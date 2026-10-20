# Lab 3 — Creating a Docker Image for a Java Application

**Track:** Docker · **Source:** https://github.com/Ibrahim-Adel15/CalculatorMavenApp.git

Build the same application two ways, compare the images, explain the difference.

## Requirements

**Part 1 — Build inside Docker**
- [x] Dockerfile using a Maven image with Java 17 — [`Dockerfile.app1`](Dockerfile.app1)
- [x] Working directory and a non-root user
- [x] Copy source, build with `mvn package`
- [x] Run the JAR, expose port 8080
- [x] Image named `app1`, size noted — **861 MB**
- [x] Ran `container1`, verified, deleted container and image

**Part 2 — Build locally**
- [x] Built locally with Maven
- [x] Dockerfile using a Java 17 **runtime** image — [`Dockerfile.app2`](Dockerfile.app2)
- [x] Working directory and a non-root user
- [x] Copy the JAR in, expose port 8080
- [x] Image named `app2`, size noted — **265 MB**
- [x] Ran `container2`, verified, deleted container and image

**Bonus**
- [x] Sizes compared and explained
- [x] Multi-stage build as `app3` — [`Dockerfile.multistage`](Dockerfile.multistage)

---

## Results

| Image | Base | Contains | Size |
|---|---|---|---|
| `app1` | `maven:3.9-eclipse-temurin-17` | JDK + Maven + dependency cache + source + JAR | **861 MB** |
| `app2` | `eclipse-temurin:17-jre-alpine` | JRE + JAR | **265 MB** |
| `app3` | multi-stage → JRE Alpine | JRE + JAR | **265 MB** |

```
REPOSITORY   TAG       SIZE
app1         latest    861MB
app2         latest    265MB
app3         latest    265MB
```

**`app1` is 3.25× the size of `app2`** — 596 MB of pure build tooling.

### Verification — all three

```
$ printf '10\n5\n' | docker run -i --name container1 app1
Enter first number: Enter second number: a = 10.0, b = 5.0
Sum: 15.0
Subtract: 5.0
Multiply: 50.0
Divide: 2.0

$ docker run --rm --entrypoint whoami app1
appuser
```

`app2` produced identical output. `app3` was checked with different inputs (7 and 3)
to confirm it is genuinely computing, not echoing a cached result:

```
a = 7.0, b = 3.0
Sum: 10.0   Subtract: 4.0   Multiply: 21.0   Divide: 2.3333333333333335
```

All three print `appuser`, not `root` — the non-root requirement is met and proven.

### Cleanup

```bash
docker rm -f container1 container2 && docker rmi app1 app2 app3
```

Both containers and all three images removed, as the lab requires.

---

## The bonus answer

**What you need to BUILD is not what you need to RUN.**

Compiling requires a JDK (compiler and full toolchain), Maven itself, every
downloaded dependency, and the source tree. *Running* requires a JVM and one
3.7 KB jar. `app1` ships the entire workshop alongside the product; `app2` ships
only the product.

Two changes produce the 596 MB saving:

- **JRE instead of JDK** — no compiler, because nothing is compiled at runtime.
- **Alpine instead of Ubuntu** — a ~5 MB base instead of ~75 MB.

Size is the visible symptom. Three consequences matter more:

1. **Security.** Every tool in an image is a potential exploit target. Shipping a
   compiler, a build tool and a package manager hands an attacker who achieves
   code execution a complete toolkit.
2. **Deploy speed.** Image size is pull time — on every node, on every rollout.
3. **Cost.** Registry storage and egress scale with size, on every build forever.

### But `app2` has a real weakness

`app2` is smaller, yet its build is **not reproducible**: it depends on the host
having the right JDK and the right file already sitting in `target/`. `app1` is
fully self-contained — anyone with Docker gets an identical result.

So neither is simply better: **Part 1 buys reproducibility, Part 2 buys size.**

### Multi-stage resolves the trade-off

`Dockerfile.multistage` uses two `FROM` stages; only the last becomes the image.
`COPY --from=build` reaches into the build stage and takes **one file** — the JDK,
Maven, dependency cache and source are discarded entirely.

**Result: `app3` is 265 MB — identical to `app2` — while needing nothing on the
host but Docker.** That is Part 1's reproducibility at Part 2's size, and it is
what production actually uses.

---

## Things worth knowing

**`EXPOSE 8080` does nothing here.** This app reads from stdin and listens on no
port. `EXPOSE` is metadata — a label in the image, read by humans and by
`docker run -P`. It opens no socket. It is included because the lab asks for it.

**`docker run` needs `-i`.** Without `--interactive` the container's stdin is
closed, `scanner.nextDouble()` hits EOF immediately, and the app dies. Confirmed
deliberately:

```
$ docker run --rm app1        # no -i
    at java.base/java.util.Scanner.nextDouble(Scanner.java:2564)
    at com.example.calculator.Main.main(Main.java:12)
```

**Where `USER` goes differs between the two Dockerfiles.** In `app1` it must come
*after* `mvn package`, because Maven writes to `/app/target` and `~/.m2`; placing
it earlier fails on permissions. In `app2` it can come earlier — there is no build,
and `COPY --chown` already set ownership.

**Alpine uses `adduser`, not `useradd`.** BusyBox provides different utilities;
`useradd` gives "command not found" on Alpine. The base image dictates the
available tooling.

**Layer order is a design decision.** Both the Maven-based Dockerfiles copy
`pom.xml` and resolve dependencies *before* copying `src/`. Docker invalidates
every layer after the first changed one, so editing a `.java` file reuses the
cached dependency layer instead of re-downloading.

**A `.dockerignore` bug worth recording.** The first version excluded `src/`,
which works for `app2` (it only copies the finished jar) but **breaks `app1` and
the multi-stage build**, since both compile from source. One build context serves
all three Dockerfiles, so [`.dockerignore`](.dockerignore) keeps `src/` and
excludes only `.git/` and `target/*` (re-including the jar `app2` needs).

---

## Commit this lab

```bash
cd ~/iVolve-Tasks && git add Docker/Lab3 && git commit -m "feat(lab3): add Dockerfiles for app1, app2 and multi-stage build" && git push
```
