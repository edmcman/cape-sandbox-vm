#!/bin/bash -eux

CAPE_ROOT="${CAPE_ROOT:-/opt/CAPEv2}"

# Install MCP optional dependencies (fastmcp, httpx) into CAPE's venv
sudo -u cape /usr/local/bin/uv sync --no-install-project --directory "$CAPE_ROOT" --extra mcp

# Install cape-mcp systemd service
cat > /lib/systemd/system/cape-mcp.service <<EOF
[Unit]
Description=CAPE MCP Server (SSE)
Documentation=https://github.com/kevoreilly/CAPEv2
Wants=cape-web.service
After=cape-web.service

[Service]
WorkingDirectory=/opt/CAPEv2
Environment=CAPE_API_URL=http://127.0.0.1:8000/apiv2
ExecStart=/usr/local/bin/uv run python mcp/server.py --transport sse --host 0.0.0.0 --port 9004
User=cape
Group=cape
Restart=always
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable cape-mcp.service