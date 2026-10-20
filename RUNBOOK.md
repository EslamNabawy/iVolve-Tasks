# Runbook — every command, and what it does

Command-by-command reference for Labs 1–3, the git workflow, and CI/CD.

- **Conceptual explanation** → the study-guide PDF (built from [pdf-kit/](pdf-kit/))
- **Step-by-step with context** → [GUIDE.md](GUIDE.md)
- **This file** → the commands themselves, what each one does, in order

Environment: Ubuntu 24.04 on WSL2 · repo at `~/iVolve-Tasks` · app clones in `~/labs-workspace`

---

## 0. The golden rule of this repo

```
~/iVolve-Tasks/        ← YOUR work. Committed. Dockerfiles, configs, write-ups.
~/labs-workspace/      ← CLONED app source. Never committed.
```

Why: your submission should contain what *you* authored, not a copy of someone
else's source or 50 MB of build output. `.gitignore` enforces it.

```bash
mkdir -p ~/labs-workspace
```

---

## 0b. You need Linux — WSL2, a real install, or a VM

Every command in this runbook is Linux, and **Docker requires a Linux kernel**.
Windows CMD or PowerShell on their own cannot run any of it.

| Option | Who it suits | Setup |
|---|---|---|
| **WSL2** on Windows | Recommended — what this repo uses | `wsl --install` in **PowerShell as Administrator**, then reboot |
| **Native Linux** | A spare machine or dual boot | Any Ubuntu 22.04+ / Fedora / Debian |
| **VM** (VirtualBox, VMware, Hyper-V) | Keeping it isolated from your host | Install Ubuntu Desktop/Server in the VM |

Verify you are actually inside Linux before starting:

```bash
uname -a && cat /etc/os-release | head -2
```

Expect `Linux` and your distribution. On WSL the kernel string also contains
`microsoft-standard-WSL2`.

> **On WSL, keep every project under `/home/<you>`, never `/mnt/c`.** Files on the
> Windows drive cross a filesystem bridge: builds run **5–20× slower**, and Linux
> permissions (the executable bit that `mvnw`/`gradlew` need) are not stored
> faithfully. Your repo at `~/iVolve-Tasks` is correct.

Open the repo in VS Code from inside WSL:

```bash
code ~/iVolve-Tasks
```

---

## 1. Environment setup (one time)

| Command | What it does |
|---|---|
| `sudo apt update` | Refreshes the list of available packages. Installs nothing. |
| `sudo apt install -y openjdk-17-jdk maven` | Installs the **full JDK** (compiler included) and Maven. `-y` auto-confirms. |
| `java -version` | Confirms the JVM is 17. |
| `mvn -version` | **The one that matters** — shows which JDK *Maven* will use. Must say 17. |

```bash
sudo apt update && sudo apt install -y openjdk-17-jdk maven
```

```bash
java -version && mvn -version
```

If `mvn -version` reports the wrong JDK, pin it:

```bash
echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' >> ~/.bashrc && source ~/.bashrc
```

> `JAVA_HOME` is the variable every JVM tool reads to find the JDK. `source` re-reads
> your shell config so the change applies now instead of after a restart.

### Gradle — via SDKMAN, not apt

```bash
curl -s "https://get.sdkman.io" | bash && source "$HOME/.sdkman/bin/sdkman-init.sh"
```

```bash
sdk install gradle && gradle -version
```

| Command | What it does |
|---|---|
| `curl -s ... \| bash` | Downloads the SDKMAN installer and runs it. Installs to `~/.sdkman` — no `sudo`. |
| `source ...sdkman-init.sh` | Loads the `sdk` command into the **current** shell. |
| `sdk install gradle` | Installs the current Gradle. |
| `sdk list java` | Shows every installable JDK — useful later when projects target different versions. |

> **Never `apt install gradle`.** Ubuntu ships Gradle 4.4 (2017); this project needs 6.7+.

### Docker (already installed on this machine)

| Command | What it does |
|---|---|
| `docker ps` | Lists running containers. Also the quickest check that the daemon is alive. |
| `sudo service docker start` | Starts the daemon. WSL has no systemd, so it doesn't always auto-start. |
| `sudo usermod -aG docker $USER` | Lets you run docker without `sudo`. **Reopen the terminal afterwards** — group membership is read at login. |

