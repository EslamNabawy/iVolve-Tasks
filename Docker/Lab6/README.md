# Lab 6 — Docker Environment Variables and Resource Management

**Track:** Docker · **Source:** https://github.com/Ibrahim-Adel15/PythonApp.git

A small Flask app that reads `APP_NAME` and `APP_ENV` at startup and serves them
on port 5000. The lab is about *where those values come from* — the run command,
an env file, or the image itself — and about capping what the container may use.

## Requirements

- [x] Application cloned from the provided repository
- [x] Dockerfile written on `python:3.12-slim`, dependencies installed, port 5000 — [`Dockerfile`](Dockerfile)
- [x] Image built as `ivolve1` — **185 MB**
- [x] `container1` run, port 5000 mapped, `APP_NAME=iVolveApp1` / `APP_ENV=stg`
- [x] Resources limited to **1 CPU** and **256 MB** memory
- [x] Application verified at `http://localhost:5000`
- [x] Environment variables verified inside the container
- [x] CPU/memory monitored with `docker stats`
- [x] [`env.txt`](env.txt) created with `APP_NAME=iVolveApp2` / `APP_ENV=prod`
- [x] `container2` run with the variables loaded from `env.txt`
- [x] New image built with `APP_NAME=iVolveApp3` / `APP_ENV=dev` hardcoded in the Dockerfile — [`Dockerfile.env`](Dockerfile.env)
- [x] `container2` run again and the Dockerfile values validated
- [x] Bonus: proven that a run-time `-e` overrides the Dockerfile `ENV`

---

## Results

| Run | Image | Variables come from | `APP_NAME` | `APP_ENV` |
|---|---|---|---|---|
| `container1` | `ivolve1` | `docker run -e` | `iVolveApp1` | `stg` |
| `container2` | `ivolve1` | `--env-file env.txt` | `iVolveApp2` | `prod` |
| `container2` (again) | `ivolve3` | Dockerfile `ENV` | `iVolveApp3` | `dev` |
| `container3` (bonus) | `ivolve3` | Dockerfile `ENV` + `-e` | `OverrideName` | `dev` |

Same application, same port, same image — only the source of the configuration
changes. That is the whole point of the exercise.

### 1 — `container1`: run-time variables and resource limits

```
$ docker run -d --name container1 -p 5000:5000 \
    --cpus=1 --memory=256m \
    -e APP_NAME=iVolveApp1 -e APP_ENV=stg ivolve1

$ curl -s localhost:5000
{"application":"iVolveApp1","environment":"stg",
 "message":"Welcome to the Docker Env & Resource Management Lab!"}

$ curl -s localhost:5000/health
{"status":"healthy"}

$ docker exec container1 env | grep '^APP_'
APP_ENV=stg
APP_NAME=iVolveApp1

$ docker stats container1 --no-stream
CONTAINER ID   NAME         CPU %     MEM USAGE / LIMIT   MEM %   NET I/O         BLOCK I/O   PIDS
2a5cc5637e2e   container1   0.01%     24.67MiB / 256MiB   9.64%   1.94kB / 1.99kB 197kB / 0B  1
```

The limit is visible twice: `MEM USAGE / LIMIT` reads **256MiB**, and the setting
Docker stored for the container is explicit:

```
$ docker inspect container1 --format 'NanoCpus={{.HostConfig.NanoCpus}} Memory={{.HostConfig.Memory}}'
NanoCpus=1000000000 Memory=268435456
```

`1000000000` nano-CPUs is exactly 1 CPU; `268435456` bytes is 256 MiB. This is
worth checking — `docker stats` shows what is *used*, `docker inspect` shows what
is *enforced*.

The Flask process used 24.67 MiB of its 256 MiB allowance, so the cap is real but
not tight.

### 2 — `container2`: variables from `env.txt`

