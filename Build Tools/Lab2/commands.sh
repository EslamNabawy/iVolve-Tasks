#!/usr/bin/env bash
# Lab 2 — Building and Packaging a Java Application with Gradle
# NOTE: the lab slide says "Go Application" — the repo is Java.
set -euo pipefail

APP=~/labs-workspace/CalculatorGradleApp

# 1. Install Gradle. Do NOT use apt (Ubuntu ships 4.4 from 2017; this needs 6.7+).
#    Preferred: SDKMAN (requires the `zip` package to be installed).
#      curl -s "https://get.sdkman.io" | bash
#      source "$HOME/.sdkman/bin/sdkman-init.sh"
#      sdk install gradle
#    Used here instead, because `zip` was unavailable and this needs no sudo:
VER=$(curl -s https://services.gradle.org/versions/current | python3 -c "import sys,json;print(json.load(sys.stdin)['version'])")
mkdir -p ~/gradle-dist
curl -sL -o /tmp/gradle.zip "https://services.gradle.org/distributions/gradle-${VER}-bin.zip"
unzip -q -o /tmp/gradle.zip -d ~/gradle-dist && rm -f /tmp/gradle.zip
export PATH="$HOME/gradle-dist/gradle-${VER}/bin:$PATH"
gradle -version

# 2. Clone the source OUTSIDE this repo
mkdir -p ~/labs-workspace
[ -d "$APP" ] || git clone https://github.com/Ibrahim-Adel15/CalculatorGradleApp.git "$APP"

# 3. Run the unit tests
cd "$APP" && gradle test               # HTML report: build/reports/tests/test/index.html

# 4. Build the artifact -> build/libs/calculator.jar
cd "$APP" && gradle clean build
ls -lh "$APP/build/libs/calculator.jar"

# 5. Run it
java -jar "$APP/build/libs/calculator.jar"
printf '10\n5\n' | java -jar "$APP/build/libs/calculator.jar"

# 6. Gradle's advantage: run the build again and watch tasks report UP-TO-DATE
cd "$APP" && gradle build
