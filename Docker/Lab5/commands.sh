#!/usr/bin/env bash
# Lab 5 — Docker Image Vulnerability Scanning with Trivy (+ remediation)
set -euo pipefail

LAB="$HOME/iVolve-Tasks/Docker/Lab5"
TRIVY="$HOME/.local/bin/trivy"

# 1. Clone the application and its Dockerfile
mkdir -p "$HOME/labs-workspace"
cd "$HOME/labs-workspace"
git clone https://github.com/Ibrahim-Adel15/TrivyImage.git
cd TrivyImage

# 2. Build the vulnerable image
docker build -t trivy-lab:v1 .
docker images trivy-lab

# 3. Install Trivy (no sudo: plain binary into ~/.local/bin)
mkdir -p "$HOME/.local/bin"
V=$(curl -s https://api.github.com/repos/aquasecurity/trivy/releases/latest |
    sed -n 's/.*"tag_name": "v\([^"]*\)".*/\1/p')
curl -sSL "https://github.com/aquasecurity/trivy/releases/download/v${V}/trivy_${V}_Linux-64bit.tar.gz" -o /tmp/trivy.tgz
tar -xzf /tmp/trivy.tgz -C "$HOME/.local/bin" trivy
"$TRIVY" --version

# 4. Scan everything, then only HIGH and CRITICAL
"$TRIVY" image --scanners vuln trivy-lab:v1
"$TRIVY" image --scanners vuln --severity HIGH,CRITICAL trivy-lab:v1

# 5. HTML report (Trivy no longer ships the template inside the binary)
mkdir -p "$HOME/.local/share/trivy" "$LAB/reports"
curl -sSL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/html.tpl \
  -o "$HOME/.local/share/trivy/html.tpl"
"$TRIVY" image --scanners vuln --severity HIGH,CRITICAL \
  --format template --template "@$HOME/.local/share/trivy/html.tpl" \
  -o "$LAB/reports/trivy-v1.html" trivy-lab:v1

# 6. Remediate: current LTS base, current express, lockfile, non-root, no package managers
docker run --rm -v "$PWD":/app -w /app node:24-alpine \
  sh -c 'npm install express@latest --package-lock-only --no-audit --no-fund'
cp package-lock.json "$LAB/package-lock.json"
docker build -f "$LAB/Dockerfile.v2" -t ivolve-app:v2 .

# 7. Verify the remediated image still works
docker run -d --name trivy2 -p 3000:3000 ivolve-app:v2
sleep 5
curl -s -w '\nHTTP %{http_code}\n' localhost:3000
curl -s -w '\nHTTP %{http_code}\n' localhost:3000/health
docker exec trivy2 whoami        # node
docker stop trivy2 && docker rm trivy2

# 8. Rescan and generate the second HTML report
"$TRIVY" image --scanners vuln --severity HIGH,CRITICAL ivolve-app:v2
"$TRIVY" image --scanners vuln --severity HIGH,CRITICAL \
  --format template --template "@$HOME/.local/share/trivy/html.tpl" \
  -o "$LAB/reports/trivy-v2.html" ivolve-app:v2

# 9. Clean up
docker rmi trivy-lab:v1 ivolve-app:v2
