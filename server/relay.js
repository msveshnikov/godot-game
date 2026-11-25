// Smash Atlas multiplayer relay.
//
// A dumb WebSocket hub: every JSON message a client sends is stamped with its
// id and forwarded to everyone else in the same room. The server also picks a
// "host" per room - the client that simulates the villager bots - and hands the
// role to someone else when the host leaves or goes quiet (e.g. a browser tab
// in the background stops sending).
//
//   PORT=8091 HOST=127.0.0.1 node relay.js
//   clients connect to ws://HOST:PORT/?room=<name>&os=<platform>&v=<version>
//
// Usage log: readable lines go to stdout (journalctl -u village-relay), and every
// finished session is appended as one JSON line to logs/sessions.jsonl (see
// stats.js). Countries come from nginx GeoIP2 headers; IPs are never stored, only
// a salted hash to count unique players.

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const { WebSocketServer } = require('ws');
const { DatabaseSync } = require('node:sqlite');

const PORT = Number(process.env.PORT) || 8091;
const HOST = process.env.HOST || '127.0.0.1';
const MAX_PER_ROOM = 16;
const HOST_STALE_MS = 2500;
const FRESH_MS = 1500;
const LOCATION_POINTS = 10000;
const TESTER_NAME = 'макс';
const PROTECTED_ROOM = /(?:^|-)(?:paris|dublin)$/;

const LOG_DIR = process.env.LOG_DIR || path.join(__dirname, 'logs');
const SESSIONS_FILE = path.join(LOG_DIR, 'sessions.jsonl');
fs.mkdirSync(LOG_DIR, { recursive: true });
const SALT_FILE = path.join(LOG_DIR, '.salt');
if (!fs.existsSync(SALT_FILE)) fs.writeFileSync(SALT_FILE, crypto.randomBytes(16).toString('hex'));
const SALT = fs.readFileSync(SALT_FILE, 'utf8').trim();

const db = new DatabaseSync(path.join(LOG_DIR, 'leaderboard.sqlite'));
db.exec('PRAGMA journal_mode = WAL');
db.exec('CREATE TABLE IF NOT EXISTS leaderboard (id TEXT PRIMARY KEY, name TEXT NOT NULL, score INTEGER NOT NULL)');
const addPoints = db.prepare(
  'INSERT INTO leaderboard VALUES (?, ?, ?) ON CONFLICT(id) DO UPDATE SET name = excluded.name, score = score + excluded.score',
);
const renamePlayer = db.prepare('UPDATE leaderboard SET name = ? WHERE id = ? AND name != ?');
const topTen = db.prepare('SELECT name, score FROM leaderboard ORDER BY score DESC, id LIMIT 10');
const playerScore = db.prepare('SELECT score FROM leaderboard WHERE id = ?');

function scoreOf(client) {
  return playerScore.get(client.scoreId)?.score || 0;
}

function award(client, points) {
  if (!client?.scoreId) return;
  addPoints.run(client.scoreId, client.name || 'Player', points);
  if (!client.locationsUnlocked) {
    const score = scoreOf(client);
    if (score >= LOCATION_POINTS) {
      client.locationsUnlocked = true;
      send(client.ws, { t: 'rank_access', score });
    }
  }
}

function readyForScore(cooldowns, key, interval) {
  const now = Date.now();
  if (now < (cooldowns.get(key) || 0)) return false;
  cooldowns.set(key, now + interval);
  return true;
}

const rooms = new Map(); // name -> { clients: Map<id, client>, host: id }
let nextId = 1;

const wss = new WebSocketServer({ port: PORT, host: HOST, maxPayload: 32 * 1024 });

function send(ws, obj) {
  if (ws.readyState === ws.OPEN) ws.send(JSON.stringify(obj));
}

function broadcast(room, obj, exceptId) {
  const text = JSON.stringify(obj);
  for (const [id, client] of room.clients) {
    if (id !== exceptId && client.ws.readyState === client.ws.OPEN) client.ws.send(text);
  }
}

function header(req, name) {
  const value = req.headers[name];
  return (Array.isArray(value) ? value[0] : value || '').trim();
}

// Short stable id for an address, so unique players can be counted without keeping IPs.
function visitorHash(ip) {
  return crypto.createHash('sha256').update(SALT + ip).digest('hex').slice(0, 10);
}

function clientPlatform(url, ua) {
  const os = (url.searchParams.get('os') || '').slice(0, 16);
  if (os) return os;
  if (/Android/i.test(ua)) return 'Web/Android';
  if (/iPhone|iPad/i.test(ua)) return 'Web/iOS';
  if (/Mozilla/i.test(ua)) return 'Web';
  return '?';
}

function duration(ms) {
  const s = Math.round(ms / 1000);
  const h = Math.floor(s / 3600);
  const m = Math.floor((s % 3600) / 60);
  return h ? `${h}h${String(m).padStart(2, '0')}m` : m ? `${m}m${String(s % 60).padStart(2, '0')}s` : `${s}s`;
}

function quoted(name) {
  return name ? `"${name}"` : `#?`;
}