```
$ cat env.txt
APP_NAME=iVolveApp2
APP_ENV=prod

$ docker run -d --name container2 -p 5000:5000 --env-file env.txt ivolve1
$ curl -s localhost:5000
{"application":"iVolveApp2","environment":"prod", ...}

$ docker exec container2 env | grep '^APP_'
APP_ENV=prod
APP_NAME=iVolveApp2
```

### 3 — `container2`: variables baked into the image

```
$ docker build -f Dockerfile.env -t ivolve3 .
$ docker run -d --name container2 -p 5000:5000 ivolve3
$ curl -s localhost:5000
{"application":"iVolveApp3","environment":"dev", ...}

$ docker exec container2 env | grep '^APP_'
APP_ENV=dev
APP_NAME=iVolveApp3

$ docker inspect ivolve3 --format '{{json .Config.Env}}'
[...,"APP_NAME=iVolveApp3","APP_ENV=dev"]
```

The variables are part of the image configuration — `docker inspect` finds them
even before a container exists. Note the **slide reuses the name `container2`**
for this third run: the previous container was stopped and deleted first, so the
name is free.

### 4 — Bonus: precedence

```
$ docker run -d --name container3 -p 5001:5000 -e APP_NAME=OverrideName ivolve3
$ curl -s localhost:5001
{"application":"OverrideName","environment":"dev", ...}
```

`APP_NAME` came from the command line, `APP_ENV` still came from the image. The
order is: **`docker run -e` / `--env-file` beats the Dockerfile `ENV`.**

---

## Why the app needs the variables

`app.py` fails fast rather than starting half-configured:

```python
if not APP_NAME or not APP_ENV:
    raise ValueError("APP_NAME and APP_ENV environment variables are required")
```

Proven, not assumed:

```
$ docker run --rm ivolve1
ValueError: APP_NAME and APP_ENV environment variables are required
```

That is a deliberate design choice: a container that cannot serve correctly
should exit loudly, not run and return `null` to users.

---

## The Dockerfile

```dockerfile
FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
RUN useradd --create-home --shell /bin/bash appuser
COPY --chown=appuser:appuser app.py .
USER appuser
EXPOSE 5000
CMD ["python", "app.py"]
```

Four decisions worth naming:

- **`requirements.txt` before `app.py`** — editing the app does not trigger a
  `pip install` on rebuild.
- **`--no-cache-dir`** — pip's download cache is build waste; it would add tens of
  MB to a 185 MB image.
- **Non-root `appuser`** — Flask needs no privileges, and the files are copied
  with `--chown` so the user can read them.
- **`PYTHONUNBUFFERED=1`** — without it, `docker logs` can appear empty because
  Python buffers stdout when it is not a TTY.

---

## Things worth knowing

**`docker stats cont1` in the slide is a typo.** The container is named
`container1`; `cont1` returns "No such container". Used `container1`.

**`--cpus=1` and `--memory=256m` are hard limits.** The CPU quota is enforced by
the CFS scheduler (1 CPU = 100 ms of CPU time per 100 ms period), and memory is
enforced by the cgroup — exceed it and the kernel OOM-kills the process rather
than letting it swap. Neither changes the *app*, which is why the same image
runs identically with and without limits.

**`--env-file` is not shell sourcing.** Each line is a literal `KEY=VALUE`; no
quotes are stripped, no variables are expanded, and `#` comments are skipped.
That is why `env.txt` has no `export`.

**Where the values live matters.**
- In the run command: visible to anyone who can read the process list or
  `docker inspect`, and lost when the container is deleted.
- In the image: baked in, same for every container, and a rebuild is needed to
  change it — fine for a default, wrong for a secret.
- In an env file: shareable, reviewable, and easy to keep out of git.

**Rebuilding `ivolve3` is nearly free** because every layer except the final
`ENV` change was cached — the build finished in 0.2 s. That is layer caching
working as intended.

---

## Commit this lab

```bash
cd ~/iVolve-Tasks && git add Docker/Lab6 && \
  git commit -m "feat(lab6): manage env vars and resource limits with Docker" && git push
```