---

## 2. Git and GitHub (one time)

### Create the repo locally

```bash
cd ~/iVolve-Tasks && git init -b main
```

| Command | What it does |
|---|---|
| `git init -b main` | Creates `.git/` and sets the default branch to `main`. |

> **Order matters.** `git config` without `--global` writes into `.git/config`, so the
> repo must exist first — otherwise you get `fatal: not in a git directory`.

### Set your identity for this repo only

```bash
cd ~/iVolve-Tasks && git config user.name "Eslam" && git config user.email "eslamlef.308@gmail.com"
```

| Command | What it does |
|---|---|
| `git config user.email "..."` | Sets the commit author **for this repo only**. Your other projects keep the global identity. |
| `git config --list --show-origin` | Shows every setting and which file it came from. |

> Three scopes, increasing precedence: `--system` (machine) → `--global` (`~/.gitconfig`)
> → local (`.git/config`). No flag = local.

### Authenticate with GitHub

```bash
gh auth login
```

Choose **GitHub.com → HTTPS → Yes (authenticate git) → Login with a web browser**.
Copy the one-time code, press Enter, authorize in the browser, and **wait for the
terminal to confirm** before touching anything.

| Command | What it does |
|---|---|
| `gh auth login` | Authenticates the CLI *and* installs itself as git's credential helper, so pushes just work. |
| `gh auth status` | Verifies the token. Want `✓ Logged in to github.com account …`. |
| `gh auth logout -h github.com -u <user>` | Clears a stale entry. Needed if `hosts.yml` has a username but no token → `HTTP 401`. |

### Connect to GitHub and push

```bash
cd ~/iVolve-Tasks && git remote add origin https://github.com/EslamNabawy/iVolve-Tasks.git
```

```bash
cd ~/iVolve-Tasks && git add . && git commit -m "chore: scaffold DevOps labs repo" && git push -u origin main
```

| Command | What it does |
|---|---|
| `git remote add origin <url>` | Registers the GitHub repo under the name `origin`. **No angle brackets** — `<` is shell redirection and will error. |
| `git add .` | Stages everything not excluded by `.gitignore`. |
| `git commit -m "..."` | Records the snapshot with a message. |
| `git push -u origin main` | Uploads and sets `origin/main` as the tracking branch, so later pushes are just `git push`. |

