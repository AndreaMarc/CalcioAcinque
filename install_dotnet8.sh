#!/bin/bash
# Install .NET 8 runtime alongside existing .NET 9
/home/ubuntu/.dotnet/dotnet --list-runtimes
echo "---Installing .NET 8 ASP.NET Core runtime---"
curl -sSL https://dot.net/v1/dotnet-install.sh | bash /dev/stdin --runtime aspnetcore --version 8.0.12 --install-dir /home/ubuntu/.dotnet
echo "---After install---"
/home/ubuntu/.dotnet/dotnet --list-runtimes
