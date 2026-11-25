// Usage summary from the relay's session log.
//
//   node stats.js [days=14] [logs/sessions.jsonl]
//
// On the server: ssh ubuntu@severance.lol 'node ~/village-relay/stats.js 7'

const fs = require('fs');
const path = require('path');

const days = Number(process.argv[2]) || 14;
const file = process.argv[3] || path.join(__dirname, 'logs', 'sessions.jsonl');
if (!fs.existsSync(file)) {
  console.log(`no sessions yet (${file})`);
  process.exit(0);
}

const since = Date.now() - days * 86400e3;
const sessions = fs
  .readFileSync(file, 'utf8')
  .split('\n')
  .filter(Boolean)
  .map((line) => {
    try {
      return JSON.parse(line);
    } catch {
      return null;
    }
  })
  .filter((s) => s && Date.parse(s.start) >= since && !/test/.test(s.room));

function hours(seconds) {
  const m = Math.round(seconds / 60);
  return m >= 60 ? `${Math.floor(m / 60)}h${String(m % 60).padStart(2, '0')}m` : `${m}m`;
}

function median(values) {
  if (!values.length) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.floor(sorted.length / 2)];
}

function top(list, key, weight = () => 1, n = 6) {
  const totals = new Map();
  for (const item of list) {
    const k = key(item);
    if (k) totals.set(k, (totals.get(k) || 0) + weight(item));
  }
  return [...totals].sort((a, b) => b[1] - a[1]).slice(0, n);
}

function summary(list) {
  const visitors = new Set(list.map((s) => s.visitor));
  const total = list.reduce((sum, s) => sum + s.seconds, 0);
  const together = list.filter((s) => s.maxOnline > 1).length;
  return (
    `${String(list.length).padStart(4)} sessions  ${String(visitors.size).padStart(3)} players  ` +
    `${hours(total).padStart(7)} played  median ${hours(median(list.map((s) => s.seconds))).padStart(4)}  ` +
    `${together} with others`
  );
}

// Local (server) calendar day.
const day = (s) => new Date(Date.parse(s.start) - new Date().getTimezoneOffset() * 60e3).toISOString().slice(0, 10);

console.log(`Last ${days} days, ${file}\n`);
console.log(`total       ${summary(sessions)}\n`);
for (const [d] of top(sessions, day, () => 1, 999).sort((a, b) => a[0].localeCompare(b[0]))) {
  const list = sessions.filter((s) => day(s) === d);
  const countries = top(list, (s) => s.country, () => 1, 4)
    .map(([c, n]) => `${c} ${n}`)
    .join(', ');
  console.log(`${d}  ${summary(list)}  | ${countries}`);
}

const fmt = (rows, f = (v) => v) => rows.map(([k, v]) => `${k} ${f(v)}`).join(', ') || '-';
console.log(`\nrooms      ${fmt(top(sessions, (s) => s.room, (s) => s.seconds, 8), hours)}`);
console.log(`countries  ${fmt(top(sessions, (s) => s.countryName || s.country, (s) => s.seconds, 10), hours)}`);
console.log(`platforms  ${fmt(top(sessions, (s) => s.os, (s) => s.seconds), hours)}`);
console.log(`versions   ${fmt(top(sessions, (s) => s.version || '?', () => 1, 5))}`);
console.log(`players    ${fmt(top(sessions, (s) => s.name, (s) => s.seconds, 15), hours)}`);
const kills = top(sessions, (s) => s.name, (s) => s.kills, 10).filter(([, n]) => n > 0);
if (kills.length) console.log(`killers    ${fmt(kills)}`);
