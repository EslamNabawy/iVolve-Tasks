# Lab 7: Multi-Network Microservices, Volumes, and Bind Mounts

**Track:** Docker · **Source:** https://github.com/Ibrahim-Adel15/MicroserviceApp.git

Three small Flask services, `frontend`, `backend`, `notification`. That must talk
to each other in one direction only:

```
browser :8080
   |
   v
frontend (:3000)  ──[ frontend-backend ]──>  backend (:5000)
                                                  |        \
                                     [ backend-notification ] \
                                                  v            v
                                       notification (:5001)   /app/data (bind mount)
```

The lab is about **network topology and persistence**, not the code: the
notification service must not be reachable from the frontend, and the backend's
messages must survive a container.

## Requirements

- [x] Application cloned from the provided repository
- [x] Dockerfile per service, [`frontend/`](frontend/Dockerfile), [`backend/`](backend/Dockerfile), [`notification/`](notification/Dockerfile)
- [x] Three images built, `micro-frontend:lab7`, `micro-backend:lab7`, `micro-notification:lab7`
- [x] Two bridge networks with separate subnets, `frontend-backend` `172.28.0.0/24`, `backend-notification` `172.29.0.0/24`
- [x] Two volumes for logs, `backend-logs`, `notification-logs`
- [x] Host directory bind-mounted for backend data, `~/labs-workspace/lab7-data` → `/app/data`
- [x] Notification running on `backend-notification` only
- [x] Backend attached to **both** networks, `NOTIFICATION_URL` configured
- [x] Frontend on `frontend-backend`, published on **8080**, `BACKEND_URL` configured
- [x] Web page accessed; messages created and read back

---

## Results

### 1. Images

```
$ docker images --format '{{.Repository}}:{{.Tag}}\t{{.Size}}' | grep lab7
micro-notification:lab7	198MB
micro-backend:lab7	202MB
micro-frontend:lab7	202MB
```

All three share the same `python:3.12-slim` base; the backend and frontend are
2 MB larger because they also install `requests`.

### 2. Networks

```
$ docker network create --driver bridge --subnet 172.28.0.0/24 frontend-backend
$ docker network create --driver bridge --subnet 172.29.0.0/24 backend-notification

$ docker network inspect frontend-backend --format '{{.Name}} {{range .IPAM.Config}}{{.Subnet}}{{end}}'
frontend-backend 172.28.0.0/24
$ docker network inspect backend-notification --format '{{.Name}} {{range .IPAM.Config}}{{.Subnet}}{{end}}'
backend-notification 172.29.0.0/24
```

Two separate subnets, so a container on one network has no route to a container
that exists only on the other.

### 3. Containers

```
$ docker run -d --name notification --network backend-notification \
    -v notification-logs:/app/logs micro-notification:lab7

$ docker run -d --name backend --network frontend-backend \
    -e NOTIFICATION_URL=http://notification:5001/notify \
    -v backend-logs:/app/logs \
    -v ~/labs-workspace/lab7-data:/app/data \
    micro-backend:lab7
$ docker network connect backend-notification backend

$ docker run -d --name frontend --network frontend-backend -p 8080:3000 \
    -e BACKEND_URL=http://backend:5000 micro-frontend:lab7

$ docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Ports}}'
NAMES          IMAGE                        PORTS
frontend       micro-frontend:lab7          0.0.0.0:8080->3000/tcp, [::]:8080->3000/tcp
backend        micro-backend:lab7           5000/tcp
notification   micro-notification:lab7      5001/tcp
```

Only the frontend publishes a port. The backend and notification services are
reachable *by name* inside their networks and from nowhere else.

### 4. Create and retrieve messages

```
$ curl -s -o /dev/null -w 'GET  /      -> HTTP %{http_code}\n' http://localhost:8080/
GET  /      -> HTTP 200
$ curl -s -o /dev/null -w 'POST /send  -> HTTP %{http_code}\n' \
    -X POST -d 'message=Hello from Lab 7' http://localhost:8080/send
POST /send  -> HTTP 302
$ curl -s -o /dev/null -w 'POST /send  -> HTTP %{http_code}\n' \
    -X POST -d 'message=Second message via Docker networks' http://localhost:8080/send
POST /send  -> HTTP 302

$ curl -s http://localhost:8080/ | grep -o '<li>[^<]*</li>'
<li>Hello from Lab 7</li>
<li>Second message via Docker networks</li>
```

