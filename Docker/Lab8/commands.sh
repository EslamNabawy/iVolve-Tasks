#!/usr/bin/env bash
# Lab 8 — Containerized Node.js and MySQL Stack Using Docker Compose
set -euo pipefail

LAB="$HOME/iVolve-Tasks/Docker/Lab8"
REGISTRY_PORT=5000

# 1. Clone the application
mkdir -p "$HOME/labs-workspace"
cd "$HOME/labs-workspace"
[ -d iVolveApp ] || git clone https://github.com/Ibrahim-Adel15/iVolveApp.git
cd iVolveApp

# 2. Compose file authored in this lab
cp "$LAB/docker-compose.yml" .

# 3. Build and start
docker compose build
docker compose up -d

# 4. Wait for the app to reach /health
for i in $(seq 1 60); do
  [ "$(curl -s -o /dev/null -w '%{http_code}' http://localhost:3000/health)" = "200" ] && break
  sleep 2
done
docker compose ps
curl -s -w '  <- HTTP %{http_code}\n' http://localhost:3000/health
curl -s -w '  <- HTTP %{http_code}\n' http://localhost:3000/ready
curl -s -o /dev/null -w 'GET / -> HTTP %{http_code}\n' http://localhost:3000/

# 5. Verify the DB connection, the network and the volumes
docker compose exec -T db mysql -uivolveuser -pivolvepass -e "SHOW DATABASES;"
docker compose exec -T app getent hosts db
docker compose exec -T app tail -3 /app/logs/access.log
docker volume ls --format '{{.Name}}' | grep ivolveapp

# 6. Data survives a full recreate (volumes are not removed by `compose down`)
docker compose down
docker compose up -d
sleep 20
docker compose exec -T db mysql -uivolveuser -pivolvepass -D ivolve -e "SHOW TABLES;"

# 7. Tag and push.
#    The deck asks for Docker Hub. This host has no Docker Hub credentials, so the
#    push target is a local `registry:2` — the same commands the learner would run,
#    with the registry host swapped. Set DOCKER_HUB_USER and `docker login` to use
#    the real Hub:
#      docker tag ivolveapp:lab8 $DOCKER_HUB_USER/ivolveapp:lab8
#      docker push $DOCKER_HUB_USER/ivolveapp:lab8
docker run -d --name lab8-registry -p ${REGISTRY_PORT}:5000 registry:2
sleep 4
docker tag eslamnabawy/ivolveapp:lab8 localhost:${REGISTRY_PORT}/eslamnabawy/ivolveapp:lab8
docker push localhost:${REGISTRY_PORT}/eslamnabawy/ivolveapp:lab8
curl -s http://localhost:${REGISTRY_PORT}/v2/_catalog; echo

# 8. Clean up (volumes keep data until `-v`)
docker compose down
docker rm -f lab8-registry
docker rmi localhost:${REGISTRY_PORT}/eslamnabawy/ivolveapp:lab8 eslamnabawy/ivolveapp:lab8
