#!/bin/bash
set -e

echo "=== Stopping service ==="
sudo systemctl stop calcioacinque

echo "=== Deploy Backend ==="
rm -rf /home/ubuntu/calcioacinque/backend/*
cd /home/ubuntu
unzip -o backend.zip -d /home/ubuntu/calcioacinque/backend/
chmod +x /home/ubuntu/calcioacinque/backend/Backend.dll

echo "=== Deploy Frontend ==="
rm -rf /home/ubuntu/calcioacinque/frontend/*
unzip -o frontend.zip -d /home/ubuntu/calcioacinque/frontend/

echo "=== Starting service ==="
sudo systemctl start calcioacinque
sleep 2
sudo systemctl status calcioacinque --no-pager

echo "=== DEPLOY COMPLETE ==="
