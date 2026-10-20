# iVolve DevOps Training — Master Guide (WSL Edition)

Your working guide for the whole track. Read this once end-to-end, then work lab by lab.

- **OS:** Ubuntu 24.04.4 LTS on WSL2
- **Repo root:** `~/DevOps-Labs`
- **App used by Labs 1–3:** `CalculatorMavenApp` / `CalculatorGradleApp`

---

## 0. Know what you're actually building

Before any command, understand the app. Every lab in the first three uses the same tiny Java program:

```java
Scanner scanner = new Scanner(System.in);
System.out.print("Enter first number: ");
double a = scanner.nextDouble();
...
```

**It is an interactive command-line program.** It reads two numbers from standard input, prints sum/subtract/multiply/divide, and exits. It is **not** a web server. Nothing listens on any port.

Why this matters immediately:

- Lab 3 tells you to `EXPOSE 8080`. You will do it, because the lab asks. But know that `EXPOSE` is **pure metadata** — a documentation label stored in the image. It opens nothing, binds nothing, and for this app it has zero runtime effect. Trainers include it as a habit-forming step.
- "Verify the application" does **not** mean `curl localhost:8080`. It means: run the container, type two numbers, see correct math. You will need `docker run -i` so the container actually receives your keystrokes.

Understanding this one thing puts you ahead of most people doing these labs.

---

## 1. One-time WSL setup

### 1.1 Current state of your machine

Already installed and working: `git` 2.43, `docker` 29.1.3 (daemon is native in WSL, Ubuntu 24.04), `kind` 0.33, `helm`, `ansible` 2.16, `kubectl` (a `kind-aiops` cluster is your current context).

Missing, and needed now: **Java 17**, **Maven**, **Gradle**. Missing, needed later: `argocd` CLI, `gh` CLI.

### 1.2 Install Java 17 + Maven (Lab 1)

```bash
sudo apt update && sudo apt install -y openjdk-17-jdk maven
```

Verify — both must report 17:

```bash
java -version && mvn -version
```

`mvn -version` prints the JDK it will actually use. If that line says anything other than 17, Maven is picking a different JDK; fix it by setting `JAVA_HOME`:

```bash
echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' >> ~/.bashrc && source ~/.bashrc
```

### 1.3 Install Gradle (Lab 2)

Do **not** use `apt install gradle` — Ubuntu ships an old version that fails on modern `build.gradle` syntax. Use SDKMAN, which is how Gradle is managed in the real world:

```bash
curl -s "https://get.sdkman.io" | bash && source "$HOME/.sdkman/bin/sdkman-init.sh"
```

```bash
sdk install gradle
```

```bash
gradle -version
```

SDKMAN also lets you hold several JDKs side by side (`sdk list java`) — a skill worth having.

### 1.4 Docker without sudo

If `docker ps` says "permission denied":

```bash
sudo usermod -aG docker $USER
```

Then **close and reopen your WSL terminal** (group membership is read at login; `newgrp` only patches the current shell).

### 1.5 WSL filesystem rule — this one bites people

Keep **all** project files under the Linux filesystem (`/home/eslam/...`), never under `/mnt/c/...`.

Builds on `/mnt/c` cross the Windows↔Linux filesystem bridge and run **5–20x slower**, and Linux file permissions (the executable bit, which matters for `mvnw`/`gradlew`) are not stored faithfully. Your repo at `~/DevOps-Labs` is correct. Your lab screenshots living on the Windows Desktop is fine — those are just images.

To open the repo in VS Code from WSL:

```bash
code ~/DevOps-Labs
```

---

## 2. Git & GitHub setup

### 2.1 Initialise the repo and fix your commit identity

**Order matters here.** `git config` without `--global` writes into `.git/config`, so the repo must exist first — running it in a plain directory fails with `fatal: not in a git directory`.

```bash
cd ~/DevOps-Labs && git init -b main
```

Your global git identity is `Nabawy <eslam@nabawy.dev>`. For training work submitted to iVolve, set a per-repo identity matching your GitHub account so commits are attributed to you there:

```bash
cd ~/DevOps-Labs && git config user.name "Eslam" && git config user.email "eslamlef.308@gmail.com"
```

Repo-level config (no `--global`) overrides global **only inside this repo** — your other projects keep the `nabawy.dev` identity. Verify:

```bash
cd ~/DevOps-Labs && git config user.email
```

The three scopes, in increasing precedence: `--system` (whole machine) → `--global` (`~/.gitconfig`, all your repos) → local (`.git/config`, this repo). `git config --list --show-origin` shows every value and which file it came from.

### 2.2 SSH key for GitHub

Check whether you already have one:

```bash
ls -la ~/.ssh
```

If there's no `id_ed25519.pub`, create one:

```bash
ssh-keygen -t ed25519 -C "eslamlef.308@gmail.com"
```

Press Enter through the prompts. Then print the **public** key and paste it into GitHub → Settings → SSH and GPG keys → New SSH key:

```bash
cat ~/.ssh/id_ed25519.pub
```

Never share `id_ed25519` (no `.pub`) — that's the private half.

Test it:

```bash
ssh -T git@github.com
```

"Hi <username>! You've successfully authenticated" is success, even though it then says shell access is denied.

### 2.3 First commit and push

Create an **empty** repo named `DevOps-Labs` on GitHub (no README, no .gitignore — you already have them). Then commit what's here (the repo was initialised in §2.1):

