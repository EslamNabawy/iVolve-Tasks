#!/usr/bin/env bash
# Lab 6 — Docker Environment Variables and Resource Management
set -euo pipefail

LAB="$HOME/iVolve-Tasks/Docker/Lab6"

# 1. Clone the application
mkdir -p "$HOME/labs-workspace"
cd "$HOME/labs-workspace"
git clone https://github.com/Ibrahim-Adel15/PythonApp.git
cd PythonApp

# 2. Build ivolve1 from the Dockerfile authored in this lab
cp "$LAB/Dockerfile" "$LAB/Dockerfile.env" "$LAB/env.txt" .
docker build -t ivolve1 .
docker images ivolve1

# 3. container1: port 5000, env vars, 1 CPU and 256 MB
docker run -d --name container1 \
  -p 5000:5000 \
  --cpus=1 --memory=256m \
  -e APP_NAME=iVolveApp1 -e APP_ENV=stg \
  ivolve1
sleep 3
curl -s localhost:5000
curl -s localhost:5000/health

# 4. Verify the environment variables and the limits
docker exec container1 env | grep '^APP_'
docker inspect container1 --format '{{json .Config.Env}}'
docker stats container1 --no-stream
docker inspect container1 --format 'NanoCpus={{.HostConfig.NanoCpus}} Memory={{.HostConfig.Memory}}'

# 5. Stop and delete container1
docker stop container1 && docker rm container1

# 6. container2: environment from env.txt
docker run -d --name container2 -p 5000:5000 --env-file env.txt ivolve1
sleep 3
curl -s localhost:5000
docker exec container2 env | grep '^APP_'
docker stop container2 && docker rm container2

# 7. New image with the variables hardcoded in the Dockerfile
docker build -f Dockerfile.env -t ivolve3 .

# 8. container2 again — from the image whose ENV holds the values
docker run -d --name container2 -p 5000:5000 ivolve3
sleep 3
curl -s localhost:5000
docker exec container2 env | grep '^APP_'
docker inspect ivolve3 --format '{{json .Config.Env}}'

# 9. Bonus: a run-time -e wins over the Dockerfile ENV
docker run -d --name container3 -p 5001:5000 -e APP_NAME=OverrideName ivolve3
sleep 3
curl -s localhost:5001

# 10. Clean up
docker rm -f container2 container3
docker rmi ivolve1 ivolve3
