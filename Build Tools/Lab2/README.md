# Lab 2 — Building and Packaging a Java Application with Gradle

**Track:** Build Tools · **Source:** https://github.com/Ibrahim-Adel15/CalculatorGradleApp.git

> **Correction to the lab slide.** The title reads *"Building and Packaging **Go**
> Application with Gradle"*. The repository is **Java** — the same
> `Calculator.java` and `Main.java` as Lab 1. The slide has a copy-paste error;
> it was built as Java.

## Requirements

- [x] Install Gradle
- [x] Clone the source code
- [x] Run unit tests
- [x] Build the app — artifact in `build/libs/calculator.jar`
- [x] Run the app
- [x] Verify the app is working

Full command sequence: [`commands.sh`](commands.sh)

---

## Steps and results

### 1. Install Gradle

**Not with apt** — Ubuntu 24.04 ships Gradle 4.4 (2017), which fails on this
project's `toolchain` block (added in Gradle 6.7).

The standard route is SDKMAN, but it requires the `zip` package, which was not
installed and needs `sudo` to add. Gradle was installed from the official binary
distribution instead — no `sudo`, and `unzip` alone is enough:

```bash
VER=$(curl -s https://services.gradle.org/versions/current | python3 -c "import sys,json;print(json.load(sys.stdin)['version'])")
curl -sL -o /tmp/gradle.zip "https://services.gradle.org/distributions/gradle-${VER}-bin.zip"
unzip -q /tmp/gradle.zip -d ~/gradle-dist
export PATH="$HOME/gradle-dist/gradle-${VER}/bin:$PATH"
```

```
$ gradle -version
Gradle 9.8.2
Launcher JVM:  17.0.20.1 (Ubuntu 17.0.20.1+1-1-24.04-Ubuntu)
Daemon JVM:    /usr/lib/jvm/java-17-openjdk-amd64
```

### 2. Clone the source

Cloned to `~/labs-workspace/CalculatorGradleApp`. Same `src/main/java` and
`src/test/java` layout as Lab 1 — Gradle adopted Maven's directory convention.
Two config files instead of one: `build.gradle` (how to build) and
`settings.gradle` (which projects form the build).

### 3. Run the unit tests

```bash
gradle test
```

```
> Task :test
BUILD SUCCESSFUL in 14s
3 actionable tasks: 3 executed
```

Gradle is terse — it does not print a test count. Read it from the XML report:

```
tests=5 failures=0 errors=0
```

**5 tests, all passing** — identical to Lab 1, because it is the same source.

### 4. Build the artifact

```bash
gradle clean build
```

```
BUILD SUCCESSFUL in 2s
8 actionable tasks: 8 executed

$ ls -lh build/libs/calculator.jar
-rw-r--r-- 1 eslam eslam 2.3K Oct 20 23:18 build/libs/calculator.jar
```

Required path hit exactly: **`build/libs/calculator.jar`**.

### 5–6. Run and verify

```bash
printf '10\n5\n' | java -jar build/libs/calculator.jar
```

```
Enter first number: Enter second number: a = 10.0, b = 5.0
Sum: 15.0
Subtract: 5.0
Multiply: 50.0
Divide: 2.0
```

**Byte-identical behaviour to Lab 1.** That is the whole point of this lab: the
build tool changed, the result did not.

### Bonus check — incremental builds

Running `gradle build` a second time with nothing changed:

```
BUILD SUCCESSFUL in 1s
7 actionable tasks: 7 up-to-date
```

**7 of 8 tasks skipped.** Gradle fingerprints each task's inputs and re-runs only
what changed. Maven redoes everything, every time.

---

## Maven vs Gradle — what actually differs

| | Maven (Lab 1) | Gradle (Lab 2) |
|---|---|---|
| Config | `pom.xml` — XML, declarative | `build.gradle` — code, programmable |
| Model | Fixed lifecycle | Task graph (DAG) |
| Output | `target/calculator.jar` (3.7 KB) | `build/libs/calculator.jar` (2.3 KB) |
| Rebuild | Redoes everything | `7 up-to-date` — skips unchanged work |
| Output style | Verbose, prints test counts | Terse; test counts live in the report |

**Three real differences**, in my own words:

1. **Declarative vs programmable.** `pom.xml` describes what the project *is* and
   Maven decides the steps. `build.gradle` is executable code that builds a task
   graph, so it can express logic Maven cannot.
2. **Incremental builds.** Measured above: 8 tasks executed, then 7 up-to-date.
   On a four-file project that saves seconds; on a real codebase it is the
   difference between a 40-second and a 12-minute build.
3. **Verbosity.** Maven tells you `Tests run: 5` on the console. Gradle says
   `BUILD SUCCESSFUL` and leaves the count in `build/test-results/`. That matters,
   because a Gradle build missing `useJUnitPlatform()` finds **zero** tests and
   still reports success — a green build that tested nothing.

### Jar size difference — verified

The Gradle jar is 2.3 KB against Maven's 3.7 KB. The `.class` files are
byte-identical (`Calculator.class` 823 B, `Main.class` 1767 B in both). The gap is
packaging metadata — Maven embeds a copy of the POM, Gradle does not:

```
$ unzip -l target/calculator.jar          # Maven — 12 entries
     1918  META-INF/maven/com.example/calculator/pom.xml
       56  META-INF/maven/com.example/calculator/pom.properties

$ unzip -l build/libs/calculator.jar      # Gradle — 7 entries
  (no META-INF/maven/ at all)
```

That accounts for ~1.97 KB of the difference.

**An unexpected find:** every entry in the Gradle jar is dated `1980-02-01 00:00`,
while Maven stamps the real build time. Gradle normalises timestamps so that
building the same source twice produces a **byte-identical** jar — a reproducible
build. Maven's output differs on every run even when nothing changed.

---

## Commit this lab

```bash
cd ~/iVolve-Tasks && git add "Build Tools/Lab2" && git commit -m "feat(lab2): build and package Calculator with Gradle" && git push
```
