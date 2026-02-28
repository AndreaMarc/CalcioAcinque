#!/bin/bash
# Update service to use dotnet command
cat > /etc/systemd/system/calcioacinque.service << 'EOF'
[Unit]
Description=CalcioAcinque Backend API
After=network.target mysql.service

[Service]
WorkingDirectory=/home/ubuntu/calcioacinque/backend
ExecStart=/home/ubuntu/.dotnet/dotnet /home/ubuntu/calcioacinque/backend/Backend.dll --urls http://0.0.0.0:5050
Restart=always
RestartSec=10
SyslogIdentifier=calcioacinque
User=ubuntu
Environment=ASPNETCORE_ENVIRONMENT=Production
Environment=DOTNET_ROOT=/home/ubuntu/.dotnet

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl restart calcioacinque
sleep 3
systemctl status calcioacinque --no-pager
