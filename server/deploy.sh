#!/usr/bin/env bash
# One-time setup of the multiplayer relay on severance.lol:
#   - copies relay.js to ~/village-relay and installs `ws`
#   - runs it as the systemd service "village-relay" on 127.0.0.1:8091
#   - proxies wss://severance.lol/village-ws to it through nginx, passing the
#     client IP and the GeoIP2 country for the usage log
#     (backs up the nginx config first and only reloads if `nginx -t` passes)
# Re-running updates relay.js and restarts the service (logs/ on the server is kept).
# Usage summary: ssh ubuntu@severance.lol 'node ~/village-relay/stats.js 7'
set -euo pipefail
cd "$(dirname "$0")"
SERVER=ubuntu@severance.lol

ssh "$SERVER" 'mkdir -p ~/village-relay'
# `ws` is pure JavaScript and the server has node but no npm, so ship it from here.
[ -d node_modules/ws ] || npm install --omit=dev --no-audit --no-fund
scp -q -r relay.js stats.js package.json package-lock.json node_modules "$SERVER":~/village-relay/

ssh "$SERVER" 'bash -s' <<'REMOTE'
set -euo pipefail
cd ~/village-relay

sudo tee /etc/systemd/system/village-relay.service >/dev/null <<'UNIT'
[Unit]
Description=Smash Atlas multiplayer relay
After=network.target

[Service]
User=ubuntu
WorkingDirectory=/home/ubuntu/village-relay
Environment=PORT=8091
Environment=HOST=127.0.0.1
ExecStart=/usr/bin/node relay.js
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT
sudo systemctl daemon-reload
sudo systemctl enable village-relay >/dev/null
sudo systemctl restart village-relay
systemctl is-active village-relay

CONF=/etc/nginx/sites-available/default
if ! grep -q 'X-Country-Code' "$CONF"; then
  sudo cp "$CONF" "$CONF.bak-village-ws"
  sudo python3 - "$CONF" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
headers = """        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Country-Code $geoip2_data_country_iso_code;
        proxy_set_header X-Country-Name $geoip2_data_country_name;
"""
if "location /village-ws {" in s:
    # Older deploy: add the usage-log headers to the existing block.
    start = s.index("location /village-ws {")
    host = "        proxy_set_header Host $host;\n"
    at = s.index(host, start) + len(host)
    assert at < s.index("}", start), "unexpected /village-ws block"
    s = s[:at] + headers + s[at:]
else:
    anchor = "    server_name severance.lol;\n    root /var/www/severance;\n    index index.html index.htm;\n"
    assert s.count(anchor) == 1, "severance.lol server block not found"
    s = s.replace(anchor, anchor + """
    location /village-ws {
        proxy_pass http://127.0.0.1:8091;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
""" + headers + """        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
    }
""")
open(p, "w").write(s)
PY
  if sudo nginx -t; then
    sudo systemctl reload nginx
  else
    sudo cp "$CONF.bak-village-ws" "$CONF"
    echo "nginx config test failed, restored backup" >&2
    exit 1
  fi
fi
echo "relay deployed: wss://severance.lol/village-ws"
REMOTE
