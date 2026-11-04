# Lab 8 — Jenkins: automate Labs 1–6 as one pipeline

**Track:** CI/CD · **Controller:** Jenkins LTS in Docker · **Job:** `ivolve-labs-1-6` · **Pipeline:** `Jenkins/Lab8/Jenkinsfile`

> This lab is the CI/CD track's first item: *"Jenkins — run Labs 1–6 automatically as a pipeline."*
> Everything below was executed on this machine against the real upstream
> apps. Controller is configured entirely as code (JCasC) — no setup
> wizard, no browser clicks. Docker builds run on the host daemon via the
> mounted socket; the unrelated `aiops-*` containers are never touched.

## Requirements

- [x] Jenkins CI image built with git, Docker CLI, Maven, JDK 17, Gradle 9.8.2, Trivy 0.76.1
- [x] Controller started with Configuration as Code (admin user + pipeline job from `jenkins.yaml`)
- [x] Pipeline triggers via crumb + cookie POST and reaches `SUCCESS`
- [x] Lab 1 Maven tests run and recorded (junit trend, 10 tests, 0 failures)
- [x] Lab 2 Gradle build runs with JDK 17 and produces the jar
- [x] Lab 3 image built and asserted via piped stdin (`10/5` → Sum 15.0 …)
- [x] Lab 4 images built and size-compared; app responds `HTTP 200`
- [x] Lab 5 Trivy gate passes on `HIGH,CRITICAL` after remediation (DB warm, lockfile regenerated)
- [x] Lab 6 container runs with env vars, `/health` healthy, 256 MiB limit shown by `docker stats`
- [x] Pipeline cleans up its own six images; lab containers removed
- [x] `aiops-*` containers untouched

## Results

| Check | Result |
|---|---|
| Pipeline | **Build 11 — `SUCCESS`** · 194,833 ms (194.8 s) · 1,648 console lines · checked out `d61d06d` |
| junit | `failCount 0`, `skipCount 0`, `totalCount 10` |
| Lab 1 Maven | `Tests run: 5, Failures: 0, Errors: 0` · `BUILD SUCCESS` · `calculator.jar 3.7K` |
| Lab 2 Gradle | `BUILD SUCCESSFUL in 8s` / `in 2s` · jar `2.3K` |
| Lab 3 containerize | `whoami → appuser` · `Sum: 15.0 / Subtract: 5.0 / Multiply: 50.0 / Divide: 2.0` |
| Lab 4 optimize | `image1:latest 671MB` / `image2:latest 294MB` · `Hello from Dockerized Spring Boot!` `HTTP 200` · `uid=100(appuser) gid=101(appgroup)` |
| Lab 5 scan + gate | Trivy `0.76.1`, DB v2 `2026-11-01 13:02:34` · `trivy image --exit-code 1 --severity HIGH,CRITICAL ivolve-app:v2` → Report Summary all 0 → passed |
| Lab 6 env + limits | `{"application":"iVolveApp1","environment":"stg","message":"Welcome to the Docker Env & Resource Management Lab!"}` · `/health {"status":"healthy"}` · `25.9MiB/256MiB 10.12%` |
| Cleanup | `docker rmi` six pipeline images → all `Untagged/Deleted` · `none of the six pipeline images left` |
| Post | `Recording test results` (junit) · `Trivy v1 report` (publishHTML) · `Finished: SUCCESS` |

Build history (Jenkins API): 1 FAILURE 193.4 s · 2 FAILURE 4.1 s · 3 FAILURE 79.1 s · 4 FAILURE 240.5 s ·
5 ABORTED 1,770.4 s · 6 FAILURE 1,835.0 s · 7 ABORTED 356,668.6 s · 8 FAILURE 135.3 s · 9 FAILURE 181.0 s ·
10 ABORTED 5,417.9 s · **11 SUCCESS 194.8 s**.

## Steps

### 1 — Build the CI image

`Dockerfile` bakes every tool Labs 1–6 use into the official Jenkins LTS image:
git, Docker CLI, Maven, Temurin JDK 17, Gradle 9.8.2, Trivy 0.76.1, and the
Pipeline plugins from `plugins.txt`. No daemon runs inside the container —
the CLI talks to the host daemon through the mounted socket.

```console
$ docker build -t ivolve-jenkins:lab8 Jenkins/Lab8
# (image built; full build log captured in session)
```

### 2 — Start Jenkins with Configuration as Code

