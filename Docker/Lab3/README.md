# Lab 3 — Creating a Docker Image for a Java Application

**Track:** Docker · **Source:** https://github.com/Ibrahim-Adel15/CalculatorMavenApp.git

Build the same app two ways, compare the images, explain the gap.

## Requirements (from the lab)

**Part 1 — Build inside Docker**
- [ ] Dockerfile using a Maven image with Java 17
- [ ] Create a working directory and a non-root user
- [ ] Copy the source and build with `mvn package`
- [ ] Run the generated JAR, expose port 8080
- [ ] Build image `app1`, note its size
- [ ] Run `container1`, verify the app, then delete container and image

**Part 2 — Build locally**
- [ ] Build the app locally with Maven
- [ ] Dockerfile using a Java 17 **runtime** image
- [ ] Create a working directory and a non-root user
- [ ] Copy the generated JAR in, expose port 8080
- [ ] Build image `app2`, note its size
- [ ] Run `container2`, verify the app, then delete container and image

**Bonus** — compare the sizes and explain the difference.

---

## Read this before you start

### The app has no web server

`Main.java` reads from `System.in` with a `Scanner` and exits. Nothing binds a socket. So:

- **`EXPOSE 8080` does nothing here.** `EXPOSE` is metadata — a label in the image saying "this is the port I'd use", read by humans and by tooling like `docker run -P`. It opens no port and starts no listener. You'll include it because the lab asks, and now you know what it actually is.
- **Verifying is not `curl`.** It's running the container, typing numbers, and seeing correct math.
- **You must run with `-i`.** Without `--interactive`, the container's stdin is closed, `scanner.nextDouble()` gets EOF immediately, and the app crashes with `NoSuchElementException`. Use `docker run -it`. When this happens to you — and it will — you'll know exactly why.

### Setup

```bash
docker ps
```

If that errors with "cannot connect to the Docker daemon", start it: `sudo service docker start`.

Work from a clone outside this repo:

```bash
mkdir -p ~/labs-workspace && git clone https://github.com/Ibrahim-Adel15/CalculatorMavenApp.git ~/labs-workspace/CalculatorMavenApp 2>/dev/null; ls ~/labs-workspace/CalculatorMavenApp
```

---

## Part 1 — Build inside Docker

The whole build happens in the container. The host needs nothing but Docker.

### Write the Dockerfile

Create `Dockerfile.app1` in `~/labs-workspace/CalculatorMavenApp/`. Write it yourself first — you learn nothing from pasting. Instructions you need, in order:

| Instruction | Purpose |
|---|---|
| `FROM` | Base image. Use `maven:3.9-eclipse-temurin-17` — Maven with JDK 17 |
| `WORKDIR` | Sets the working directory, creating it if absent |
| `RUN useradd` | Create the non-root user |
| `COPY` | Copy source from host build context into the image |
| `RUN mvn package` | Build inside the image |
| `USER` | Switch to the non-root user for everything after |
| `EXPOSE` | Declare port 8080 (metadata) |
| `ENTRYPOINT` | The command the container runs |

Two things to think about while writing it:

1. **Order matters for the build cache.** Docker caches each layer and invalidates everything after the first changed one. Copying `pom.xml` and running a dependency fetch *before* copying `src/` means source edits don't re-download dependencies. Try it the naive way first, then improve it.
2. **When do you switch to the non-root user?** The build needs to write to `/app` and `~/.m2`. Switch too early and `mvn package` fails on permissions. Switch too late and the app runs as root. Decide where `USER` goes — and *why*.

<details>
<summary>Check your work (try first)</summary>

```dockerfile
FROM maven:3.9-eclipse-temurin-17

WORKDIR /app

# Create a non-root user up front; we switch to it after the build
RUN useradd --create-home --shell /bin/bash appuser

# Dependencies first: this layer is cached unless pom.xml changes
COPY pom.xml .
RUN mvn -B dependency:go-offline

# Source changes invalidate only from here down
COPY src ./src
RUN mvn -B clean package

# Hand the build output to the unprivileged user, then drop privileges
RUN chown -R appuser:appuser /app
USER appuser

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/target/calculator.jar"]
```

`USER` sits *after* the build because Maven must write to `/app/target` and the dependency cache. The `chown` hands ownership over before dropping privileges. `-B` is batch mode — no ANSI progress spam in build logs, standard for CI.
</details>

### Build and inspect

```bash
cd ~/labs-workspace/CalculatorMavenApp && docker build -f Dockerfile.app1 -t app1 .
```

```bash
docker images app1
```

Record the size. Expect roughly **500–800 MB**.

### Run and verify

```bash
docker run -it --name container1 app1
```

Type `10`, Enter, `5`, Enter. Confirm `Sum: 15.0`.

Confirm it is genuinely not running as root:

