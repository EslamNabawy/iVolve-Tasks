# Lab 20 — Role-based authorization in Jenkins

**Track:** CI/CD · **Controller:** Jenkins LTS in Docker (`127.0.0.1:8081`) ·
**Config:** JCasC · **Image:** `ivolve-jenkins:lab20`

> Deck Lab 20 asks for `user1` and `user2` in Jenkins, with an **admin** role for
> `user1` and a **read-only** role for `user2`, and proof the distinction holds.

## Requirements

- [x] users `user1` and `user2` declared as code (JCasC, no setup wizard)
- [x] `user1` — administer Jenkins (can trigger builds)
- [x] `user2` — read-only (can see jobs, cannot trigger them)
- [x] anonymous users have no access
- [x] verified by HTTP status codes, not by clicking around

## Results

| Check | admin | user1 | user2 | anonymous |
|---|:-:|:-:|:-:|:-:|
| `GET /api/json` | 200 | 200 | 200 | **403** |
| `GET /job/lab20-job/api/json` | 200 | 200 | 200 | — |
| `POST /job/lab20-job/build` | 201 | **201** | **403** | — |
| `GET /pluginManager/api/json` | 200 | 200 | **403** | — |

`user1` triggered build **#1 → `SUCCESS`**; `user2` got `403` for the same
request. That is the admin/read-only split in one table.

## One deviation, stated

The deck says "roles". Jenkins has no built-in named roles: they come from the
**role-strategy** plugin's `roleBased` strategy. Its JCasC `assignments` field
is now rejected as deprecated, and Jenkins failed to boot with it:

```console
$ docker logs jenkins-lab20 | grep SEVERE
ConfiguratorException: authorizationStrategy: Failed to configure
'authorizationStrategy': 'assignments' is deprecated
```

So this lab uses **Matrix Authorization** (`matrix-auth`), which expresses the
same two permission sets per user: admin (`Overall/Administer`) for `user1`,
read-only (`Overall/Read`, `Job/Read`, `View/Read`) for `user2`. The outcome the
deck asks for is identical; only the mechanism differs, and the deviation is
recorded here rather than hidden.

## Steps

### 1 — A minimal Jenkins image

```dockerfile
FROM jenkins/jenkins:lts
ENV JAVA_OPTS="-Djenkins.install.runSetupWizard=false"
COPY plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt
```

`plugins.txt` holds `configuration-as-code` and `matrix-auth` — the setup
wizard never runs.

### 2 — Users and permissions as code

```yaml
jenkins:
  securityRealm:
    local:
      allowsSignup: false
      users:
        - { id: "admin", password: "${JENKINS_ADMIN_PASSWORD}" }
        - { id: "user1", password: "${USER1_PASSWORD}" }
        - { id: "user2", password: "${USER2_PASSWORD}" }
  authorizationStrategy:
    globalMatrix:
      permissions:
        - "Overall/Administer:admin"
        - "Overall/Administer:user1"
        - "Overall/Read:user2"
        - "Job/Read:user2"
        - "View/Read:user2"
```

Passwords arrive as environment variables at `docker run`; nothing secret is
in the repository. The file is mounted read-only at
`/var/jenkins_home/casc/jenkins.yaml`.

### 3 — Start it

```console
$ docker run -d --name jenkins-lab20 -p 127.0.0.1:8081:8080 \
    -v ~/jenkins-home-lab20:/var/jenkins_home \
    -v .../jenkins.yaml:/var/jenkins_home/casc/jenkins.yaml:ro \
    -e CASC_JENKINS_CONFIG=/var/jenkins_home/casc \
    -e JENKINS_ADMIN_PASSWORD=... -e USER1_PASSWORD=... -e USER2_PASSWORD=... \
    ivolve-jenkins:lab20
```

### 4 — A job to protect

Created through the API as admin (Jenkins requires a CSRF crumb for POSTs):

```console
$ curl -s -c jar -u admin:... http://127.0.0.1:8081/crumbIssuer/api/json
$ curl -b jar -u admin:... -H "Jenkins-Crumb:..." -H 'Content-Type: application/xml' \
    --data-binary @job.xml -X POST 'http://127.0.0.1:8081/createItem?name=lab20-job'
createItem HTTP 200
```

### 5 — Prove the boundary

```console
$ curl -s -o /dev/null -w '%{http_code}' -u user1:... -X POST .../job/lab20-job/build
201
$ curl -s -o /dev/null -w '%{http_code}' -u user2:... -X POST .../job/lab20-job/build
403
$ curl -s -o /dev/null -w '%{http_code}' -u user2:... .../pluginManager/api/json
403
```

`201` means "queued"; the build finished `SUCCESS`. `403` means the permission
check refused before anything ran.

## Things worth knowing

1. **Matrix vs role-strategy.** Matrix assigns permissions per user; role-strategy
   creates named roles and assigns users to them. Both can express admin vs
   read-only; role-strategy scales better when many users share a role, but its
   JCasC was broken for this version.
2. **`Overall/Read` alone is not "read-only".** Without `Job/Read` the user sees
   an empty controller; the read-only set needs both.
3. **Jenkins POSTs need a CSRF crumb.** A bare `curl -X POST` gets `403` even
   for an admin — a crumb defect looks exactly like a permission defect, so
   always fetch the crumb first.
4. **Permissions are checked before the request body.** `user2`'s build POST is
   rejected without Jenkins touching the job, which is why `403` (not `404`) is
   the right signal.
5. **Passwords never enter git.** JCasC reads them from the container's
   environment; the manifest only references the variables.

## Cleanup

The controller is left running for evidence. Remove it with:

```bash
docker rm -f jenkins-lab20
docker rmi ivolve-jenkins:lab20
rm -rf ~/jenkins-home-lab20
```

## Commit this lab

```bash
cd ~/iVolve-Tasks
git add Jenkins/Lab20
git commit -m "feat(lab20): Jenkins users with admin and read-only access"
```