function logSession(entry) {
  fs.appendFile(SESSIONS_FILE, JSON.stringify(entry) + '\n', (err) => {
    if (err) console.error(`sessions log: ${err.message}`);
  });
}

function electHost(room) {
  const now = Date.now();
  let best = null;
  for (const client of room.clients.values()) {
    const fresh = now - client.lastSeen < FRESH_MS;
    if (!best || (fresh && !best.fresh) || (fresh === best.fresh && client.id < best.id)) {
      best = { id: client.id, fresh };
    }
  }
  room.host = best ? best.id : 0;
  if (best) broadcast(room, { t: 'host', id: room.host });
}

wss.on('connection', (ws, req) => {
  const url = new URL(req.url || '/', 'http://relay');
  const roomName = (url.searchParams.get('room') || 'main').slice(0, 32);
  const protectedRoom = PROTECTED_ROOM.test(roomName);
  let room = null;

  const id = nextId++;
  const ip = header(req, 'x-real-ip') || req.socket.remoteAddress || '';
  const ua = header(req, 'user-agent');
  const client = {
    id,
    ws,
    lastSeen: Date.now(),
    alive: true,
    start: Date.now(),
    name: '',
    names: [],
    country: header(req, 'x-country-code') || '??',
    countryName: header(req, 'x-country-name'),
    visitor: visitorHash(ip),
    os: clientPlatform(url, ua),
    version: (url.searchParams.get('v') || '').slice(0, 24),
    counts: Object.create(null), // message type -> how many this client sent
    bytes: 0,
    scoreId: null,
    locationsUnlocked: false,
    nextTopRequest: 0,
    scoreCooldowns: new Map(),
    rockets: new Map(),
    kills: 0,
    deaths: 0,
    maxOnline: 0,
  };
  const joinTimeout = protectedRoom ? setTimeout(() => ws.close(1008, 'ranking required'), 5000) : null;

  function joinRoom() {
    const target = rooms.get(roomName) || { clients: new Map(), host: 0, npcScores: new Map() };
    if (target.clients.size >= MAX_PER_ROOM) {
      ws.close(1013, 'room full');
      return false;
    }
    clearTimeout(joinTimeout);
    room = target;
    rooms.set(roomName, room);
    room.clients.set(id, client);
    if (!room.clients.has(room.host)) room.host = id;
    for (const c of room.clients.values()) c.maxOnline = Math.max(c.maxOnline, room.clients.size);
    console.log(
      `[${roomName}] +${id} ${client.country} ${client.os}${client.version ? ' ' + client.version : ''}` +
        ` visitor ${client.visitor} (${room.clients.size} online, host ${room.host})`,
    );
    send(ws, { t: 'welcome', ranking: true, id, host: room.host, peers: [...room.clients.keys()].filter((x) => x !== id) });
    broadcast(room, { t: 'join', id }, id);
    return true;
  }

  if (!protectedRoom && !joinRoom()) return;

  ws.on('message', (data, isBinary) => {
    if (ws.readyState !== ws.OPEN) return;
    client.lastSeen = Date.now();
    if (isBinary) return;
    let msg;
    try {
      msg = JSON.parse(data.toString());
    } catch {
      return;
    }
    if (!msg || typeof msg !== 'object' || Array.isArray(msg) || typeof msg.t !== 'string') return;
    if (!room && msg.t !== 'rank_join') return;
    if (msg.t === 'rank_join') {
      if (typeof msg.token !== 'string' || !/^[0-9a-f]{64}$/.test(msg.token)) return;
      const scoreId = crypto.createHash('sha256').update(msg.token).digest('hex');
      if (client.scoreId && client.scoreId !== scoreId) return;
      client.scoreId = scoreId;
      const score = scoreOf(client);
      client.locationsUnlocked = score >= LOCATION_POINTS;
      if (protectedRoom && !client.locationsUnlocked && msg.n !== TESTER_NAME) {
        send(ws, { t: 'location_locked' });
        ws.close(1008, '10,000 points required');
        return;
      }
      if (!room && !joinRoom()) return;
      send(ws, { t: 'rank_access', score });
    }
    const type = msg.t.slice(0, 8);
    if (type in client.counts || Object.keys(client.counts).length < 32) client.counts[type] = (client.counts[type] || 0) + 1;
    client.bytes += data.length;
    // Smash Atlas puts the name in every "p" as `n`; Sea Battle sends it once in "hello" as `name`.
    const rawName = typeof msg.n === 'string' ? msg.n : msg.t === 'hello' && typeof msg.name === 'string' ? msg.name : '';
    if (protectedRoom && !client.locationsUnlocked && rawName && rawName !== TESTER_NAME) {
      send(ws, { t: 'location_locked' });
      ws.close(1008, '10,000 points required');
      return;
    }
    if (rawName && rawName !== client.name) {
      const name = rawName.slice(0, 16).replace(/[\x00-\x1f"]/g, '');
      if (name && name !== client.name) {
        console.log(`[${roomName}] #${id} ${client.name ? `renamed ${quoted(client.name)} -> ` : 'is '}${quoted(name)}`);
        client.name = name;
        if (client.scoreId) renamePlayer.run(name, client.scoreId, name);
        if (!client.names.includes(name)) client.names.push(name);
      }
    }
    // Ranking messages are private to the relay. The token is a per-installation
    // credential and stays off the room broadcast and out of the session log.
    if (msg.t === 'rank_join') {
      if (client.name) renamePlayer.run(client.name, client.scoreId, client.name);
      return;
    }
    if (msg.t === 'rank_top') {
      const now = Date.now();
      if (now >= client.nextTopRequest) {
        client.nextTopRequest = now + 500;
        send(ws, { t: 'rank_top', rows: topTen.all() });
      }
      return;
    }
    if (msg.t === 'rank_npc') {
      if (id === room.host && Number.isInteger(msg.i) && msg.i >= 0 && msg.i < 512) {
        const attacker = room.clients.get(msg.by);
        if (attacker?.scoreId && readyForScore(room.npcScores, msg.i, 1000)) award(attacker, 100);
      }
      return;
    }
    if (msg.t === 'rank_glass') {
      award(client, 10);
      return;
    }
    if (client.scoreId && msg.t === 'dn' && msg.first === true &&
        (msg.w === 'parked' || msg.w === 'traffic') && Number.isInteger(msg.i) && msg.i >= 0 && msg.i < 4096 &&
        readyForScore(client.scoreCooldowns, msg.w + msg.i, 1000)) award(client, 10);
    if (client.scoreId && msg.t === 'rf' && Number.isSafeInteger(msg.rocket) && msg.rocket > 0 &&
        readyForScore(client.scoreCooldowns, 'rocket', 1000)) {
      const now = Date.now();
      for (const [rocket, expiry] of client.rockets) {
        if (expiry <= now) client.rockets.delete(rocket);
      }
      if (!client.rockets.has(msg.rocket)) client.rockets.set(msg.rocket, now + 10000);
    }
    if (msg.t === 'rx' && (client.rockets.get(msg.rocket) || 0) > Date.now()) {
      client.rockets.delete(msg.rocket);
      award(client, 200);
    }

    if (msg.t === 'kill') {
      // Sent by the victim: `by` is the killer's id.
      client.deaths++;
      const killer = room.clients.get(Number(msg.by));
      if (killer) killer.kills++;
      if (killer?.scoreId && killer.id !== id && killer.scoreId !== client.scoreId &&
          readyForScore(client.scoreCooldowns, 'death', 1000)) award(killer, 1000);
      console.log(`[${roomName}] ${killer ? quoted(killer.name) : '#' + msg.by} killed ${quoted(client.name)}${msg.z ? ' (' + msg.z + ')' : ''}`);
    }
    if (msg.t === 'b' && id !== room.host) return; // only the host drives the bots
    msg.from = id;
    broadcast(room, msg, id);
  });

  ws.on('pong', () => {
    client.alive = true;
  });

  ws.on('close', (code) => {
    clearTimeout(joinTimeout);
    if (!room) return;
    room.clients.delete(id);
    const ms = Date.now() - client.start;
    const counts = Object.entries(client.counts)
      .sort((a, b) => b[1] - a[1])
      .map(([t, n]) => `${t}:${n}`)
      .join(' ');
    console.log(
      `[${roomName}] -${id} ${quoted(client.name)} ${client.country} after ${duration(ms)}` +
        `${client.kills || client.deaths ? `, ${client.kills} kills ${client.deaths} deaths` : ''}` +
        ` (${room.clients.size} online) msgs ${counts || 'none'}`,
    );
    logSession({
      start: new Date(client.start).toISOString(),
      end: new Date().toISOString(),
      seconds: Math.round(ms / 1000),
      room: roomName,
      id,
      name: client.name,
      names: client.names,
      country: client.country,
      countryName: client.countryName,
      visitor: client.visitor,
      os: client.os,
      version: client.version,
      maxOnline: client.maxOnline,
      kills: client.kills,
      deaths: client.deaths,
      msgs: client.counts,
      bytes: client.bytes,
      code,
    });
    if (room.clients.size === 0) {
      rooms.delete(roomName);
      return;
    }
    broadcast(room, { t: 'leave', id });
    if (room.host === id) electHost(room);
  });
});

// Hand the host role over when the host stops talking (backgrounded tab, frozen app).
setInterval(() => {
  const now = Date.now();
  for (const room of rooms.values()) {
    const host = room.clients.get(room.host);
    if (host && now - host.lastSeen < HOST_STALE_MS) continue;
    const someoneFresh = [...room.clients.values()].some((c) => now - c.lastSeen < FRESH_MS);
    if (!host || someoneFresh) {
      const before = room.host;
      electHost(room);
      if (room.host !== before) console.log(`host ${before} -> ${room.host}`);
    }
  }
}, 500);

// Drop dead sockets.
setInterval(() => {
  for (const room of rooms.values()) {
    for (const client of room.clients.values()) {
      if (!client.alive) {
        client.ws.terminate();
        continue;
      }
      client.alive = false;
      client.ws.ping();
    }
  }
}, 15000);

console.log(`Smash Atlas relay on ws://${HOST}:${PORT}`);
