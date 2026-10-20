# Lab 1 — Building and Packaging a Java Application with Maven

**Track:** Build Tools · **Source:** https://github.com/Ibrahim-Adel15/CalculatorMavenApp.git

## Requirements (from the lab)

- [ ] Install Java and Maven
- [ ] Clone the source code
- [ ] Run unit tests
- [ ] Build the app — artifact must land at `target/calculator.jar`
- [ ] Run the app
- [ ] Verify the app works

---

## Steps

### 1. Install Java 17 and Maven

```bash
sudo apt update && sudo apt install -y openjdk-17-jdk maven
```

```bash
java -version && mvn -version
```

Check the `Java version:` line in the `mvn -version` output — it must say 17. The `pom.xml` sets `maven.compiler.source` to 17, so an older JDK fails the build.

### 2. Clone the source

Clone **outside** this repo so upstream code isn't committed into your submission:

```bash
mkdir -p ~/labs-workspace && git clone https://github.com/Ibrahim-Adel15/CalculatorMavenApp.git ~/labs-workspace/CalculatorMavenApp
```

Look around before building:

```bash
find ~/labs-workspace/CalculatorMavenApp -type f -not -path '*/.git/*'
```

You should find four files: `pom.xml`, `Main.java`, `Calculator.java`, `CalculatorTest.java`.

### 3. Run the unit tests

```bash
cd ~/labs-workspace/CalculatorMavenApp && mvn test
```

The first run downloads dependencies into `~/.m2` — slow once, fast after. Look for `Tests run: N, Failures: 0, Errors: 0` and `BUILD SUCCESS`.

Open `src/test/java/com/example/calculator/CalculatorTest.java` and read it. Notice there's a test asserting that dividing by zero throws `ArithmeticException` — the tests cover the error path, not just the happy path.

### 4. Build the artifact

```bash
cd ~/labs-workspace/CalculatorMavenApp && mvn clean package
```

```bash
ls -lh ~/labs-workspace/CalculatorMavenApp/target/calculator.jar
```

The lab demands the file be named exactly `calculator.jar`. Maven's default would be `calculator-1.0.0.jar` (artifactId-version). It isn't, because `pom.xml` sets `<finalName>calculator</finalName>`. Find that line.

`mvn package` runs the full lifecycle up to `package`: validate → compile → test → package. `mvn clean` first wipes `target/` so you can't accidentally ship a stale build.

### 5. Run the app

```bash
java -jar ~/labs-workspace/CalculatorMavenApp/target/calculator.jar
```

It prompts for two numbers. Type one, press Enter, type the other, press Enter.

### 6. Verify

With inputs `10` and `5`, expect:

```
a = 10.0, b = 5.0
Sum: 15.0
Subtract: 5.0
Multiply: 2.0
Divide: 2.0
```

Non-interactively (useful for scripting and CI):

```bash
printf '10\n5\n' | java -jar ~/labs-workspace/CalculatorMavenApp/target/calculator.jar
```

---

## Understand it

**Why does `java -jar` work at all?** A `.jar` is a zip archive. It only runs when its manifest declares an entry point. The `maven-jar-plugin` block in `pom.xml` writes `Main-Class: com.example.calculator.Main` into `META-INF/MANIFEST.MF`. Prove it:

```bash
unzip -p ~/labs-workspace/CalculatorMavenApp/target/calculator.jar META-INF/MANIFEST.MF
```

Remove that plugin config and you get "no main manifest attribute".

**`mvn test` vs `mvn package` vs `mvn install`** — the lifecycle is cumulative. `package` runs everything `test` does, plus packaging. `install` does all of that, then copies the jar into your local `~/.m2` repository so other local projects can depend on it.

**Where did JUnit come from?** You never downloaded it manually. `pom.xml` declares it as a dependency with `<scope>test</scope>`, so Maven fetched it from Maven Central and put it on the *test* classpath only — it is deliberately absent from the runtime classpath, because shipping a test framework to production is waste.

## My output

> Paste your real terminal output here — `mvn test` results, `ls -lh target/`, and the app run. Evidence of the work is the point of the write-up.

```
```

## What I learned

> 2–4 sentences in your own words. What surprised you? What broke?