```bash
docker run --rm --entrypoint whoami app1
```

Must print `appuser`, not `root`. `--entrypoint` overrides the image's entrypoint for a one-off command — a useful debugging trick.

### Clean up

```bash
docker rm container1 && docker rmi app1
```

---

## Part 2 — Build locally

Build on the host, ship only the artifact.

### Build the jar on the host

```bash
cd ~/labs-workspace/CalculatorMavenApp && mvn clean package && ls -lh target/calculator.jar
```

### Write the Dockerfile

Create `Dockerfile.app2`. Same structure, two changes: the base image is a **JRE** (`eclipse-temurin:17-jre-alpine` or `:17-jre`), and instead of building you `COPY` the finished jar.

Here the `USER` placement question has a different answer — think about why before you look.

<details>
<summary>Check your work (try first)</summary>

```dockerfile
FROM eclipse-temurin:17-jre-alpine

WORKDIR /app

# Alpine uses BusyBox adduser, not useradd
RUN adduser -D -h /home/appuser appuser

COPY --chown=appuser:appuser target/calculator.jar /app/calculator.jar

USER appuser

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/calculator.jar"]
```

`USER` can come before `ENTRYPOINT` with nothing privileged left to do, because `COPY --chown` sets ownership as it copies — no separate `RUN chown` layer. If you chose `eclipse-temurin:17-jre` (Ubuntu-based) instead of Alpine, use `useradd --create-home appuser`; `adduser -D` is BusyBox syntax and will fail there.
</details>

Add a `.dockerignore` so you don't ship `src/` and the whole `target/` directory into the build context:

```bash
printf 'src/\n.git/\ntarget/*\n!target/calculator.jar\nDockerfile*\n' > ~/labs-workspace/CalculatorMavenApp/.dockerignore
```

### Build, run, verify, clean up

```bash
cd ~/labs-workspace/CalculatorMavenApp && docker build -f Dockerfile.app2 -t app2 .
```

```bash
docker images app2
```

```bash
docker run -it --name container2 app2
```

```bash
docker rm container2 && docker rmi app2
```

---

## Bonus — compare and explain

Before deleting the images, capture both sizes side by side:

```bash
docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}' | grep -E 'app1|app2|REPOSITORY'
```

| Image | Base | Contains | Size |
|---|---|---|---|
| `app1` | `maven:3.9-eclipse-temurin-17` | Full JDK + Maven + dependency cache + source + jar | _fill in_ |
| `app2` | `eclipse-temurin:17-jre-alpine` | JRE + jar | _fill in_ |

**The explanation to write in your own words:** build-time dependencies are not run-time dependencies. Compiling needs a JDK (compiler, debugger, full toolchain), Maven, every downloaded dependency and the source tree. *Running* needs a JVM and one jar. `app1` ships the entire workshop along with the product; `app2` ships only the product.

Beyond size, three real consequences:

- **Attack surface.** Every binary in an image is a potential exploit target. A shipped compiler and package manager are gifts to an attacker who gets code execution.
- **Deploy speed.** Image size is pull time, on every node, on every rollout.
- **Cost.** Registry storage and egress scale with image size across every build you ever push.

### Go further: multi-stage build

This is how production actually resolves the tradeoff — Part 1's reproducibility at Part 2's size. One Dockerfile, two `FROM` lines; only the final stage becomes the image.

```dockerfile
# ---- build stage ----
FROM maven:3.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn -B dependency:go-offline
COPY src ./src
RUN mvn -B clean package

# ---- runtime stage ----
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
RUN adduser -D -h /home/appuser appuser
COPY --from=build --chown=appuser:appuser /app/target/calculator.jar /app/calculator.jar
USER appuser
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/calculator.jar"]
```

```bash
cd ~/labs-workspace/CalculatorMavenApp && docker build -f Dockerfile.multistage -t app3 . && docker images app3
```

`COPY --from=build` reaches into the first stage and takes one file. Everything else in that stage — JDK, Maven, caches, source — is discarded. `app3` should land within a few MB of `app2` while needing nothing on the host but Docker. **This is the real answer to the bonus question**, and demonstrating it with a working image is worth more than a paragraph about it.

---

## Deliverables for this folder

Commit the Dockerfiles you wrote, not the cloned app:

```bash
cp ~/labs-workspace/CalculatorMavenApp/Dockerfile.app1 ~/labs-workspace/CalculatorMavenApp/Dockerfile.app2 ~/labs-workspace/CalculatorMavenApp/.dockerignore "/home/eslam/iVolve-Tasks/Docker/Lab3/"
```

## My output

> Paste `docker images` showing both sizes, and a verified app run from each container.

```
```

## What I learned

> Answer the bonus in your own words. Did you hit the `-i` stdin problem? The `USER`-too-early permission failure?
