#!/usr/bin/env bash
# Lab 8 — Jenkins: automate Labs 1-6 as one pipeline
# Reproduces the whole lab end to end: CI image, Jenkins container with
# Configuration as Code (admin user + job from this repo's Jenkinsfile),
# build, verification, cleanup. The unrelated aiops-* containers are
# never touched.
set -euo pipefail

LAB="$HOME/iVolve-Tasks/Jenkins/Lab8"
JHOME="$HOME/jenkins-home"
URL="http://127.0.0.1:8080"
USER=ivolve-admin
PASS=ivolve-admin

# 1. Build the CI image: jenkins:lts + git, docker CLI, maven, JDK 17,
#    Gradle 9.8.2, Trivy 0.76.1 and the Pipeline plugins, all baked in.
docker build -t ivolve-jenkins:lab8 "$LAB"

# 2. Start Jenkins. Same-path mounts matter twice: the docker CLI runs
#    the HOST daemon, which must resolve every build-context path, and
#    the job checks out file:///repo. The socket's group id (docker =
#    1001 here) is granted so user jenkins can use it.
rm -rf "$JHOME" && mkdir -p "$JHOME"
docker rm -f jenkins-lab8 2>/dev/null || true
docker run -d --name jenkins-lab8 \
  -p 127.0.0.1:8080:8080 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  --group-add 1001 \
  --add-host=host.docker.internal:host-gateway \
  -v "$HOME/iVolve-Tasks:$HOME/iVolve-Tasks:ro" \
  -v "$HOME/iVolve-Tasks:/repo:ro" \
  -v "$LAB/jenkins.yaml:/var/jenkins_home/casc/jenkins.yaml:ro" \
  -v "$JHOME:$JHOME" \
  -e JENKINS_HOME="$JHOME" \
  -e CASC_JENKINS_CONFIG=/var/jenkins_home/casc \
  -e JENKINS_ADMIN_ID="$USER" \
  -e JENKINS_ADMIN_PASSWORD="$PASS" \
  -e TRIVY_CACHE_DIR="$JHOME/.cache/trivy" \
  -e JAVA_OPTS="-Dhudson.plugins.git.GitSCM.ALLOW_LOCAL_CHECKOUT=true" \
  ivolve-jenkins:lab8

# 3. Wait for the endpoint (JCasC applied, security on: -u needed)
for i in $(seq 1 60); do curl -sf -u "$USER:$PASS" "$URL/api/json" >/dev/null && break; sleep 2; done
curl -s -u "$USER:$PASS" "$URL/api/json?tree=mode"

# 4. The job already exists (JCasC + Job DSL). Trigger it.
JAR=/tmp/jenkins-crumb.jar
rm -f "$JAR"
CRUMB=$(curl -s -c "$JAR" -u "$USER:$PASS" "$URL/crumbIssuer/api/json" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d["crumbRequestField"]+":"+d["crumb"])')
CODE=$(curl -s -o /dev/null -w "%{http_code}" -b "$JAR" -c "$JAR" -u "$USER:$PASS" -H "$CRUMB" -X POST "$URL/job/ivolve-labs-1-6/build")
echo "trigger HTTP $CODE (want 201)"

# 5. Wait for the verdict
R=RUNNING
for i in $(seq 1 200); do
  R=$(curl -s -u "$USER:$PASS" "$URL/job/ivolve-labs-1-6/lastBuild/api/json?tree=result" |
      python3 -c "import sys,json;print(json.load(sys.stdin).get('result') or 'RUNNING')" 2>/dev/null || echo RUNNING)
  [ "$R" != "RUNNING" ] && break
  sleep 6
done
echo "pipeline result: $R"
curl -s -u "$USER:$PASS" "$URL/job/ivolve-labs-1-6/lastBuild/api/json?tree=result,duration,number" | python3 -m json.tool

# 6. Evidence: the tail of the real console
curl -s -u "$USER:$PASS" "$URL/job/ivolve-labs-1-6/lastBuild/consoleText" | tail -25

[ "$R" = "SUCCESS" ] || { echo "PIPELINE FAILED"; exit 1; }

# 7. The pipeline cleaned up its own six images
docker images | grep -E '^(ivolve-ci|image1|image2|trivy-lab|ivolve-app|ivolve1)' \
  || echo "no pipeline images left"

# 8. Cleanup — this lab only
docker rm -f jenkins-lab8
docker rmi ivolve-jenkins:lab8
rm -rf "$JHOME"
docker ps -a --format '{{.Names}}' | grep '^aiops' || echo "no aiops containers present"
