// Gacha Village multiplayer relay.
//
// A dumb WebSocket hub: every JSON message a client sends is stamped with its
// id and forwarded to everyone else in the same room. The server also picks a
// "host" per room - the client that simulates the villager bots - and hands the
// role to someone else when the host leaves or goes quiet (e.g. a browser tab
// in the background stops sending).
//
//   PORT=8091 HOST=127.0.0.1 node relay.js
//   clients connect to ws://HOST:PORT/?room=<name>

const { WebSocketServer } = require('ws');

const PORT = Number(process.env.PORT) || 8091;
const HOST = process.env.HOST || '127.0.0.1';
const MAX_PER_ROOM = 16;
const HOST_STALE_MS = 2500;
const FRESH_MS = 1500;

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
  let room = rooms.get(roomName);
  if (!room) {
    room = { clients: new Map(), host: 0 };
    rooms.set(roomName, room);
  }
  if (room.clients.size >= MAX_PER_ROOM) {
    ws.close(1013, 'room full');
    return;
  }

  const id = nextId++;
  const client = { id, ws, lastSeen: Date.now(), alive: true };
  room.clients.set(id, client);
  if (!room.clients.has(room.host)) room.host = id;
  console.log(`[${roomName}] +${id} (${room.clients.size} online, host ${room.host})`);

  send(ws, { t: 'welcome', id, host: room.host, peers: [...room.clients.keys()].filter((x) => x !== id) });
  broadcast(room, { t: 'join', id }, id);

  ws.on('message', (data, isBinary) => {
    client.lastSeen = Date.now();
    if (isBinary) return;
    let msg;
    try {
      msg = JSON.parse(data.toString());
    } catch {
      return;
    }
    if (!msg || typeof msg !== 'object' || Array.isArray(msg) || typeof msg.t !== 'string') return;
    if (msg.t === 'b' && id !== room.host) return; // only the host drives the bots
    msg.from = id;
    broadcast(room, msg, id);
  });

  ws.on('pong', () => {
    client.alive = true;
  });

  ws.on('close', () => {
    room.clients.delete(id);
    console.log(`[${roomName}] -${id} (${room.clients.size} online)`);
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

console.log(`Gacha Village relay on ws://${HOST}:${PORT}`);
