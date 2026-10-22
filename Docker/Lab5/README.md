# Lab 5 — Docker Image Vulnerability Scanning with Trivy

**Track:** Docker · **Source:** https://github.com/Ibrahim-Adel15/TrivyImage.git

Build the image exactly as shipped, scan it, then fix what the scan found and
prove the fix with a second scan. The app is a small Express server: `GET /`
and `GET /health` on port 3000.

## Requirements

- [x] Application and Dockerfile cloned from the provided repository
- [x] Image built and tagged `trivy-lab:v1` — **1.46 GB**
- [x] Trivy installed and verified — **0.76.1**
- [x] Image scanned and results reviewed
- [x] Scan filtered to **HIGH** and **CRITICAL** only
- [x] HTML report generated and reviewed — [`reports/trivy-v1.html`](reports/trivy-v1.html)

**Bonus — remediation**
- [x] HIGH/CRITICAL findings investigated
- [x] Base image and application dependency updated
- [x] Image rebuilt as `ivolve-app:v2` — **252 MB**
- [x] Rescanned, new HTML report — [`reports/trivy-v2.html`](reports/trivy-v2.html)
- [x] **No HIGH or CRITICAL vulnerabilities remain — no vulnerabilities at all**

---

## Results

| Image | Base | express | Size | Total | HIGH | CRITICAL |
|---|---|---|---|---|---|---|
| `trivy-lab:v1` | `node:18-bullseye` (Debian 11.11, EOL) | 4.18.2 | **1.46 GB** | 12,430 | **2,122** | **221** |
| `ivolve-app:v2` | `node:24-alpine` (Alpine 3.24.3) | 5.3.0 | **252 MB** | **0** | **0** | **0** |

```
$ trivy image trivy-lab:v1
trivy-lab:v1 (debian 11.11)
Total: 12430 (UNKNOWN: 105, LOW: 3047, MEDIUM: 6935, HIGH: 2122, CRITICAL: 221)

$ trivy image --severity HIGH,CRITICAL trivy-lab:v1
Total: 2343 (HIGH: 2122, CRITICAL: 221)

$ trivy image --severity HIGH,CRITICAL --ignore-unfixed trivy-lab:v1
Total: 1271 (HIGH: 1089, CRITICAL: 182)
```

**2,343 HIGH/CRITICAL findings.** 1,271 of them have a published fix — so the
gap between "fixable" and "total" is not an excuse to stop at 1,271.

After remediation, every target in the image reports zero:

```
$ trivy image --severity HIGH,CRITICAL ivolve-app:v2
Report Summary
│ ivolve-app:v2 (alpine 3.24.3)  │ alpine   │ 0 │
│ app/node_modules/*/package.json │ node-pkg │ 0 │   (all 66 targets, 0)
```

---

## Where the 2,343 findings actually came from

The big number is not the application. It is mostly things the app never uses:

| Source | Example findings |
|---|---|
| **Debian 11 (bullseye)** — end-of-life, no security updates | `libssl`, `zlib`, `perl-base`, `glibc` … |
| **npm's own bundled dependencies** (npm 10.8.2 ships ~17 MB of `node_modules`) | `tar` (CRITICAL), `sigstore`, `pacote`, `undici`, `brace-expansion` … |
| **express 4.18.2 transitive deps** | `path-to-regexp` 0.1.7 → CVE-2024-45296, CVE-2024-52798 |

Trivy even warns about the first one explicitly:

```
WARN  This OS version is no longer supported by the distribution  family="debian" version="11.11"
WARN  The vulnerability detection may be insufficient because security updates are not provided
```

`node:18` reached end-of-life in April 2025, so the base had both an old
userspace and no path to patches.

---

## The remediation

Two files changed, plus a lockfile. [`Dockerfile.v2`](Dockerfile.v2):

| Change | Why |
|---|---|
| `node:18-bullseye` → `node:24-alpine` | Current LTS; Alpine has a much smaller userspace, so fewer OS packages to be vulnerable at all |
| `express@4.18.2` → `express@5.3.0` | Fixes the `path-to-regexp` ReDoS family and the rest of the 4.x tree |
| `npm install` → `npm ci --omit=dev` + committed `package-lock.json` | Reproducible builds; dev dependencies never enter the image |
| `USER node` | Non-root runtime (the upstream Dockerfile runs as root) |
| `HEALTHCHECK` on `/health` | The app already exposes `/health`; the container can now report its own state |
| Remove `npm`, `npx`, `corepack`, `/opt/yarn-*` | They are build tools. Shipping them added ~20 MB and their bundled dependencies accounted for 4 HIGH findings on their own |

That last row is the interesting one. A first remediation pass
(`node:24-alpine` + express 5) still left **4 HIGH** — all of them inside
`/usr/local/lib/node_modules/npm` and `/opt/yarn-v1.22.22`, not in the app:

```
brace-expansion  CVE-2026-102276  HIGH  fixed
brace-expansion  CVE-2026-102278  HIGH  fixed
undici           CVE-2026-19534   HIGH  fixed
http-cache-semantics CVE-2026-93748 HIGH affected
```

The container starts `node app.js`, so no package manager is needed at runtime.
Removing them took the image to zero. **The lesson: a scanner counts what you
ship, not what you use.**

### Functional check after remediation

```
$ curl -s localhost:3000            → Welcome to the Trivy Security Lab!   HTTP 200
$ curl -s localhost:3000/health     → {"status":"UP"}                      HTTP 200
$ docker exec trivy2 whoami         → node
$ docker exec trivy2 node -v        → v24.22.1
$ docker inspect trivy2 --format '{{.State.Health.Status}}' → healthy
```

The fix is real: Express 5 still serves both routes, and the health check passes.

---

## Things worth knowing

**Trivy no longer embeds the HTML template.** The common command
`--template "@html.tpl"` fails with `open html.tpl: no such file or directory`
on 0.76.1. The template has to be fetched from the Trivy repository first:

```bash
curl -sSL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/html.tpl \
  -o ~/.local/share/trivy/html.tpl
trivy image --format template --template "@$HOME/.local/share/trivy/html.tpl" -o report.html IMAGE
```

**The full report is 40 MB; the HIGH/CRITICAL report is 9.3 MB.** Every finding
is a table row, so a 12,430-row report is impractical to open. The committed
report is filtered to HIGH/CRITICAL — matching what the lab actually asks you to
review — and it is still large enough to make the point.

**`--ignore-unfixed` is a reporting choice, not a fix.** It hides 1,072 findings
that have no patch yet. That is useful to prioritise, but the honest statement is
"1,271 fixable HIGH/CRITICAL", not "only 1,271 vulnerabilities".

**A CVE in a dependency you never call still counts.** `http-cache-semantics`
was reachable only through npm's own dependency tree, and it disappeared when
npm was removed — not because the code was patched, but because it stopped
being shipped.

**Trivy needs a database.** The first scan downloads ~130 MB of vulnerability
data; that is why the first run feels slow and later runs do not.

**Where this belongs in a pipeline.** `trivy image --exit-code 1 --severity HIGH,CRITICAL`
fails a CI job when a regression is introduced. The lab runs it manually; the
command is identical.

---

## Commit this lab

```bash
cd ~/iVolve-Tasks && git add Docker/Lab5 && \
  git commit -m "feat(lab5): scan images with Trivy and remediate HIGH/CRITICAL findings" && git push
```
