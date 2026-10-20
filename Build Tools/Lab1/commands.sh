#!/usr/bin/env bash
# Lab 1 — Building and Packaging a Java Application with Maven
# Every command, in order. Run from anywhere.
set -euo pipefail

APP=~/labs-workspace/CalculatorMavenApp

# 1. Install Java 17 and Maven
sudo apt update && sudo apt install -y openjdk-17-jdk maven
java -version && mvn -version          # the "Java version" line must read 17

# 2. Clone the source OUTSIDE this repo
mkdir -p ~/labs-workspace
[ -d "$APP" ] || git clone https://github.com/Ibrahim-Adel15/CalculatorMavenApp.git "$APP"

# 3. Run the unit tests
cd "$APP" && mvn -B test               # want: Tests run: 5, Failures: 0, Errors: 0

# 4. Build the artifact -> target/calculator.jar
cd "$APP" && mvn -B clean package
ls -lh "$APP/target/calculator.jar"

# 5. Run it (interactive: type 10, Enter, 5, Enter)
java -jar "$APP/target/calculator.jar"

# 5b. Or non-interactively, the way CI does it
printf '10\n5\n' | java -jar "$APP/target/calculator.jar"

# 6. Why `java -jar` works at all: the manifest names an entry point
unzip -p "$APP/target/calculator.jar" META-INF/MANIFEST.MF
