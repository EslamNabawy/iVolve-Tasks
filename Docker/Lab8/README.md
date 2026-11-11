# Lab 8 — Containerized Node.js and MySQL Stack Using Docker Compose

**Track:** Docker · **Source:** https://github.com/Ibrahim-Adel15/iVolveApp.git

A Node/Express storefront that refuses to start until it can reach MySQL and the
`ivolve` database exists. The lab turns Lab 7's pile of `docker run` flags into a
single declarative file: two services, one private network, two volumes.

## Requirements

- [x] Application cloned from the provided repository
- [x] [`docker-compose.yml`](docker-compose.yml) authored with an `app` and a `db` service
- [x] App built from its `Dockerfile`, port **3000** mapped, DB settings via environment
- [x] App logs persisted at `/app/logs/`
- [x] MySQL comes from the official image, its data persisted in the **`db_data`** volume at `/var/lib/mysql`
- [x] Custom network **`ivolve-net`** for service-to-service traffic
- [x] Services started; `/health`, `/ready` and the page verified; DB connectivity proven
- [x] Image tagged with a Docker Hub username and pushed — **deviation:** pushed to a local `registry:2` because this host has no Docker Hub credentials (see §6)

---

## Results

### 1 — Build and start

```
$ docker compose up -d
 Network ivolveapp_ivolve-net  Creating
 Network ivolveapp_ivolve-net  Created
 Volume ivolveapp_db_data  Creating
 Volume ivolveapp_db_data  Created
 Volume ivolveapp_app_logs  Creating
 Volume ivolveapp_app_logs  Created
 Container ivolvedb  Creating
 Container ivolvedb  Created
 Container ivolveapp  Creating
 Container ivolveapp  Created
 Container ivolvedb  Starting
 Container ivolvedb  Started
 Container ivolvedb  Waiting
 Container ivolvedb  Healthy
 Container ivolveapp  Starting
 Container ivolveapp  Started
```

`Waiting` / `Healthy` is the `depends_on: db: condition: service_healthy`
contract doing its job: the app container is not even started until
`mysqladmin ping` succeeds.

### 2 — Both services up

```
$ docker compose ps
NAME        IMAGE                        SERVICE   STATUS                    PORTS
ivolveapp   eslamnabawy/ivolveapp:lab8   app       Up 3 seconds              0.0.0.0:3000->3000/tcp
ivolvedb    mysql:8.4                    db        Up 24 seconds (healthy)   3306/tcp, 33060/tcp
```

Only the app publishes a port. MySQL is reachable by the hostname `db` on
`ivolve-net` and by nothing else.

### 3 — The application answers

```
$ curl -s http://localhost:3000/health
🚀 iVolve web app is working! Keep calm and code on! 🎉   <- HTTP 200

$ curl -s http://localhost:3000/ready
👍 iVolve web app is ready to rock and roll! 🤘   <- HTTP 200

$ curl -s -o /dev/null -w 'GET / -> HTTP %{http_code} (%{size_download} bytes)\n' http://localhost:3000/
GET / -> HTTP 200 (2769 bytes)
```

`/health` is not a static 200: it runs `SELECT 1` against the connection the app
opened at boot, so a 200 here is a live database round trip.

### 4 — Connectivity and DNS

```
$ docker compose exec app getent hosts db
172.20.0.2        db  db
$ docker network inspect ivolveapp_ivolve-net --format '{{range .Containers}}{{.Name}} {{end}}'
ivolvedb ivolveapp

$ docker compose logs --no-color app | tail -3
ivolveapp  | 🔄 Attempting to connect to MySQL...
ivolveapp  | ✅ Connected to MySQL and 'ivolve' DB found.
ivolveapp  | 🚀 Server started on http://0.0.0.0:3000
```

The `ivolve` database exists before the app looks for it because the MySQL image
creates `MYSQL_DATABASE=ivolve` during first initialisation.

```
$ docker compose exec db mysql -uivolveuser -pivolvepass -e \
    "CREATE TABLE IF NOT EXISTS products (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255), price DECIMAL(10,2), image TEXT);
     INSERT INTO products (name, price, image) VALUES ('Red Shirt',29.99,'x'),('Blue Jeans',49.99,'y');
     SELECT id,name,price FROM products;"
id	name	price
1	Red Shirt	29.99
2	Blue Jeans	49.99
```

### 5 — Volumes persist through `compose down`