`commands.sh` starts `jenkins-lab8` with same-path mounts
(`~/iVolve-Tasks` and `~/jenkins-home` at identical host paths), the Docker
socket with the docker group id `1001`, the JCasC file, and admin
credentials from environment — never written into the repo:

```console
$ docker run -d --name jenkins-lab8 -p 127.0.0.1:8080:8080 \
    -v /var/run/docker.sock:/var/run/docker.sock --group-add 1001 \
    -v ~/iVolve-Tasks:~/iVolve-Tasks:ro -v ~/iVolve-Tasks:/repo:ro \
    -v Jenkins/Lab8/jenkins.yaml:/var/jenkins_home/casc/jenkins.yaml:ro \
    -v ~/jenkins-home:~/jenkins-home \
    -e JENKINS_HOME=~/jenkins-home -e CASC_JENKINS_CONFIG=/var/jenkins_home/casc \
    -e JENKINS_ADMIN_ID=ivolve-admin -e JENKINS_ADMIN_PASSWORD=ivolve-admin \
    -e TRIVY_CACHE_DIR=~/jenkins-home/.cache/trivy \
    ivolve-jenkins:lab8
```

`jenkins.yaml` declares the admin user, one executor, and the pipeline job
`ivolve-labs-1-6`, which checks out this repository itself via
`file:///repo` (a local path is a valid git remote — no network needed for
the checkout) and runs `Jenkins/Lab8/Jenkinsfile`.

### 3 — Trigger and wait for the verdict

The job already exists, so `commands.sh` triggers it with the standard
crumb + cookie flow and polls the API until `result` is set:

```console
$ curl -s -c jar -u ivolve-admin:ivolve-admin http://127.0.0.1:8080/crumbIssuer/api/json
$ curl -s -b jar -c jar -u ivolve-admin:ivolve-admin -H "Jenkins-Crumb:..." -X POST http://127.0.0.1:8080/job/ivolve-labs-1-6/build
trigger HTTP 201 (want 201)
pipeline result: SUCCESS
```

### 4 — What each stage proved (from the green console)

Console: 1,648 lines. Stage markers: `Checkout SCM` (line 23), `Lab 1 - Maven`
(54), `Lab 2 - Gradle` (155), `Lab 3 - Containerize` (200), `Lab 4 - Optimize`
(284), `Lab 5 - Scan and gate` (1,214), `Lab 6 - Env and limits` (1,531),
`Cleanup pipeline images` (1,607), `Post Actions` (1,625).

- **Lab 1 — Maven:** upstream `CalculatorMavenApp` cloned, `mvn -B test` →
  `Tests run: 5, Failures: 0, Errors: 0`, then `mvn -B clean package` →
  `BUILD SUCCESS`, `target/calculator.jar 3.7K`.
- **Lab 2 — Gradle:** `CalculatorGradleApp` cloned, `gradle test` →
  `BUILD SUCCESSFUL in 8s`, `gradle clean build` → `in 2s`,
  `build/libs/calculator.jar 2.3K`.
- **Lab 3 — Containerize:** image `ivolve-ci:lab3` built from the repo's
  `Docker/Lab3/Dockerfile.multistage`; `--entrypoint whoami` → `appuser`;
  `printf "10\n5\n" | docker run -i --rm` →
  `Sum: 15.0 / Subtract: 5.0 / Multiply: 50.0 / Divide: 2.0`.
- **Lab 4 — Optimize:** `image1 671MB` vs `image2 294MB`; `ci-lab4` on
  `:8081` → `Hello from Dockerized Spring Boot!  HTTP 200`;
  `uid=100(appuser) gid=101(appgroup)`.
- **Lab 5 — Scan and gate:** `trivy --version` → `0.76.1`; DB warmed from
  `ghcr.io` (`131.49 MiB` in ~60 s, `UpdatedAt 2026-11-01 13:02:34`);
  `trivy-lab:v1` scanned (HIGH/CRITICAL on EOL Debian 11 — the evidence
  Lab 5 remediated); lockfile regenerated with
  `node:24-alpine npm install express@latest --package-lock-only`;
  `ivolve-app:v2` built from `Docker/Lab5/Dockerfile.v2`; gate
  `trivy image --exit-code 1 --severity HIGH,CRITICAL` → Report Summary
  all 0 (Alpine 3.24.3 + every bundled node package) → passed. HTML report
  via the committed template → published as `Trivy v1 report`.
