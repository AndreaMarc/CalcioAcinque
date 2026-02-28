#!/bin/bash
cp /home/ubuntu/calcioacinque/backend/appsettings.Production.json /home/ubuntu/calcioacinque/appsettings.Production.json.bak
rm -rf /home/ubuntu/calcioacinque/backend/publish /home/ubuntu/calcioacinque/backend/publish-linux
rm -f /home/ubuntu/calcioacinque/backend/Backend /home/ubuntu/calcioacinque/backend/Backend.dll /home/ubuntu/calcioacinque/backend/Backend.pdb /home/ubuntu/calcioacinque/backend/Backend.deps.json /home/ubuntu/calcioacinque/backend/Backend.runtimeconfig.json /home/ubuntu/calcioacinque/backend/Backend.exe /home/ubuntu/calcioacinque/backend/Backend.staticwebassets.endpoints.json
rm -f /home/ubuntu/calcioacinque/backend/*.so /home/ubuntu/calcioacinque/backend/createdump /home/ubuntu/calcioacinque/backend/web.config
find /home/ubuntu/calcioacinque/backend/ -name "*.dll" ! -name "appsettings*" -delete 2>/dev/null
unzip -o /home/ubuntu/calcioacinque/backend-linux.zip -d /home/ubuntu/calcioacinque/backend/
cp /home/ubuntu/calcioacinque/appsettings.Production.json.bak /home/ubuntu/calcioacinque/backend/appsettings.Production.json
chmod +x /home/ubuntu/calcioacinque/backend/Backend
systemctl restart calcioacinque
sleep 2
systemctl status calcioacinque --no-pager