The `302` is the form redirect back to `/`; the page then lists both messages
which means the whole chain worked: **frontend → backend → notification → log**.

### 5. The network split is real

```
$ docker network inspect frontend-backend --format '{{range .Containers}}{{.Name}} {{end}}'
frontend backend
$ docker network inspect backend-notification --format '{{range .Containers}}{{.Name}} {{end}}'
backend notification
```

`notification` appears only in the second list. The frontend cannot resolve or
reach it even though all three containers share one Docker daemon.

### 6. Persistence: volumes and the bind mount

```
$ docker exec notification cat /app/logs/notification.log | tail -3
2026-11-11 22:33:32,027 INFO Notification received for message: Hello from Lab 7
2026-11-11 22:33:32,028 INFO 172.29.0.3 - - [11/Nov/2026 22:33:32] "POST /notify HTTP/1.1" 200 -
2026-11-11 22:33:32,042 INFO Notification received for message: Second message via Docker networks

$ docker exec backend tail -3 /app/logs/backend.log
2026-11-11 22:33:34,067 INFO Received request to retrieve messages
2026-11-11 22:33:34,068 INFO 172.28.0.3 - - [11/Nov/2026 22:33:34] "GET /messages HTTP/1.1" 200 -
2026-11-11 22:33:34,396 INFO 172.28.0.3 - - [11/Nov/2026 22:33:34] "GET /health HTTP/1.1" 200 -

$ cat ~/labs-workspace/lab7-data/messages.json
[
  "Hello from Lab 7",
  "Second message via Docker networks"
]

$ docker inspect backend --format '{{range .Mounts}}{{.Type}} {{.Source}} -> {{.Destination}}{{"\n"}}{{end}}'
volume /var/lib/docker/volumes/backend-logs/_data -> /app/logs
bind /home/eslam/labs-workspace/lab7-data -> /app/data
```

Three different storage mechanisms in one container list:

| Destination | Type | Where the bytes actually are | Survives `docker rm`? |
|---|---|---|---|
| `/app/logs` (backend) | named volume `backend-logs` | `/var/lib/docker/volumes/...` | yes, until the volume is removed |
| `/app/logs` (notification) | named volume `notification-logs` | `/var/lib/docker/volumes/...` | yes |
| `/app/data` (backend) | bind mount | a directory **you** own on the host | yes, and editable from the host |

The source IPs in the logs are the proof of which network a request arrived on:
`172.29.0.3` is the backend on `backend-notification`, `172.28.0.3` is the frontend
on `frontend-backend`.

---

## Notes

1. **A container can be on several networks at once.** `docker network connect`
   adds an interface without restarting the container; that is how the backend
 sits between two isolated subnets. Name resolution is per network, the
   frontend can resolve `backend` but not `notification`, because the embedded DNS
   server only answers for networks the container is attached to.
2. **`--network` at `docker run` is not exclusive.** The second attachment is a
 separate command (`docker network connect`), which is what the slide
   asks for.
3. **Volumes vs bind mounts.** A named volume is managed by Docker and has no
   useful host path in normal work. A bind mount points at a real directory, which
   is why the JSON file could be `cat`-ed from the host. Both are "persistent", but
   only the bind mount is *shared* with the host.
4. **`-p 8080:3000` maps host 8080 to container 3000**, not the other way round.
   The frontend really listens on 3000 (its Dockerfile `EXPOSE`s it); the deck
   asks for the page on 8080.
5. **Order matters only for DNS convenience, not for startup.** Backend could
   start before notification; `notify` calls would fail until it came up. The app
 logs a notification failure instead of losing the message, a deliberate
   property of this app.
6. **All of this is why Compose exists.** Every command here becomes one line in
   Lab 8's `docker-compose.yml`.

## Running it again

```bash
bash ~/iVolve-Tasks/Docker/Lab7/commands.sh
```

## Tidy up after it

`commands.sh` ends by removing the three containers, both networks, both volumes
and the three images. The bind-mount directory is left behind on purpose. It is
ordinary host data.

## Committing this

```bash
cd ~/iVolve-Tasks
git add Docker/Lab7
git commit -m "feat(lab7): multi-network microservices with volumes and bind mount"
```
