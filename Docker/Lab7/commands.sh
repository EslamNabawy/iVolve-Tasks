#!/usr/bin/env bash
# Lab 7 — Multi-Network Microservices, Volumes, and Bind Mounts
set -euo pipefail

LAB="$HOME/iVolve-Tasks/Docker/Lab7"
DATA="$HOME/labs-workspace/lab7-data"

# 1. Clone the application
mkdir -p "$HOME/labs-workspace"
cd "$HOME/labs-workspace"
[ -d MicroserviceApp ] || git clone https://github.com/Ibrahim-Adel15/MicroserviceApp.git
cd MicroserviceApp

# 2. Build the three images from the Dockerfiles authored in this lab
cp "$LAB/frontend/Dockerfile"     frontend/Dockerfile
cp "$LAB/backend/Dockerfile"      backend/Dockerfile
cp "$LAB/notification/Dockerfile" notification/Dockerfile
docker build --network=host -t micro-frontend:lab7 frontend
docker build --network=host -t micro-backend:lab7 backend
docker build --network=host -t micro-notification:lab7 notification
docker images --format '{{.Repository}}:{{.Tag}} {{.Size}}' | grep lab7

# 3. Two bridge networks with separate subnets
docker network create --driver bridge --subnet 172.28.0.0/24 frontend-backend
docker network create --driver bridge --subnet 172.29.0.0/24 backend-notification

# 4. Two volumes, one per log producer
docker volume create backend-logs
docker volume create notification-logs

# 5. Host directory for backend application data (bind mount)
mkdir -p "$DATA"

# 6. Notification — only on backend-notification
docker run -d --name notification --network backend-notification \
  -v notification-logs:/app/logs micro-notification:lab7

# 7. Backend — both networks, notification URL, log volume, data bind mount
docker run -d --name backend --network frontend-backend \
  -e NOTIFICATION_URL=http://notification:5001/notify \
  -v backend-logs:/app/logs \
  -v "$DATA":/app/data \
  micro-backend:lab7
docker network connect backend-notification backend

# 8. Frontend — frontend-backend, port 8080 on the host, backend URL
docker run -d --name frontend --network frontend-backend -p 8080:3000 \
  -e BACKEND_URL=http://backend:5000 micro-frontend:lab7
sleep 5

# 9. Verify the page and create two messages through the UI form
curl -s -o /dev/null -w 'GET  /      -> HTTP %{http_code}\n' http://localhost:8080/
curl -s -o /dev/null -w 'POST /send  -> HTTP %{http_code}\n' \
  -X POST -d 'message=Hello from Lab 7' http://localhost:8080/send
curl -s -o /dev/null -w 'POST /send  -> HTTP %{http_code}\n' \
  -X POST -d 'message=Second message via Docker networks' http://localhost:8080/send
sleep 2
curl -s http://localhost:8080/ | grep -o '<li>[^<]*</li>'

# 10. Prove the network split
docker network inspect frontend-backend     --format '{{range .Containers}}{{.Name}} {{end}}'
docker network inspect backend-notification --format '{{range .Containers}}{{.Name}} {{end}}'

# 11. Prove the volumes and the bind mount
docker exec notification tail -3 /app/logs/notification.log
docker exec backend tail -3 /app/logs/backend.log
cat "$DATA/messages.json"
docker inspect backend --format '{{range .Mounts}}{{.Type}} {{.Source}} -> {{.Destination}}{{"\n"}}{{end}}'

# 12. Clean up
docker rm -f frontend backend notification
docker network rm frontend-backend backend-notification
docker volume rm backend-logs notification-logs
docker rmi micro-frontend:lab7 micro-backend:lab7 micro-notification:lab7
