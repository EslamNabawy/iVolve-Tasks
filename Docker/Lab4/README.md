# Lab 4 — Docker Image Optimization and Export/Load

**Track:** Docker · **Source:** https://github.com/Ibrahim-Adel15/ImageOptimization-.git

A Spring Boot web app: build it the way the repo does (JDK + Maven inside the
image), then build it again properly (multi-stage, JRE only, non-root), compare
the two, and prove an image survives a `save` → `rmi` → `load` round trip.

## Requirements

- [x] Application cloned from the provided repository
- [x] Image built from the existing `Dockerfile` as `image1` — [`Dockerfile`](Dockerfile)
- [x] Image size noted — **671 MB**
- [x] Container `container1` run from `image1`, application verified
- [x] `container1` stopped and deleted
- [x] Multi-stage Dockerfile written — [`Dockerfile.multistage`](Dockerfile.multistage)
- [x] Application configured to run as a **non-root** user
- [x] Optimized image built as `image2` — **294 MB**
- [x] Sizes compared: `image2` is **2.28× smaller**
- [x] Container `container2` run from `image2`, application verified, non-root proven
- [x] `container2` stopped and deleted
- [x] `image2` saved as `lab-image.tar` — **82 MB**
- [x] `image2` deleted from the local Docker host
- [x] Image loaded back from the tar and verified in `docker images`
- [x] Restored image run again to confirm it still works

---

## Results

| Image | Stages | Base | Contains | Size |
|---|---|---|---|---|
| `image1` | 1 | `maven:3.9.15-eclipse-temurin-17-alpine` | JDK + Maven + `~/.m2` + source + fat jar | **671 MB** |
| `image2` | 2 | `eclipse-temurin:17-jre-alpine` | JRE + fat jar (19.6 MB) | **294 MB** |

```
$ docker images --format '{{.Repository}}:{{.Tag}}  {{.Size}}' | grep -E '^image[12]:'
image2:latest  294MB
image1:latest  671MB
```

**671 → 294 MB: 377 MB removed, a 2.28× reduction.** The whole Spring Boot fat
jar is 19.6 MB, so almost none of either image is the application.

### Verification — `container1` (image1)

```
$ docker run -d --name container1 -p 8080:8080 image1
$ curl -s -w '\nHTTP %{http_code}\n' localhost:8080
Hello from Dockerized Spring Boot!
HTTP 200

$ docker logs container1 | tail -2
... Tomcat started on port 8080 (http) with context path ''
... Started DemoApplication in 1.74 seconds (process running for 2.14)
```

Unlike Lab 3's calculator, this app really listens on its port — so `-p` and
`EXPOSE 8080` are functional here, not decoration.

### Verification — `container2` (image2)

```
$ docker run -d --name container2 -p 8080:8080 image2
$ curl -s -w '\nHTTP %{http_code}\n' localhost:8080
Hello from Dockerized Spring Boot!
HTTP 200

$ docker exec container2 whoami
appuser
$ docker exec container2 id
uid=100(appuser) gid=101(appgroup) groups=101(appgroup)
$ docker exec container2 ls -l /app/app.jar
-rw-r--r-- 1 appuser appgroup 19626337 ... /app/app.jar
$ docker run --rm --entrypoint whoami image2
appuser
```

The last line matters: `docker run --entrypoint whoami` bypasses the app, so it
proves the **image** default user is non-root, not just the running process.

### Export / load round trip

```
$ docker save image2 -o lab-image.tar
$ ls -lh lab-image.tar
-rw------- 1 eslam eslam 82M ... lab-image.tar
$ file lab-image.tar
lab-image.tar: POSIX tar archive

$ docker rmi image2
Untagged: image2:latest
Deleted: sha256:e9da01ba8311...
$ docker images | grep image2 || echo 'image2 is gone'
image2 is gone

$ docker load -i lab-image.tar
Loaded image: image2:latest
$ docker images | grep image2
image2:latest  294MB  e9da01ba8311

$ docker run -d --name container2 -p 8080:8080 image2 && curl -s localhost:8080
Hello from Dockerized Spring Boot!
```

The loaded image keeps its name, tag, size and ID — a tar is a complete copy of
the image, not a reference to it.

---

## The optimization, explained

**What you need to BUILD is not what you need to RUN.** Compiling needs a JDK,
Maven, and the whole dependency tree; running needs a JVM and one jar. `image1`
ships the workshop with the product. The multi-stage build keeps the workshop in
stage 1 and copies exactly one file into stage 2:

```dockerfile
COPY --from=build --chown=appuser:appgroup \
     /build/target/demo-0.0.1-SNAPSHOT.jar app.jar
```

Everything else in stage 1 — JDK, Maven, `~/.m2`, the source — is discarded.

Three changes do the work:

1. **Two stages instead of one** — build tooling never becomes a layer of the final image.
2. **JRE instead of JDK** — `eclipse-temurin:17-jre-alpine` has no compiler.
3. **Alpine instead of a full distro** — a few MB of base OS instead of ~70 MB.

### Non-root, properly

`image1` runs as root because the Maven base image does. In `image2` a dedicated
user is created *before* the copy, and `COPY --chown` hands the jar to it:

```dockerfile
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
COPY --from=build --chown=appuser:appgroup /build/target/... app.jar
USER appuser
```

`USER` must come after the `COPY` here — otherwise Docker cannot write the
file into the image as that user's owner. Alpine uses `adduser`/`addgroup`
(BusyBox), not `useradd`; the base image decides the available tooling.

---

## Things worth knowing

**The build stalled, and it was not Maven's fault.** Two builds froze at 0% CPU
inside `RUN mvn package`, after the same download, for 20+ minutes. Maven Central
was reachable from a normal container (`wget` of a POM took 0.3 s), so the
problem was BuildKit's sandboxed network path, not the registry. Fix:

```bash
docker build --network=host ...          # build steps share the host network
ENV MAVEN_OPTS="-Djava.net.preferIPv4Stack=true"   # don't try IPv6 first
```

After both changes the build finished in **31 seconds** from a warm layer cache.
`--network=host` is a build-time workaround, not something baked into the image.

**The slide says two different filenames.** "Save `image2` as a TAR file named
`lab-image.tar`" … then "Load the image from `image2.tar`". There is one file:
`lab-image.tar`, and that is the name used here for both save and load.

**A cache mount keeps rebuilds fast without growing the image.** `RUN --mount=type=cache,target=/root/.m2`
stores Maven's dependency cache outside the image layers: source edits reuse the
downloaded dependencies, and none of them are shipped. Even better for layer
reuse is copying `pom.xml` before `src/` and resolving dependencies first —
which is what the multi-stage file does here.

**`.dockerignore` again.** [`​.dockerignore`](.dockerignore) excludes `.git`,
`target` and markdown. It must not exclude `src/` — stage 1 compiles from it.
The same trap as Lab 3, in a different project.

**Image size is not the only axis.** `image1` is self-contained and reproducible
anyone with Docker can rebuild it identically. `image2` is smaller, but its
build still depends on Maven Central being up at build time. Multi-stage gives
you both: reproducible *and* small.

---

## Commit this lab

```bash
cd ~/iVolve-Tasks && git add Docker/Lab4 && \
  git commit -m "feat(lab4): optimize Spring Boot image with multi-stage build and add save/load" && git push
```
