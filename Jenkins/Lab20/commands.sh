#!/usr/bin/env bash
# Lab 20 — two Jenkins users, admin vs read-only, verified over HTTP.
set -euo pipefail
LAB="$HOME/iVolve-Tasks/Jenkins/Lab20"
URL=http://127.0.0.1:8081
A=admin:ivolveadmin
U1=user1:user1pass
U2=user2:user2pass

docker build -t ivolve-jenkins:lab20 "$LAB"
docker rm -f jenkins-lab20 2>/dev/null || true
rm -rf "$HOME/jenkins-home-lab20"; mkdir -p "$HOME/jenkins-home-lab20"
docker run -d --name jenkins-lab20 -p 127.0.0.1:8081:8080 \
  -v "$HOME/jenkins-home-lab20:/var/jenkins_home" \
  -v "$LAB/jenkins.yaml:/var/jenkins_home/casc/jenkins.yaml:ro" \
  -e CASC_JENKINS_CONFIG=/var/jenkins_home/casc \
  -e JENKINS_ADMIN_PASSWORD=ivolveadmin \
  -e USER1_PASSWORD=user1pass \
  -e USER2_PASSWORD=user2pass \
  ivolve-jenkins:lab20

for i in $(seq 1 60); do
  curl -sf -u "$A" "$URL/api/json" >/dev/null 2>&1 && break
  sleep 2
done

crumb() {
  local jar=$1 user=$2
  rm -f "$jar"
  curl -s -c "$jar" -u "$user" "$URL/crumbIssuer/api/json" \
    | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d["crumbRequestField"]+":"+d["crumb"])'
}

JAR=/tmp/j20-admin.jar
C=$(crumb "$JAR" "$A")
curl -s -o /dev/null -w 'createItem: %{http_code}\n' -b "$JAR" -u "$A" -H "$C" \
  -H 'Content-Type: application/xml' --data-binary "@$LAB/job.xml" \
  -X POST "$URL/createItem?name=lab20-job"

J1=/tmp/j20-u1.jar
C1=$(crumb "$J1" "$U1")
printf 'user1 build: %s\n' "$(curl -s -o /dev/null -w '%{http_code}' -b "$J1" -u "$U1" -H "$C1" -X POST "$URL/job/lab20-job/build")"

J2=/tmp/j20-u2.jar
C2=$(crumb "$J2" "$U2")
printf 'user2 build: %s\n' "$(curl -s -o /dev/null -w '%{http_code}' -b "$J2" -u "$U2" -H "$C2" -X POST "$URL/job/lab20-job/build")"
printf 'user2 manage: %s\n' "$(curl -s -o /dev/null -w '%{http_code}' -u "$U2" "$URL/pluginManager/api/json?depth=0")"
printf 'anonymous:   %s\n' "$(curl -s -o /dev/null -w '%{http_code}' "$URL/api/json")"

curl -s -u "$A" "$URL/job/lab20-job/lastBuild/api/json?tree=number,result" \
  | python3 -c 'import sys,json;d=json.load(sys.stdin);print("last build #%s %s" % (d["number"], d["result"]))'
