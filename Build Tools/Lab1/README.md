# Lab 1 — Building and Packaging a Java Application with Maven

**Track:** Build Tools · **Source:** https://github.com/Ibrahim-Adel15/CalculatorMavenApp.git

## Requirements (from the lab)

- [x] Install Java and Maven
- [x] Clone the source code
- [x] Run unit tests
- [x] Build the app — artifact must land at `target/calculator.jar`
- [x] Run the app
- [x] Verify the app works

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
Multiply: 50.0
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

**Toolchain**

```
$ java -version
openjdk version "17.0.20.1" 2026-08-18
OpenJDK Runtime Environment (build 17.0.20.1+1-1-24.04-Ubuntu)
OpenJDK 64-Bit Server VM (build 17.0.20.1+1-1-24.04-Ubuntu, mixed mode, sharing)

$ mvn -version
Apache Maven 3.8.7
Maven home: /usr/share/maven
Java version: 17.0.20.1, vendor: Ubuntu, runtime: /usr/lib/jvm/java-17-openjdk-amd64
OS name: "linux", version: "6.18.33.2-microsoft-standard-wsl2", arch: "amd64", family: "unix"
```

**Build**

```
$ mvn clean package
[INFO] ------------------------------------------------------------------------
[INFO] BUILD SUCCESS
[INFO] ------------------------------------------------------------------------
[INFO] Total time:  16.509 s
[INFO] Finished at: 2026-10-20T17:12:07+03:00
[INFO] ------------------------------------------------------------------------

$ ls -lh target/calculator.jar
-rw-r--r-- 1 eslam eslam 3.7K Oct 20 17:12 target/calculator.jar
```

<!-- TODO: paste the `mvn test` summary line here — the "Tests run: N, Failures: 0, Errors: 0" line -->

**Run and verify**

```
$ java -jar target/calculator.jar
Enter first number: 10
Enter second number: 5
a = 10.0, b = 5.0
Sum: 15.0
Subtract: 5.0
Multiply: 50.0
Divide: 2.0
```

**Manifest — why `java -jar` works**

```
$ unzip -p target/calculator.jar META-INF/MANIFEST.MF
Manifest-Version: 1.0
Created-By: Maven JAR Plugin 3.4.1
Build-Jdk-Spec: 17
Main-Class: com.example.calculator.Main
```

## What I learned

> 2–4 sentences in your own words. What surprised you? What broke?

---

## Commit this lab

The write-up above **is** the deliverable — git tracks file changes, so nothing is
recorded until this README is filled in. Check what you're about to commit, then push:

```bash
cd ~/iVolve-Tasks && git status
```

```bash
cd ~/iVolve-Tasks && git add "Build Tools/Lab1" && git commit -m "feat(lab1): build and package Calculator with Maven" && git push
```

One commit per lab, pushed as you go — your git history is part of what is graded.