```
$ docker compose down
 Container ivolveapp  Removed
 Container ivolvedb  Removed
 Network ivolveapp_ivolve-net  Removed

$ docker volume ls --format '{{.Name}}' | grep ivolveapp
ivolveapp_app_logs
ivolveapp_db_data

$ docker compose up -d            # full recreate of containers and network
$ docker compose exec db mysql -uivolveuser -pivolvepass -D ivolve -e "SELECT id,name,price FROM products;"
id	name	price
1	Red Shirt	29.99
2	Blue Jeans	49.99

$ docker compose exec app tail -3 /app/logs/access.log
172.20.0.1 - - [11/Nov/2026:22:37:21 +0000] "GET / HTTP/1.1" 200 2769 "-" "curl/8.5.0"
172.20.0.1 - - [11/Nov/2026:22:37:38 +0000] "GET / HTTP/1.1" 200 2769 "-" "curl/8.5.0"
172.20.0.1 - - [11/Nov/2026:22:38:00 +0000] "GET /health HTTP/1.1" 200 59 "-" "curl/8.5.0"
```

`docker compose down` removes containers **and the network**, but not named
volumes. That is why the rows and the access log are still there after a full
recreate. Only `docker compose down -v` destroys them.

### 6 — Tag and push

The deck asks for the image to be tagged with a Docker Hub username and pushed.
This machine has no Docker Hub credentials (`~/.docker/config.json` is `{}`), so a
local `registry:2` plays the registry role. **The commands are the same; only the
host part of the image reference changes.**

```
$ docker tag eslamnabawy/ivolveapp:lab8 localhost:5000/eslamnabawy/ivolveapp:lab8
$ docker push localhost:5000/eslamnabawy/ivolveapp:lab8
...
lab8: digest: sha256:1ec7a7bb254a25db904fb1357051d70d25ea64c67585bee5339369840f21e40e size: 856

$ curl -s http://localhost:5000/v2/_catalog
{"repositories":["eslamnabawy/ivolveapp"]}
$ curl -s http://localhost:5000/v2/eslamnabawy/ivolveapp/tags/list
{"name":"eslamnabawy/ivolveapp","tags":["lab8"]}
```

The round trip was proven by deleting the local tag and pulling it back:

```
$ docker rmi localhost:5000/eslamnabawy/ivolveapp:lab8
$ docker pull localhost:5000/eslamnabawy/ivolveapp:lab8
Digest: sha256:1ec7a7bb254a25db904fb1357051d70d25ea64c67585bee5339369840f21e40e
Status: Downloaded newer image for localhost:5000/eslamnabawy/ivolveapp:lab8
```

With real credentials the only edit is:

```bash
docker login
docker tag eslamnabawy/ivolveapp:lab8 eslamnabawy/ivolveapp:lab8   # already the Hub name
docker push eslamnabawy/ivolveapp:lab8
```

---

## Things worth knowing

1. **`depends_on` alone only waits for the container to *start*.** The
   `condition: service_healthy` form waits for the healthcheck, which is why the
   app never enters its 10-retry connection loop here.
2. **The healthcheck is `mysqladmin ping`, not a TCP check.** MySQL's TCP port
   opens before the server accepts authenticated queries, so a TCP check would let
   the app start too early.
3. **`MYSQL_DATABASE` does two things**: creates `ivolve`, and grants `MYSQL_USER`
   access to it. The app never runs `CREATE DATABASE`.
4. **Project prefixing.** Compose prefixes resources with the directory name —
   `ivolveapp_db_data`, `ivolveapp_ivolve-net`. The logical names in the YAML stay
   `db_data` and `ivolve-net`, as the slide asks.
5. **`db.js` is not wired into `server.js` in this revision.** It contains the
   `products` DDL and seed rows, but the running server only connects and serves
   the static frontend. The table above was created with that file's own DDL to
   prove persistence — the app does not create it itself. That is upstream
   behaviour, not a lab bug.
6. **Credentials in the YAML are throwaway.** A real stack reads them from an
   `.env` file or a secret store; committing `ivolvepass` would be a finding in any
   review.

## Reproduce

```bash
bash ~/iVolve-Tasks/Docker/Lab8/commands.sh
```

## Clean up

```bash
cd ~/labs-workspace/iVolveApp && docker compose down -v
docker rm -f lab8-registry
docker rmi eslamnabawy/ivolveapp:lab8
```

## Commit

```bash
cd ~/iVolve-Tasks
git add Docker/Lab8
git commit -m "feat(lab8): compose stack with MySQL, named volumes and custom network"
```
