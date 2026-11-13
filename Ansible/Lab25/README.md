# Lab 25: One playbook for Docker, kubectl and Jenkins

> **Deck task:** write a playbook that installs Docker, kubectl and Jenkins on
> the managed node, then verify the three installations.

## Requirements

- [x] A playbook that installs **Docker**
- [x] … that installs **kubectl**
- [x] … that installs **Jenkins**
- [x] Verification on the managed node, from the control node
- [x] The playbook is idempotent (second run changes nothing)

## Who is who

| Role | What it is |
|---|---|
| Control node | this WSL host, `ansible-core 2.16.3` |
| Managed nodes | two containers built in Lab 24 (`managed1:2222`, `managed2:2223`), reached over SSH with the key `~/.ssh/ivolve_lab24` |
| Inventory | `Ansible/Lab24/inventory.ini`, unchanged from Lab 24 |

The nodes are rebuilt from the Lab 24 image before every run, so the playbook
starts against an empty Ubuntu. A playbook run against nodes that are already
provisioned reports `changed=0` and proves nothing.

---

## The playbook

Fifteen tasks, one file: `playbook.yml`.

```yaml
- name: Install Docker, kubectl and Jenkins
  hosts: managed
  become: true
```

`hosts: managed` is the inventory group; `become: true` is why every task runs
as root without a password, the `ansible` user has `NOPASSWD` sudo.

### Docker, one apt task

```yaml
- name: Install Docker
  ansible.builtin.apt:
    name: docker.io
    state: present
    update_cache: true
    cache_valid_time: 3600
```

`cache_valid_time: 3600` keeps the second run from refreshing the index again:
that is part of what makes the idempotence claim below true.

### kubectl, downloaded once, on the control node

The obvious version of this task is a `get_url` per host. It failed:

```
fatal: [managed1]: FAILED! => {"msg": "failed to create temporary content file:
  The read operation timed out"}
```

`get_url` uses a **10-second** socket timeout. kubectl is 59 MB and takes 30–45 s
from this network, so the download dies even with `timeout: 120` set, because
the timeout applies per read, not to the whole transfer. Two parallel downloads
make it worse.

The playbook therefore downloads once, on the control node, with retries:

```yaml
- name: Download kubectl on the control node
  ansible.builtin.command:
    cmd: "curl -fsSL --retry 5 --retry-delay 5 --retry-all-errors -o {{ kubectl_local }} {{ kubectl_url }}"
    creates: "{{ kubectl_local }}"
  delegate_to: localhost
  become: false
  run_once: true
```

`creates:` is the idempotence guard: once the file exists the task is skipped, so
the second run does not re-download 59 MB. `run_once: true` means it runs for one
host only, the rest of the play then copies the file to every node.

The binary is verified against the checksum **published with the release**, not
against a hash typed into the playbook:

```yaml
- name: Verify the downloaded binary against it
  ansible.builtin.shell: |
    set -eu
    printf '%s  %s\n' "{{ kubectl_sha_published.content | trim }}" "{{ kubectl_local }}" | sha256sum -c -
```

A hash copied into a file proves nothing after the next patch release; a hash
fetched from the same release as the binary proves the transfer was not
corrupted or replaced.

### Jenkins, a repository, a key, and a package

The repository is configured the normal Debian way:

```yaml
- name: Add the Jenkins repository
  ansible.builtin.apt_repository:
    repo: "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/"
```

Two things then had to change from the textbook version:

**1. The key must be the current one.** `jenkins.io-2023.key` expired on
2026-03-26 and apt refuses the repository with `NO_PUBKEY`. The playbook uses
`jenkins.io-2026.key` (valid to 2028-12-21).

**2. The package cannot be left to apt.** `pkg.jenkins.io` redirects the
`.deb` to a mirror; on this network the 53.8 MB transfer exceeded apt's
connection window:

```
E: Failed to fetch https://mirrors.zerolag.ro/.../jenkins_2.580.2_all.deb
   Connection timed out
```

The same URL fetched with `curl --retry` completes in about 40 s. So the package
is fetched once on the control node and installed from disk, the same pattern
as kubectl, with the same `creates:` guard:

```yaml
- name: Install Jenkins from the package
  ansible.builtin.apt:
    deb: "{{ jenkins_deb_local }}"
```

The repository stays configured: it is still what supplies Jenkins'
dependencies, and the key is still what lets apt trust it.

---

## How it went

First run, against freshly rebuilt nodes. This is where the installing happens:

```
PLAY RECAP *********************************************************************
managed1                   : ok=16   changed=6    unreachable=0    failed=0
managed2                   : ok=11   changed=6    unreachable=0    failed=0
```

`managed2` shows fewer `ok` tasks because the five `run_once` tasks (the four
control-node downloads plus the checksum read) are counted only on the first
host.

The six changes per node are exactly the six state-changing tasks: Docker
the kubectl binary, the keyring, the apt repository, the copied `.deb`, and the
Jenkins package.

Verification, read back from the nodes:

```
"docker  : Docker version 29.1.3, build 29.1.3-0ubuntu3~24.04.2"
"kubectl : sha256 65691ff77eb6fa44c908b77a1082c9f092c3b9733b5cefabec0d1104890e21a8 (matches the published checksum)"
"kubectl : Client Version: v1.37.1 Kustomize Version: v5.8.1"
"jenkins : 2.580.2"
```

Second run, the same playbook against the same nodes:

```
managed1                   : ok=16   changed=0    unreachable=0    failed=0
managed2                   : ok=11   changed=0    unreachable=0    failed=0
```

`changed=0` on every task is the idempotence claim. The downloads were skipped
(`creates:`), the packages were already present, and `cache_valid_time` kept the
APT index from being refreshed needlessly.

---

## What tripped me up

1. **`get_url` has a 10-second socket timeout, and `timeout:` does not fix a
   slow transfer.** It sets the per-operation timeout; a 59 MB download on a
   30 s/MB link still fails. `curl --retry-all-errors` with `creates:` is the
   robust shape for large artefacts.
2. **A checksum proves a transfer, not a build.** Fetching the `.sha256` from
   the same release as the binary is meaningful; hard-coding it is not.
3. **Ubuntu's `jenkins.io-2023.key` is expired.** The symptom is `NO_PUBKEY`
   plus "repository is not signed", which reads like a repository problem and is
   a key-age problem.
4. **`get_url` will not overwrite an existing file.** Changing the key URL is
   not enough if the old file is still on disk: the download is skipped and apt
   keeps failing on the stale key. Either remove the file or download to a new
   path.
5. **These managed nodes are containers, so there is no systemd.** Docker's
   daemon is not started (nothing would supervise it); the package and the
   binary are what the lab installs and verifies. On a VM the same playbook
   would add a `service` task, and nothing else would change.
6. **`run_once` is per play, not per task.** Combined with `delegate_to:
   localhost` it turns "one download" into a real guarantee instead of two
   simultaneous downloads racing each other.
7. **`ok=16` versus `ok=11` is not a failure.** The difference is the five
   `run_once` tasks; `failed=0` on both hosts is what matters.

---

## To replay this

```bash
cd ~/iVolve-Tasks/Ansible/Lab25
./commands.sh
```

The script rebuilds both managed nodes, re-installs the Lab 24 SSH key, runs
`ansible -m ping`, runs the playbook, reads the three versions back, then runs
the playbook a second time to show `changed=0`.

## Clean up

```bash
docker rm -f managed1 managed2
docker rmi ivolve-node:base
```

## Put it in git

```bash
git add Ansible/Lab25
git commit -m "feat(lab25): playbook installing Docker, kubectl and Jenkins"
```