- **Lab 6 — Env and limits:** `ivolve1` built, run as
  `ci-lab6 -p 5000:5000 --cpus=1 --memory=256m -e APP_NAME=iVolveApp1 -e APP_ENV=stg`;
  `/` → `{"application":"iVolveApp1","environment":"stg","message":"Welcome to the Docker Env & Resource Management Lab!"}`;
  `/health` → `{"status":"healthy"}`; `docker stats` → `25.9MiB/256MiB 10.12%`.

### 5 — Cleanup (pipeline + lab)

The Cleanup stage removes exactly the six pipeline images
(`ivolve-ci:lab3 image1 image2 trivy-lab:v1 ivolve-app:v2 ivolve1`) — never
`docker system prune`. `post/always` removes `ci-lab4` / `ci-lab6` even if a
stage dies first. `commands.sh` additionally verifies `no pipeline images
left`, then removes `jenkins-lab8`, the CI image and `~/jenkins-home`.

## Why this lab looks different from every Docker lab

**The network is flaky, so every network touch in the pipeline retries.**
Builds 1–10 failed on this machine's network before build 11 went green:

| Build | Result | Cause (from the raw logs) |
|---|---|---|
| 1 | FAILURE 193.4 s | `git clone` connect timeout after 131,961 ms → exit 128 |
| 2 | FAILURE 4.1 s | `destination path 'CalculatorMavenApp' already exists` → exit 128 |
| 3 | FAILURE 79.1 s | spring-boot repackage — `Failed to read artifact descriptor` |
| 4 | FAILURE 240.5 s | `TrivyImage` clone `Failed to connect … after 130,715 ms` |
| 5 | ABORTED 1,770.4 s | `failed to solve: context canceled` + `Timeout has been exceeded` (30-min timeout) |
| 6 | FAILURE 1,835.0 s | clone `Connection reset by peer` + Maven `Could not resolve dependencies` |
| 7 | ABORTED 4 days 1 hr | `Timeout expired` → `Finished: ABORTED` |
| 8 | FAILURE 135.3 s | Trivy DB from `mirror.gcr.io` stalls at ~0.25 % of 131.24 MiB → exit 1 |
| 9 | FAILURE 181.0 s | `npm ci` exit code 152 inside `Dockerfile.v2` |
| 10 | ABORTED 5,417.9 s | Maven Central `Read timed out` after 1,823.8 s |
| 11 | **SUCCESS 194.8 s** | — (all fixes in) |

The fixes that carried build 11 over the line:
14 lab-scoped fixes — workspace wipe, 5× retry with 20 s backoff around
every clone, Docker build, Maven/Gradle/npm and DB download; warmed Trivy
cache; 90-minute pipeline timeout; and `TRIVY_DB_REPOSITORY='ghcr.io/aquasecurity/trivy-db:2'`
(the mirror resets mid-transfer here and Trivy fails hard instead of
falling back). Nothing was mocked: the same commands that fail standalone
on a bad network minute are retried until one is genuinely green.

## Things worth knowing

1. **Same-path mounts are the Docker-in-Docker trick here.** The container
   holds no daemon; the CLI sends every request to the host daemon, so the
   daemon must resolve build-context paths at the exact same paths the
   pipeline sees them (`~/iVolve-Tasks`, `~/jenkins-home`).
2. **The socket needs its group id.** The host docker group is `1001`;
   without `--group-add 1001` user `jenkins` cannot open the socket.
3. **A warm Trivy cache beats a bigger timeout.** The DB is 131 MiB; the
   mirror stalls at ~0.25 %. `ghcr.io` completes in ~60 s, and the cache
   lives under `JENKINS_HOME` so only the first build pays for it.
4. **`deleteDir()` is the re-run fix.** Without it, a second build sees a
   non-empty `CalculatorMavenApp/` and `git clone` exits 128.
5. **Checkout needs no network and no GitHub credentials:** `file:///repo`
   is a mounted local path, and the job runs `scriptPath('Jenkins/Lab8/Jenkinsfile')`
   from `main` — what Jenkins runs is always what the repo holds.
6. **junit and publishHTML publish even on failure** (`post/always`) — the
   trend graph and the Trivy HTML report exist for red builds too.
7. **This README's numbers trace to build 11's console** (1,648 lines,
   `d61d06d` checkout, 30 CACHED layers) — the only green run. Builds 1–10
   are recorded above as the failure ledger, not as results.

## Commit this lab

```bash
cd ~/iVolve-Tasks
git add Jenkins/Lab8
git commit -m "feat(lab8): Jenkins pipeline automating Labs 1-6"
```
