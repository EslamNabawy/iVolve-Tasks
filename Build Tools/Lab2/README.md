# Lab 2 — Building and Packaging a Java Application with Gradle

**Track:** Build Tools · **Source:** https://github.com/Ibrahim-Adel15/CalculatorGradleApp.git

> **Slide correction:** the lab title reads "Building and Packaging Go Application with Gradle". The repository is **Java**, not Go — same `Calculator.java` / `Main.java` as Lab 1. Treat it as a Java lab; the title is a copy-paste slip.

## Requirements (from the lab)

- [ ] Install Gradle
- [ ] Clone the source code
- [ ] Run unit tests
- [ ] Build the app — artifact must land at `build/libs/calculator.jar`
- [ ] Run the app
- [ ] Verify the app works

---

## Steps

### 1. Install Gradle

**Avoid `apt install gradle`** — Ubuntu's package is several major versions behind and chokes on modern `build.gradle` syntax (notably the `toolchain` block this project uses). Install via SDKMAN, the standard JVM toolchain manager:

```bash
curl -s "https://get.sdkman.io" | bash && source "$HOME/.sdkman/bin/sdkman-init.sh"
```

```bash
sdk install gradle
```

```bash
gradle -version
```

The output shows the Gradle version, the JVM it's running on, and your OS. Java 17 must be present from Lab 1.

### 2. Clone the source

```bash
git clone https://github.com/Ibrahim-Adel15/CalculatorGradleApp.git ~/labs-workspace/CalculatorGradleApp
```

```bash
find ~/labs-workspace/CalculatorGradleApp -type f -not -path '*/.git/*'
```

Two build files here instead of one: `build.gradle` (what to build) and `settings.gradle` (which projects make up the build). Maven packs both roles into `pom.xml`.

### 3. Run the unit tests

```bash
cd ~/labs-workspace/CalculatorGradleApp && gradle test
```

Gradle is quieter than Maven — on success it prints little more than `BUILD SUCCESSFUL`. For the actual test report, open the HTML it generates:

```bash
ls ~/labs-workspace/CalculatorGradleApp/build/reports/tests/test/index.html
```

Want Maven-style per-test output on the console? Run `gradle test -i`.

Note `test { useJUnitPlatform() }` in `build.gradle`. Without that line Gradle defaults to JUnit 4 and silently runs **zero** JUnit 5 tests — a green build that tested nothing. A quietly passing build is more dangerous than a failing one.

### 4. Build the artifact

```bash
cd ~/labs-workspace/CalculatorGradleApp && gradle clean build
```

```bash
ls -lh ~/labs-workspace/CalculatorGradleApp/build/libs/calculator.jar
```

`build` runs compile + test + jar. The name `calculator.jar` comes from the `jar { }` block: `archiveBaseName = 'calculator'` and `archiveVersion = ''` (the empty version is what strips the `-1.0.0` suffix).

### 5. Run the app

```bash
java -jar ~/labs-workspace/CalculatorGradleApp/build/libs/calculator.jar
```

Gradle can also run it directly, thanks to the `application` plugin:

```bash
cd ~/labs-workspace/CalculatorGradleApp && gradle run --console=plain -q
```

`--console=plain` matters: Gradle's rich console redraws progress bars over your prompts and makes interactive input unreadable.

### 6. Verify

Inputs `10` and `5` → `Sum: 15.0`, `Subtract: 5.0`, `Multiply: 50.0`, `Divide: 2.0` — identical to Lab 1, since it is the same source code.

```bash
printf '10\n5\n' | java -jar ~/labs-workspace/CalculatorGradleApp/build/libs/calculator.jar
```

---

## Understand it

**Maven vs Gradle — the real difference.** Maven is *declarative*: `pom.xml` describes what your project **is**, and Maven applies a fixed lifecycle. Gradle is *imperative/programmable*: `build.gradle` is executable code (Groovy or Kotlin) that builds a task graph. Maven trades flexibility for predictability; Gradle trades predictability for power and speed.

| | Maven | Gradle |
|---|---|---|
| Config | `pom.xml` (XML) | `build.gradle` (Groovy/Kotlin DSL) |
| Model | Fixed lifecycle | Task graph (DAG) |
| Output | `target/` | `build/` |
| Build | `mvn package` | `gradle build` |
| Incremental builds | Limited | Yes — skips up-to-date tasks |
| Build cache / daemon | No | Yes — much faster on repeat builds |

**See incremental builds work.** Run `gradle build` twice without changing anything. The second run reports `UP-TO-DATE` on most tasks and finishes in a fraction of the time. Maven re-does the work every time.

**The toolchain block.** `languageVersion = JavaLanguageVersion.of(17)` tells Gradle to compile against Java 17 *and download a matching JDK if the machine lacks one*. This is how a team guarantees everyone builds against the same JDK regardless of what's installed locally — a reproducibility guarantee Maven doesn't offer out of the box.

**Why the wrapper matters.** Real projects commit `gradlew` / `gradlew.bat` plus `gradle/wrapper/`, then everyone runs `./gradlew build`. The wrapper pins an exact Gradle version per project, so a new contributor needs no Gradle installed at all. This repo has no wrapper — worth noticing, and a reasonable thing to mention in your write-up.

## My output

> Paste your real terminal output here.

```
```

## What I learned

> Compare the two build tools in your own words. Which did you find clearer, and why?
