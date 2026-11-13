# Lab 21: Jenkins Pipeline for Application Deployment

<p align="center"><em>One pipeline that takes a Java application from source to a pod in kind:
build, containerise, scan, push, clean up, rewrite the manifest, deploy.</em></p>

---

## What the lab asks for

| # | Requirement | Where |
|---|---|---|
| 1 | Clone `DemoApp` with its `Dockerfile` | [Checkout stage](#1-checkout) |
| 2 | Stage 1, build the application | [Build app](#2-build-app) |
| 3 | Stage 2, build the Docker image | [Build Docker Image](#3-build-docker-image) |
| 4 | Stage 3, scan the image | [Scan Docker Image](#4-scan-docker-image) |
| 5 | Stage 4, push the image to DockerHub | [Push image](#5-push-image) |
| 6 | Stage 5, delete the image locally | [Delete image locally](#6-delete-image-locally) |
| 7 | Stage 6, update the image tag in the deployment file | [Update image](#7-update-image-in-the-deployment-file) |
| 8 | Stage 7, deploy to Kubernetes | [Deploy](#8-deploy-to-kubernetes) |
| 9 | `post` actions: `always`, `success`, `failure` | [Post actions](#9-post-actions) |

Two deviations, both stated up front because they change what the output looks like:

* **Registry = local, not Docker Hub.** This machine has no Docker Hub credentials
  (`~/.docker/config.json` is `{}`), so the push goes to the `registry:2` container
  from Lab 8. The image reference is `172.18.0.1:5000/eslamnabawy/demoapp:<build>`.
 Every command is otherwise identical, swap `REGISTRY` and the `docker login`
  step and the same pipeline pushes to Hub.
* **The application is cloned from the local copy** (`file:///home/eslam/labs-workspace/DemoApp`)
  because GitHub is unreliable from this host (see Lab 8). The clone is the upstream
  repository, unmodified.

---

## The pipeline

```
Jenkinsfile  (Jenkins/Lab21/Jenkinsfile)
├── Checkout ─────────────── two clones: app/ (DemoApp)  repo/ (this repository)
├── Build app ────────────── mvn -B clean package
├── Build Docker Image ───── docker build -t 172.18.0.1:5000/…/demoapp:<BUILD_NUMBER>
├── Scan Docker Image ────── trivy, CRITICAL/fixable gates the build
├── Push image to DockerHub ─ docker push
├── Delete image locally ─── docker rmi
├── Update image in deployment file ─ sed on Jenkins/Lab21/deployment.yaml
└── Deploy to Kubernetes ─── kubectl apply + rollout status
post { always / success / failure }
```

The controller runs in a purpose-built image (`ivolve-jenkins:lab21`, 3.09 GB):
`jenkins/jenkins:lts` plus Maven, Temurin JDK 17, the Docker CLI, Trivy 0.76.1 and
kubectl 1.37.1. It is started with `--network host` and the host's
`/var/run/docker.sock` mounted, which is the same "build on the host daemon"
pattern as Lab 8, no Docker-in-Docker.

---

## Results

Every block below is copied from the build console or the terminal of the run
that produced this README.

### 0. Controller, job and trigger

```text
$ curl -s -u ivolve-admin:ivolve-admin http://127.0.0.1:8082/api/json?tree=mode,numExecutors
{"_class":"hudson.model.Hudson","mode":"NORMAL","numExecutors":1}
trigger HTTP 201 (want 201)
```

### 1. Checkout

Two clones into one workspace, `app/` and `repo/`:

```text
[Pipeline] deleteDir
[Pipeline] { (Checkout)
Cloning repository file:///home/eslam/labs-workspace/DemoApp
Checking out Revision f37bb9984451bd6db859cbacad32ecbe472f003d (refs/remotes/origin/main)
Commit message: "Add files via upload"
Running in /home/eslam/jenkins-home-lab21/workspace/lab21-pipeline/repo
```

### 2. Build app

```text
[INFO] --- spring-boot:3.2.0:repackage (repackage) @ demo ---
[INFO] Replacing main artifact …/target/demo-0.0.1-SNAPSHOT.jar with repackaged archive, adding nested dependencies in BOOT-INF/.
[INFO] BUILD SUCCESS
[INFO] Total time:  01:04 min
+ ls -l target/demo-0.0.1-SNAPSHOT.jar
-rw-r--r-- 1 jenkins jenkins 19626337 Nov 11 23:28 target/demo-0.0.1-SNAPSHOT.jar
Recording test results
No test report files were found. Configuration error?
```

That last line is not an error in the pipeline: `DemoApp` ships no tests, so the
`junit` step is called with `allowEmptyResults: true`. A real project with surefire
reports would publish them here.

### 3. Build Docker Image

```text
#8 naming to localhost:5000/eslamnabawy/demoapp:1 done
+ docker images localhost:5000/eslamnabawy/demoapp:1 --format {{.Repository}}:{{.Tag}} {{.Size}}
localhost:5000/eslamnabawy/demoapp:1 725MB
```

### 4. Scan Docker Image

```text
Some vulnerabilities have been ignored/suppressed. Use the "--show-suppressed" flag to display them.
+ grep -E ^Total: trivy-report.txt
Total: 2 (HIGH: 2, CRITICAL: 0)
Total: 38 (HIGH: 38, CRITICAL: 0)
```

Two targets: the Ubuntu 24.04 base (2 HIGH, both fixable) and the packaged jar
(38 HIGH). The nine CRITICALs are suppressed by `.trivyignore`, counted, not
hidden: the same image scanned without the triage file reports

```text
Total: 49 (UNKNOWN: 0, LOW: 4, MEDIUM: 43, HIGH: 2, CRITICAL: 0)   # ubuntu
Total: 94 (UNKNOWN: 0, LOW: 14, MEDIUM: 33, HIGH: 38, CRITICAL: 9) # jar
```

and the gate itself still bites when the threshold is raised:

```text
$ trivy image --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 demoapp:lab21
…
$ echo $?
1
```

The report is archived on every build, green or red (`app/trivy-report.txt`).
`--ignore-unfixed` keeps the gate honest: it only fails on findings that
have a published fix, so an operator is never blocked by something they cannot
act on.

### 5. Push image

```text
+ docker push localhost:5000/eslamnabawy/demoapp:1
The push refers to repository [localhost:5000/eslamnabawy/demoapp]
1: digest: sha256:8cb7fd1181ae8d5c22b7a4f9f98cc290ed648e7f9203e25c85a3d417de990341 size: 856
+ curl -s localhost:5000/v2/_catalog
{"repositories":["eslamnabawy/demoapp","eslamnabawy/ivolveapp"]}
+ curl -s localhost:5000/v2/eslamnabawy/demoapp/tags/list
{"name":"eslamnabawy/demoapp","tags":["1"]}
```

`ivolveapp` is Lab 8's image, the same registry, still holding both labs.

### 6. Delete image locally

```text
+ docker rmi localhost:5000/eslamnabawy/demoapp:1
Untagged: localhost:5000/eslamnabawy/demoapp:1
Deleted: sha256:3d39dea70425826972aa1a92601de8c3b3a87d3283aaafe85de133b295c4764a
+ docker images localhost:5000/eslamnabawy/demoapp:1 --format {{.Repository}}:{{.Tag}}
```

The final `docker images` prints nothing: the host no longer has the image.

### 7. Update image in the deployment file

```text
+ echo old:           image: eslamnabawy/demoapp:initial
old:           image: eslamnabawy/demoapp:initial
+ sed -i s|^\( *image:\).*|\1 172.18.0.1:5000/eslamnabawy/demoapp:1| Jenkins/Lab21/deployment.yaml
new:           image: 172.18.0.1:5000/eslamnabawy/demoapp:1
```

### 8. Deploy to Kubernetes

```text
+ kubectl apply -f Jenkins/Lab21/namespace.yaml
namespace/lab21 created
+ kubectl apply -f Jenkins/Lab21/deployment.yaml
deployment.apps/demoapp created
+ kubectl apply -f Jenkins/Lab21/service.yaml
service/demoapp created
+ kubectl -n lab21 rollout status deployment/demoapp --timeout=240s
Waiting for deployment "demoapp" rollout to finish: 0 of 1 updated replicas are available...
deployment "demoapp" successfully rolled out
+ kubectl -n lab21 get pods -o wide
NAME                       READY   STATUS    RESTARTS   AGE   IP                NODE
demoapp-657c885d84-r5xb6   1/1     Running   0          12s   192.168.209.103   ivolve-worker2
```

State after the build, from the host:

```text
$ kubectl -n lab21 get deploy,pods,svc -o wide
NAME                      READY   UP-TO-DATE   AVAILABLE   AGE    IMAGES
deployment.apps/demoapp   1/1     1            1           14s    172.18.0.1:5000/eslamnabawy/demoapp:1

NAME                           READY   STATUS    RESTARTS   AGE   IP                NODE
pod/demoapp-657c885d84-r5xb6   1/1     Running   0          14s   192.168.209.103   ivolve-worker2

NAME              TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)   AGE
service/demoapp   ClusterIP   10.96.150.1   <none>        80/TCP    14s

$ curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8088/   # via port-forward
200
```

The pod started after `docker rmi`, so its image came from the registry, the
push in stage 5 and the pull in stage 7 are both real.

### 9. Post actions

```text
Pipeline finished: SUCCESS (build #1)
Archiving artifacts
+ docker rmi localhost:5000/eslamnabawy/demoapp:1
Image 172.18.0.1:5000/eslamnabawy/demoapp:1 is running in namespace lab21.
Finished: SUCCESS
```

`always` archived the Trivy report and cleaned the image; `success` stated where
the image now runs. The `failure` branch was exercised too, the first attempt
died at the push stage and the console shows its own diagnosis:

```text
Pipeline failed — last cluster state:
+ kubectl -n lab21 get pods -o wide
No resources found in lab21 namespace.
```

which is exactly right: nothing was deployed, because the image never reached the
registry.


---

## Loose ends

**The Jenkinsfile has to be committed before the job can read it.** The job is a
*Pipeline script from SCM*: Jenkins clones the repository first and then looks for
`Jenkins/Lab21/Jenkinsfile` **in that clone**. An unstaged file on disk does not
exist as far as the build is concerned:

```
Checking out Revision 9347525… (origin/main)
ERROR: …/Jenkins/Lab21/Jenkinsfile not found
Finished: FAILURE
```

The build died in 1.1 s. Nothing about the pipeline was wrong, the file simply
was not in the commit it checked out.

**Two checkouts, because one SCM checkout owns the whole workspace.** The build
needs two repositories at once: the application under test and this lab
repository that holds the manifests. A single `checkout scm` replaces the
workspace contents, so the manifests would disappear the moment the app is
cloned. `dir('app')` and `dir('repo')` keep them side by side.

**Trivy's default timeout is five minutes, and the scan is silent about it.**
`demoapp:lab21` is a 725 MB image with a 94-finding Spring Boot jar inside;
the default `--timeout 5m` gave up mid-layer:

```
FATAL run error: … walk dir error: walk error: context deadline exceeded
```

Worse. It still printed counts (`CRITICAL: 9, HIGH: 40`) that look like a
finished scan. Every scan in the pipeline passes `--timeout 30m`.

**A gate that can never pass is not a gate.** The image has 49 fixable
HIGH/CRITICAL findings, all inherited from the application's pinned Spring Boot
3.2.0 (Tomcat 10.1.16, Spring MVC 6.1.1). Turning on
`--severity HIGH,CRITICAL --exit-code 1` fails the build on the first run, on
findings nobody in this lab can fix, the app is cloned as-is. The pipeline
therefore gates on **CRITICAL only**, with the nine known CRITICALs listed in
`Jenkins/Lab21/.trivyignore` and a comment naming the library and the reason.
A new CRITICAL, or a fixable one after a dependency bump, still fails the
build. The report is archived as a build artefact either way.

**`.trivyignore` is discovered automatically, which changes what the report
shows.** Trivy reads the file from the working directory, so the *report* scan 
which never passes `--ignorefile`, is already filtered, and its totals read
`CRITICAL: 0`. The true count is the nine printed above from a scan with no
triage file present. Nothing is hidden, but a reader who only looks at the
archived report would undercount.

**One registry, two names.** The host's Docker daemon trusts `127.0.0.1` as an
insecure registry out of the box; it does **not** trust `172.18.0.1`. Pushing to
the bridge address fails with:

```
failed to do request: Head "https://172.18.0.1:5000/v2/…": server gave HTTP
response to HTTPS client
```

The kind nodes have the opposite problem: inside a node, `localhost:5000` is the
node itself, not the host. So the pipeline pushes to `localhost:5000/…` and
writes `172.18.0.1:5000/…` into the manifest. Both names address the same
`registry:2` store; containerd on each node is given a plain-HTTP mirror entry
for `172.18.0.1:5000` and restarted:

```toml
[plugins."io.containerd.grpc.v1.cri".registry.mirrors."172.18.0.1:5000"]
  endpoint = ["http://172.18.0.1:5000"]
```

The alternative, adding `insecure-registries` to the host daemon and restarting
Docker, would have bounced the Lab 8 registry and every other container on this
machine.

**Deleting the local image is what proves the push worked.** Stage 5 removes the
image from the host, and stage 7's pod still starts, because the node pulls it
from the registry. Without stage 5 a `local` image would satisfy the deployment
and the push could be broken without anyone noticing.

**A fresh controller every run costs a full Maven download.** `commands.sh`
deletes `~/jenkins-home-lab21` (and the image) so each run is reproducible, which
also throws away `~/.m2` inside the container. The Trivy database is the one cache
worth keeping: 1.7 GB through WSL networking, so the script copies the host's
`~/.cache/trivy` into the new home before starting Jenkins.

**The POST needs a CSRF crumb.** `curl -X POST …/job/lab21-pipeline/build` alone
returns `403` even with valid credentials; the script fetches
`crumbIssuer/api/json` with a cookie jar and replays the crumb header (the same
trap as Lab 20).

**Namespace `lab21`, not `ivolve`.** The `ivolve` namespace still carries Lab
11's three-pod quota, and Lab 16 already had to work around a full quota. A new
namespace keeps this lab's rollout independent of the earlier state.


---

## Running it again

```bash
cd ~/iVolve-Tasks/Jenkins/Lab21
bash commands.sh
```

`commands.sh` is the whole lab, in order: registry + containerd trust, namespace
CI image build, controller start, job trigger over the HTTP API with a CSRF crumb
result polling, manifest and cluster verification, and cleanup.

---

## Tidy up after it

`commands.sh` ends with the cleanup:

```bash
docker rm -f jenkins-lab21
docker rmi ivolve-jenkins:lab21
rm -rf ~/jenkins-home-lab21
```

The `lab21` namespace is left behind on purpose. It is the evidence that stage 7
worked. Remove it with `kubectl delete namespace lab21`.

---

## Committing this

```bash
cd ~/iVolve-Tasks
git add Jenkins/Lab21
git commit -m "feat(lab21): Jenkins pipeline — build, scan, push, retag manifest, deploy"
git push origin main
```
