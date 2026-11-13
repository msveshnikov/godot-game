#!/usr/bin/env bash
# One-time setup of the multiplayer relay on severance.lol:
#   - copies relay.js to ~/village-relay and installs `ws`
#   - runs it as the systemd service "village-relay" on 127.0.0.1:8091
#   - proxies wss://severance.lol/village-ws to it through nginx
#     (backs up the nginx config first and only reloads if `nginx -t` passes)
# Re-running only updates relay.js and restarts the service.
set -euo pipefail
cd "$(dirname "$0")"
SERVER=ubuntu@severance.lol

ssh "$SERVER" 'mkdir -p ~/village-relay'
# `ws` is pure JavaScript and the server has node but no npm, so ship it from here.
[ -d node_modules/ws ] || npm install --omit=dev --no-audit --no-fund
scp -q -r relay.js package.json package-lock.json node_modules "$SERVER":~/village-relay/

ssh "$SERVER" 'bash -s' <<'REMOTE'
set -euo pipefail
cd ~/village-relay

sudo tee /etc/systemd/system/village-relay.service >/dev/null <<'UNIT'
[Unit]
Description=Gacha Village multiplayer relay
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
if ! grep -q '/village-ws' "$CONF"; then
  sudo cp "$CONF" "$CONF.bak-village-ws"
  sudo python3 - "$CONF" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
anchor = "    server_name severance.lol;\n    root /var/www/severance;\n    index index.html index.htm;\n"
assert s.count(anchor) == 1, "severance.lol server block not found"
s = s.replace(anchor, anchor + """
    location /village-ws {
        proxy_pass http://127.0.0.1:8091;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_read_timeout 3600s;
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