```bash
cd ~/DevOps-Labs && git add . && git commit -m "chore: scaffold DevOps labs repo"
```

```bash
cd ~/DevOps-Labs && git remote add origin git@github.com:<your-username>/DevOps-Labs.git && git push -u origin main
```

### 2.4 Commit discipline

Commit **per lab**, not one giant dump at the end. Your git history is part of what's being assessed — it shows how you work.

```bash
git add "Build Tools/Lab1" && git commit -m "feat(lab1): build and package Calculator with Maven"
```

Use [Conventional Commits](https://www.conventionalcommits.org/) prefixes — `feat:`, `fix:`, `docs:`, `chore:`, `ci:`. It's the industry default and costs nothing to adopt now.

---

## 3. How to work a lab

The same loop every time. Resist the urge to skip step 1.

1. **Read the lab slide.** Write the requirements as a checklist in that lab's `README.md` *before* you start.
2. **Do it by hand first.** Type the commands. Don't copy-paste blindly — you learn the failure modes only by hitting them.
3. **Capture evidence.** Terminal output, `docker images` sizes, test results. Paste into the README.
4. **Explain *why*, not just *what*.** The README should answer "why this base image?", "why a non-root user?". This is the difference between a lab submission and a portfolio.
5. **Commit** with a scoped message.

### What belongs in a lab folder

```
Lab3/
├── README.md        ← requirements, steps, output, explanation
├── Dockerfile       ← the artifact you authored
└── .dockerignore
```

**Do not commit:** cloned upstream source (`CalculatorMavenApp/`), `target/`, `build/`, `*.jar`, `.gradle/`. The root `.gitignore` already blocks these. Your repo holds *your work* — the Dockerfiles, configs, manifests, playbooks and write-ups. Keep clones outside the repo, in `~/labs-workspace/`.

```bash
mkdir -p ~/labs-workspace
```

---

## 4. The core concepts, lab by lab

Skim now; return when you reach each lab.

### Labs 1–2 — Build tools

A build tool turns source into a distributable artifact, reproducibly. Both Maven and Gradle run the same **lifecycle**: compile → test → package.

| | Maven | Gradle |
|---|---|---|
| Config | `pom.xml` (XML, declarative) | `build.gradle` (Groovy/Kotlin, programmable) |
| Build | `mvn package` | `gradle build` |
| Test only | `mvn test` | `gradle test` |
| Output | `target/calculator.jar` | `build/libs/calculator.jar` |
| Clean | `mvn clean` | `gradle clean` |

The key idea in both `pom.xml` and `build.gradle` here: the **manifest `Main-Class` attribute**. A `.jar` is just a zip; it only becomes runnable with `java -jar` because the manifest names an entry point. Open `pom.xml` and find `<mainClass>` — that's the line doing it.

> **Slide note:** Lab 2's title says "Go Application with Gradle". The repo is Java, not Go. The slide has a copy-paste error; build it as Java.

### Lab 3 — Docker

Two ways to produce an image, and the lab makes you build both so you *feel* the difference:

- **Part 1 (build inside Docker)** — ship the full Maven toolchain in the image. Self-contained and reproducible on any machine, but the result carries a JDK, Maven, and your whole dependency cache. Expect **~500–800 MB**.
- **Part 2 (build locally)** — compile on the host, copy only the finished `.jar` into a JRE-only image. Expect **~200–300 MB**.

The bonus question asks you to explain the gap. The real answer: **build-time dependencies are not run-time dependencies.** A compiler, a build tool and a dependency cache are needed to *produce* the jar and are dead weight once it exists. They also widen your security attack surface — every tool in a production image is something that can be exploited.

The professional resolution to this tradeoff is the **multi-stage build**: one stage builds with Maven, a second copies just the jar into a slim runtime. You get Part 1's reproducibility at Part 2's size. The lab doesn't require it — do it anyway as a third image and your submission stands out. That's the bonus answered with code, not prose.

**Non-root user:** by default a container process runs as root. If an attacker escapes the application, they're root inside the container — and with a kernel exploit or a bad mount, that reaches the host. Running as an unprivileged user is a one-line change and a standard production requirement.

---

## 5. Troubleshooting WSL

**`docker: command not found` or "cannot connect to the Docker daemon"**
```bash
sudo service docker start
```
WSL has no systemd by default, so the daemon doesn't always auto-start on boot.

**Maven build is painfully slow the first time**
Normal. Maven is downloading the world into `~/.m2`. Subsequent builds hit the cache and are fast.

**Out of memory / WSL eating RAM**
You have 9.7 GB allocated. Cap it by creating `C:\Users\eslam\.wslconfig` in Windows with:
```
[wsl2]
memory=6GB
processors=4
```
Then `wsl --shutdown` from PowerShell.

**Reclaim Docker disk space between labs**
```bash
docker system prune -af
```
This deletes all stopped containers and unused images. Safe between labs; don't run it mid-lab.

---

## 6. What's ahead

Folders for Kubernetes, Jenkins, ArgoCD and Ansible get created as those labs arrive. You already have `kind`, `helm`, `kubectl` and `ansible`, so you're set up for most of them. You'll need the `argocd` CLI and likely Jenkins in a container when you get there.

When you receive new lab slides, drop the images anywhere and say the word — the folder, README skeleton and checklist get generated the same way these were.
