#!/usr/bin/env bash
# Lab 4 — Docker Image Optimization and Export/Load
# Run from anywhere; the upstream app is cloned to ~/labs-workspace and never committed.
set -euo pipefail

LAB="$HOME/iVolve-Tasks/Docker/Lab4"

# 1. Clone the application
mkdir -p "$HOME/labs-workspace"
cd "$HOME/labs-workspace"
git clone https://github.com/Ibrahim-Adel15/ImageOptimization-.git
cd ImageOptimization-

# 2. Build the image from the Dockerfile that ships with the repo
docker build -t image1 .
docker images image1

# 3. Run container1 and verify the application
docker run -d --name container1 -p 8080:8080 image1
sleep 10
curl -s -w '\nHTTP %{http_code}\n' localhost:8080
docker logs container1 | tail -3

# 4. Stop and delete container1
docker stop container1 && docker rm container1

# 5. Build the optimized, multi-stage, non-root image
#    --network=host works around the BuildKit network stall on this machine (see README)
docker build --network=host -f "$LAB/Dockerfile.multistage" -t image2 .

# 6. Compare sizes
docker images --format '{{.Repository}}:{{.Tag}}  {{.Size}}' | grep -E '^image[12]:'

# 7. Run container2, verify the app and prove non-root
docker run -d --name container2 -p 8080:8080 image2
sleep 10
curl -s -w '\nHTTP %{http_code}\n' localhost:8080
docker exec container2 whoami          # appuser
docker exec container2 id              # uid=100(appuser)
docker run --rm --entrypoint whoami image2

# 8. Stop and delete container2
docker stop container2 && docker rm container2

# 9. Export image2 to a tar, delete it, load it back
cd "$HOME"
docker save image2 -o lab-image.tar
ls -lh lab-image.tar
docker rmi image2
docker images | grep image2 || echo 'image2 is gone'
docker load -i lab-image.tar
docker images | grep image2

# 10. The restored image still works
docker run -d --name container2 -p 8080:8080 image2
sleep 10
curl -s -w '\nHTTP %{http_code}\n' localhost:8080
docker stop container2 && docker rm container2

# 11. Clean up the tar (the image is back on the host)
rm -f lab-image.tar