**If the remote already has a README** (from GitHub's "Add a README" checkbox), a plain
push is rejected. Join the histories instead of force-pushing:

```bash
cd ~/iVolve-Tasks && git fetch origin && git merge origin/main --allow-unrelated-histories --no-edit
```

```bash
cd ~/iVolve-Tasks && git checkout --ours README.md && git add README.md && git commit --no-edit
```

| Command | What it does |
|---|---|
| `git merge --allow-unrelated-histories` | Joins two histories that share no common ancestor. |
| `git checkout --ours <file>` | During a conflict, keeps **your** version. (`--theirs` keeps the remote's.) |

---

## 3. The per-lab git workflow

Commit **once per lab**, not one dump at the end — your history is part of what's graded.

```bash
cd ~/iVolve-Tasks && git status
```

```bash
cd ~/iVolve-Tasks && git add "Build Tools/Lab1" && git commit -m "feat(lab1): build and package Calculator with Maven" && git push
```

| Command | What it does |
|---|---|
| `git status` | Shows what changed. **Run before every commit.** |
| `git status --short` | Compact view: `M` modified, `??` untracked. |
| `git add "Build Tools/Lab1"` | Stages one folder. Quotes are required — the name has a space. |
| `git add -A` | Stages everything, including deletions. |
| `git diff` | Shows unstaged changes; `git diff --staged` shows what's about to be committed. |
| `git log --oneline` | Compact history. |
| `git push` | Uploads (short form works after the first `-u` push). |

> **"nothing to commit, working tree clean" is not an error.** It means no *file* changed.
> Running lab commands in `~/labs-workspace` changes nothing inside the repo — the
> write-up in the lab's `README.md` is the deliverable.

### Commit message convention

`<type>(<scope>): <summary>` — [Conventional Commits](https://www.conventionalcommits.org/), the industry default.

| Type | Use for | Example |
|---|---|---|
| `feat` | New work delivered | `feat(lab3): add multi-stage Dockerfile` |
| `fix` | Correcting something broken | `fix(lab1): correct expected multiply output` |
| `docs` | Documentation only | `docs(lab2): explain Maven vs Gradle` |
| `chore` | Housekeeping | `chore: ignore build output` |
| `ci` | Pipeline changes | `ci: add Maven build workflow` |

---

## 4. Lab 1 — Maven

**Goal:** source → `target/calculator.jar`, tested and runnable.

```bash
git clone https://github.com/Ibrahim-Adel15/CalculatorMavenApp.git ~/labs-workspace/CalculatorMavenApp
```

```bash
cd ~/labs-workspace/CalculatorMavenApp && find . -type f -not -path './.git/*'
```

```bash
cd ~/labs-workspace/CalculatorMavenApp && mvn test
```

```bash
cd ~/labs-workspace/CalculatorMavenApp && mvn clean package && ls -lh target/calculator.jar
```

```bash
java -jar ~/labs-workspace/CalculatorMavenApp/target/calculator.jar
```

| Command | What it does |
|---|---|
| `git clone <url> <dir>` | Downloads the repo into a chosen folder. |
| `find . -type f -not -path './.git/*'` | Lists every real file, hiding git internals. Four files here. |
| `mvn test` | Compiles, then runs unit tests. Want `Tests run: N, Failures: 0, Errors: 0`. |
| `mvn clean` | Deletes `target/` so you can't ship a stale build. |
| `mvn package` | Runs the lifecycle up to packaging: **validate → compile → test → package**. A failed test stops it. |
| `ls -lh` | Lists with human-readable sizes (`3.7K`). |
| `java -jar <file>` | Runs the artifact. Type `10` ⏎ `5` ⏎ → `Sum: 15.0`, `Multiply: 50.0`. |

**Verify non-interactively** (how CI does it — no human types anything):

```bash
printf '10\n5\n' | java -jar ~/labs-workspace/CalculatorMavenApp/target/calculator.jar
```

> `printf` writes to stdout, `|` pipes it into the program's stdin, `\n` is the Enter key.

**Prove why `java -jar` works:**

```bash
unzip -p ~/labs-workspace/CalculatorMavenApp/target/calculator.jar META-INF/MANIFEST.MF
```

| Command | What it does |
|---|---|
| `unzip -p <jar> <path>` | Prints one file from the archive to stdout without unpacking — proving a JAR is a ZIP. |

Prints `Main-Class: com.example.calculator.Main` — the only reason the JAR is runnable.

**Commit:**

```bash
cd ~/iVolve-Tasks && git add "Build Tools/Lab1" && git commit -m "feat(lab1): build and package Calculator with Maven" && git push
```

---

## 5. Lab 2 — Gradle

**Goal:** the same app via a different tool → `build/libs/calculator.jar`.

```bash
git clone https://github.com/Ibrahim-Adel15/CalculatorGradleApp.git ~/labs-workspace/CalculatorGradleApp
```

```bash
cd ~/labs-workspace/CalculatorGradleApp && gradle test
```

```bash
cd ~/labs-workspace/CalculatorGradleApp && gradle clean build && ls -lh build/libs/calculator.jar
```

```bash
cd ~/labs-workspace/CalculatorGradleApp && gradle build
```

```bash
java -jar ~/labs-workspace/CalculatorGradleApp/build/libs/calculator.jar
```

| Command | What it does |
|---|---|
| `gradle test` | Runs tests. Terse by default — add `-i` for per-test output. |
| `gradle clean build` | Deletes `build/`, then compiles + tests + jars. |
| `gradle build` (2nd time) | Prints `UP-TO-DATE` and finishes instantly — **this is the point**, Gradle skips unchanged work. |
| `gradle run --console=plain -q` | Runs via the `application` plugin. `--console=plain` stops progress bars corrupting interactive input. |
| `gradle tasks` | Lists every available task. |

**View the HTML test report in your Windows browser:**

```bash
explorer.exe "$(wslpath -w ~/labs-workspace/CalculatorGradleApp/build/reports/tests/test/index.html)"
```

| Command | What it does |
|---|---|
| `wslpath -w <path>` | Converts a Linux path to its Windows form. |
| `explorer.exe <winpath>` | Opens it with the default Windows application. |

**Commit:**

```bash
cd ~/iVolve-Tasks && git add "Build Tools/Lab2" && git commit -m "feat(lab2): build and package Calculator with Gradle" && git push
```

---

## 6. Lab 3 — Docker

**Goal:** two images, sizes compared, both verified and cleaned up.

### Part 1 — build inside Docker

Write `~/labs-workspace/CalculatorMavenApp/Dockerfile.app1`, then:

```bash
cd ~/labs-workspace/CalculatorMavenApp && docker build -f Dockerfile.app1 -t app1 .
```

```bash
docker images app1
```

```bash
docker run -it --name container1 app1
```

```bash
docker run --rm --entrypoint whoami app1
```

```bash
docker rm container1 && docker rmi app1
```

| Command | What it does |
|---|---|
| `docker build -f <file> -t <name> .` | Builds an image. `-f` picks the Dockerfile, `-t` tags it, **`.` is the build context** — the folder sent to the daemon, which `COPY` reads from. |
| `docker images <name>` | Shows the image and its size. **Record it** — the bonus needs it. |
| `docker run -it --name X <img>` | Runs it. `-i` keeps stdin open (**mandatory** — without it the app crashes with `NoSuchElementException`), `-t` gives a terminal. |
| `docker run --rm --entrypoint whoami <img>` | Overrides the entrypoint for a one-off command. Must print `appuser`, proving the non-root requirement. `--rm` auto-deletes the container. |
| `docker rm <container>` | Deletes the container. |
| `docker rmi <image>` | Deletes the image — **container must go first**. |
| `docker history <image>` | Shows each layer and its size. Reveals exactly where the megabytes went. |

Expect **~500–800 MB**.

### Part 2 — build locally

```bash
cd ~/labs-workspace/CalculatorMavenApp && mvn clean package
```

```bash
printf 'src/\n.git/\ntarget/*\n!target/calculator.jar\nDockerfile*\n' > ~/labs-workspace/CalculatorMavenApp/.dockerignore
```

```bash
cd ~/labs-workspace/CalculatorMavenApp && docker build -f Dockerfile.app2 -t app2 . && docker images app2
```

```bash
docker run -it --name container2 app2
```

```bash
docker rm container2 && docker rmi app2
```

| Command | What it does |
|---|---|
| `.dockerignore` | Excludes files from the build context, like `.gitignore`. `!target/calculator.jar` re-includes one file after excluding its folder — later rules win. |

Expect **~200–300 MB**.

### Compare both — before deleting

```bash
docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}' | grep -E 'app1|app2|REPOSITORY'
```

| Command | What it does |
|---|---|
| `--format 'table {{...}}'` | Go-template output — prints only the columns you want. |

### Bonus — multi-stage

```bash
cd ~/labs-workspace/CalculatorMavenApp && docker build -f Dockerfile.multistage -t app3 . && docker images app3
```

Result: as small as `app2`, as reproducible as `app1`.

### Cleanup

```bash
docker system prune -af
```

| Command | What it does |
|---|---|
| `docker system prune -af` | Deletes all stopped containers and unused images. `-a` includes unused images, `-f` skips the prompt. Safe **between** labs, not during one. |

**Commit:**

```bash
cd ~/iVolve-Tasks && git add Docker/Lab3 && git commit -m "feat(lab3): add Dockerfiles for app1, app2 and multi-stage build" && git push
```

---

## 7. CI/CD — automating everything above

### Read this before copying any pipeline

**A CI pipeline needs source code to build. This repo has none.**

```
~/iVolve-Tasks/        ← write-ups and Dockerfiles. No pom.xml, no .java
~/labs-workspace/      ← the actual app, deliberately NOT committed
```

A workflow added here would run, find nothing to compile, and fail — a red ✗ on
your repo for the instructor to see. **The pipeline belongs in the application
repo, not the labs repo.**

So to actually run CI, first **fork the app**:

```bash
gh repo fork Ibrahim-Adel15/CalculatorMavenApp --clone --fork-name calculator-ci
```

| Command | What it does |
|---|---|
| `gh repo fork <repo> --clone` | Copies the repo to your account and clones it locally. |
| `--fork-name <name>` | Names your copy. |

Everything below goes in **that** repo.

---

### 7.1 GitHub Actions — build and test on every push

Create `.github/workflows/ci.yml`:

```yaml
name: CI

on:
  push:
    branches: [ main ]
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Check out the code
        uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: maven            # caches ~/.m2 between runs

      - name: Run unit tests
        run: mvn -B test

      - name: Build the artifact
        run: mvn -B clean package

      - name: Upload the JAR
        uses: actions/upload-artifact@v4
        with:
          name: calculator-jar
          path: target/calculator.jar
```

| Line | What it does |
|---|---|
| `on: push` | Triggers the pipeline on every push to `main`. |
| `runs-on: ubuntu-latest` | GitHub gives you a fresh Ubuntu VM per run. |
| `actions/checkout@v4` | Clones your repo into that VM. Nothing exists until you do this. |
| `setup-java` + `cache: maven` | Installs JDK 17 and caches `~/.m2`, so later runs skip re-downloading. |
| `mvn -B test` | **This is Lab 1, automated.** `-B` = batch mode, no progress spam in logs. |
| `mvn -B clean package` | **Lab 1's build step**, automated. A failing test stops the job here. |
| `upload-artifact` | Saves the JAR so you can download it from the run page. |

**That's the whole idea of CI:** the commands you ran by hand in Labs 1–3 now run
automatically, on a clean machine, on every push. If it passes on a fresh VM, it
isn't "works on my machine" any more.

```bash
git add .github/workflows/ci.yml && git commit -m "ci: build and test with Maven on every push" && git push
```

```bash
gh run list --limit 5
```

```bash
gh run watch
```

| Command | What it does |
|---|---|
| `gh run list` | Lists recent workflow runs and their status. |
| `gh run watch` | Follows the current run live in your terminal. |
| `gh run view --log-failed` | Shows logs for just the failed steps. |

---

### 7.2 Add the Docker stage — CD

Append this job to the same file. It builds **Lab 3's image** and pushes it to
GitHub's own registry (GHCR), which needs no extra account or secret.

```yaml
  docker:
    needs: build                     # only runs if tests passed
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write                # required to push to GHCR
    steps:
      - uses: actions/checkout@v4

      - name: Log in to GHCR
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Build and push
        uses: docker/build-push-action@v6
        with:
          context: .
          file: ./Dockerfile.multistage
          push: true
          tags: |
            ghcr.io/${{ github.repository_owner }}/calculator:latest
            ghcr.io/${{ github.repository_owner }}/calculator:${{ github.sha }}
```

| Line | What it does |
|---|---|
| `needs: build` | **The gate.** This job is skipped unless tests passed — a broken image is never published. |
| `secrets.GITHUB_TOKEN` | Automatically provided by GitHub. No secret to create. |
| `file: Dockerfile.multistage` | Uses your Lab 3 bonus Dockerfile — small *and* reproducible. |
| `tags:` two entries | `:latest` for convenience, `:${{ github.sha }}` pins the exact commit. **Always tag with the commit** — `latest` is ambiguous and makes rollback guesswork. |

Pull the published image from anywhere:

```bash
docker pull ghcr.io/eslamnabawy/calculator:latest && docker run -it ghcr.io/eslamnabawy/calculator:latest
```

> Packages are private by default. Make it public on the repo's **Packages** page if
> your instructor needs to pull it.

#### Pushing to Docker Hub instead

```bash
gh secret set DOCKERHUB_USERNAME
```

```bash
gh secret set DOCKERHUB_TOKEN
```

| Command | What it does |
|---|---|
| `gh secret set NAME` | Prompts for a value and stores it encrypted. **Never put credentials in the YAML.** |

Then swap the login step's `registry`/`username`/`password` to
`docker.io` / `${{ secrets.DOCKERHUB_USERNAME }}` / `${{ secrets.DOCKERHUB_TOKEN }}`.
Use a Docker Hub **access token**, not your password.

---

### 7.3 Doing it manually — what the pipeline automates

Every CI step maps to a command you can run yourself. Worth doing once so the YAML
isn't magic:

```bash
echo $GITHUB_TOKEN | docker login ghcr.io -u EslamNabawy --password-stdin
```

```bash
cd ~/labs-workspace/CalculatorMavenApp && docker build -f Dockerfile.multistage -t ghcr.io/eslamnabawy/calculator:latest .
```

```bash
docker push ghcr.io/eslamnabawy/calculator:latest
```

| Command | What it does |
|---|---|
| `docker login <registry> --password-stdin` | Authenticates. Reading from stdin keeps the token out of your shell history. |
| `docker tag <src> <dest>` | Renames an existing image for a registry. |
| `docker push <image>` | Uploads it. The tag's registry prefix decides where it goes. |

---

### 7.4 Jenkins — the same pipeline, next track

Jenkins is coming later in this training. It expresses the identical chain in a
`Jenkinsfile` committed beside your code:

```groovy
pipeline {
    agent any
    stages {
        stage('Test')  { steps { sh 'mvn -B test' } }
        stage('Build') { steps { sh 'mvn -B clean package' } }
        stage('Image') { steps { sh 'docker build -f Dockerfile.multistage -t calculator:$BUILD_NUMBER .' } }
    }
    post {
        always  { junit 'target/surefire-reports/*.xml' }
        failure { echo 'Build failed — image not produced.' }
    }
}
```

| Part | What it does |
|---|---|
| `stages` | Same order as Labs 1 → 3: test, build, image. |
| `$BUILD_NUMBER` | Jenkins increments it per run — same idea as tagging with the git SHA. |
| `junit '...surefire-reports/*.xml'` | Reads Maven's test XML so Jenkins can graph pass/fail over time. |

**GitHub Actions vs Jenkins:** Actions is hosted — nothing to maintain, free for public
repos. Jenkins you run and patch yourself, but it integrates with anything and many
companies already have one. The *pipeline logic* is identical; only the syntax differs.

---

## 8. Cheat sheet

| Command | Does |
|---|---|
| `mvn clean package` | Build the JAR (compiles + tests first) |
| `mvn test` | Tests only |
| `gradle clean build` | Gradle equivalent |
| `java -jar f.jar` | Run an artifact |
| `unzip -p f.jar META-INF/MANIFEST.MF` | Show the manifest |
| `docker build -f F -t N .` | Build an image |
| `docker images` | List images + sizes |
| `docker run -it --name N img` | Run interactively |
| `docker run --rm --entrypoint whoami img` | Check the user |
| `docker rm C && docker rmi I` | Delete container, then image |
| `docker system prune -af` | Reclaim disk space |
| `git status --short` | What changed |
| `git add -A && git commit -m "..."` | Stage and commit everything |
| `git push` | Upload |
| `git log --oneline` | Compact history |
| `gh run list` / `gh run watch` | CI status / follow live |
| `gh secret set NAME` | Store a credential encrypted |

### Troubleshooting one-liners

| Problem | Fix |
|---|---|
| `fatal: not in a git directory` | `git init -b main` first |
| `bash: NAME: No such file or directory` | Remove the `<` `>` placeholders — `<` is shell redirection |
| `nothing to commit` | No *file* changed — edit the lab README |
| `HTTP 401` from `gh` | `gh auth logout -h github.com -u <user>` then `gh auth login` |
| `Permission denied (publickey)` | Key not on GitHub — or just use HTTPS via `gh` |
| `Cannot connect to the Docker daemon` | `sudo service docker start` |
| `NoSuchElementException` | Add `-i` to `docker run` |
| `useradd: command not found` | Alpine — use `adduser -D` |
| `docker rmi` refuses | `docker rm` the container first |
