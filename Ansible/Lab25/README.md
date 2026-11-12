# Lab 25 — Ansible playbook: Docker + kubectl + Jenkins

> **Deck task:** write a playbook that installs Docker, kubectl and Jenkins on
> the managed node, then verify the three installs on that node.

## Requirements

- [x] One playbook (`playbook.yml`) that installs all three tools
- [x] Runs against the inventory created in Lab 24
- [x] Idempotent — a second run changes nothing
- [x] Verified **on the managed node**, not on the control node
- [x] Written so it would work on a plain VM as well as on these containers

## The playbook

```
Install Docker        apt: docker.io
Report the version    command: docker --version
Download kubectl      get_url on the CONTROL node (run_once, delegate_to localhost)
Download checksum     get_url, same release
Verify                sha256sum -c against the published checksum
Copy kubectl          copy to /usr/local/bin/kubectl, mode 0755
Report the version    command: kubectl version --client
Add the Jenkins key   get_url jenkins.io-2026.key -> /usr/share/keyrings/
Add the repository    apt_repository, update_cache
Download the .deb     get_url on the CONTROL node (run_once)
Copy the .deb         copy to each managed node
Install Jenkins       apt: deb=
Report the version    dpkg-query
Summary               debug, the three versions in one message
```

Two of those steps do their work on the control node rather than on the target.
That is the interesting part of this lab — see *Why the download happens on the
control node* below.

---

## Results

### First run — installs everything

```
TASK [Install Docker] **********************************************************
ok: [managed1]
ok: [managed2]

TASK [Download kubectl on the control node] ************************************
ok: [managed1 -> localhost]

TASK [Copy kubectl to the managed node] ****************************************
ok: [managed1]
ok: [managed2]

TASK [Download the Jenkins package on the control node] ************************
changed: [managed1 -> localhost]

TASK [Copy the package to the managed nodes] ***********************************
changed: [managed1]
changed: [managed2]

TASK [Install Jenkins from the package] ****************************************
changed: [managed1]
changed: [managed2]

TASK [Verification summary] ****************************************************
ok: [managed2] => {
    "msg": [
        "docker  : Docker version 29.1.3, build 29.1.3-0ubuntu3~24.04.2",
        "kubectl : /tmp/kubectl-v1.37.1: OK / Client Version: v1.37.1 Kustomize Version: v5.8.1",
        "jenkins : 2.580.2"
    ]
}

PLAY RECAP *********************************************************************
managed1                   : ok=15   changed=3    unreachable=0    failed=0
managed2                   : ok=11   changed=2    unreachable=0    failed=0
```

`managed1` shows a higher `ok` count than `managed2` because the two `run_once`
tasks execute once, on the first host in the play — `managed1 -> localhost`.
The work they do is shared with both nodes by the `copy` that follows.

### Second run — idempotence

```
PLAY RECAP *********************************************************************
managed1                   : ok=15   changed=0    unreachable=0    failed=0
managed2                   : ok=11   changed=0    unreachable=0    failed=0
```

`changed=0` on both nodes. `docker.io`, the kubectl binary, the apt repository
and the Jenkins package are all reported as already in the desired state, and
the two downloads are skipped because their files already exist.

### Verification, run from the control node against every managed node

```
== docker --version
managed2 | CHANGED | rc=0 | (stdout) Docker version 29.1.3, build 29.1.3-0ubuntu3~24.04.2
managed1 | CHANGED | rc=0 | (stdout) Docker version 29.1.3, build 29.1.3-0ubuntu3~24.04.2
== kubectl version --client
managed2 | CHANGED | rc=0 | (stdout) Client Version: v1.37.1\nKustomize Version: v5.8.1
managed1 | CHANGED | rc=0 | (stdout) Client Version: v1.37.1\nKustomize Version: v5.8.1
== dpkg-query -W -f='${Version}' jenkins
managed2 | CHANGED | rc=0 | (stdout) 2.580.2
managed1 | CHANGED | rc=0 | (stdout) 2.580.2
```

`CHANGED` here is Ansible reporting that the ad-hoc `shell` task ran, not that
anything on the node changed — `shell` cannot know.

---

## Why the download happens on the control node

The obvious playbook does this:

```yaml
- name: Install kubectl
  ansible.builtin.get_url:
    url: https://dl.k8s.io/release/v1.37.1/bin/linux/amd64/kubectl
    dest: /usr/local/bin/kubectl
```

It fails here:

```
fatal: [managed1]: FAILED! => {"changed": false, "elapsed": 0,
  "msg": "failed to create temporary content file: The read operation timed out"}
```

`get_url` uses a 10-second socket timeout by default. kubectl is 59 MB and takes
30–45 s from this host, so the connection dies mid-transfer. Raising `timeout:`
helps, but two nodes then pull the same 59 MB at the same time over a link that
is already the slowest part of the lab.

The playbook therefore downloads **once** on the control node, checks the
checksum against the release's published `.sha256`, and copies the verified
binary out:

```yaml
- name: Download kubectl on the control node
  ansible.builtin.get_url:
    url: "{{ kubectl_base }}/kubectl"
    dest: "{{ kubectl_local }}"
    timeout: 300
  delegate_to: localhost
  become: false
  run_once: true

- name: Verify the binary against it
  ansible.builtin.shell: echo "$(cat /tmp/kubectl.sha256)  {{ kubectl_local }}" | sha256sum -c -
  ...
```

That is also faster (one download instead of two) and easier to audit: the bytes
that reach the nodes are the bytes that were checked.

The Jenkins package gets the same treatment, for a different reason — see trap 5.

---

## Things worth knowing

1. **`get_url` will not overwrite an existing file.** After the Jenkins signing
   key was replaced upstream, the playbook kept the old keyring file and apt
   failed with `NO_PUBKEY 7198F4B714ABFC68`. The task needs `force: true` when
   the file at `dest` must be refreshed, otherwise the download is silently
   skipped — a stale file and a green-ish task.
2. **The Jenkins 2023 signing key expired on 2026-03-26.** `jenkins.io-2023.key`
   still downloads (HTTP 200) but it is no longer the key the repository is
   signed with; the 2026 key (fingerprint `7198 F4B7 14AB FC68`, valid to
   2028-12-21) is. A playbook that pins a URL and never re-checks it will
   eventually install an unsigned repository.
3. **`run_once` runs on the first host, not "everywhere".** That is why
   `managed1` shows `ok=15` and `managed2` shows `ok=11`; the difference is
   exactly the four control-node tasks. It is not a failure.
4. **`apt` is not a downloader.** Its own retry/timeout window is short and it
   does not resume. When the mirror it is assigned is slow, the failure arrives
   as `Failed to fetch ... Connection timed out` after two minutes, which looks
   like a broken repository. `curl` against the same file succeeded in 40 s.
5. **The repository and the package can be handled separately.** The playbook
   keeps `apt_repository` configured (so dependencies resolve normally) and
   installs the one large package from a file fetched with a 300 s timeout. The
   repository is still used; only the slow mirror is bypassed.
6. **These managed nodes have no systemd.** They are containers running `sshd`
   in the foreground. `apt` installs Jenkins and its `postinst` cannot start it;
   the lab verifies the installation (`dpkg-query`), not a running service. On a
   VM the same playbook gives you a started service.
7. **`kubectl version --client` prints a warning-free line only with
   `--client`.** Without it, kubectl tries to reach a cluster and the task fails
   on a node that has no kubeconfig — a false negative that looks like a broken
   install.
8. **The checksum is fetched, not typed in.** A hash written into the playbook
   proves nothing after the next release; comparing against the publisher's own
   `.sha256` is the version that keeps working.

## Reproduce

```bash
cd ~/iVolve-Tasks/Ansible/Lab25
./commands.sh
```

The script recreates the managed nodes if they are gone, pings them, runs the
playbook twice (install, then prove idempotence) and queries the three versions
on each node.

## Clean up

```bash
docker rm -f managed1 managed2
```

The nodes are shared with Labs 26 and 27, so the lab leaves them running.

## Commit

```bash
git add Ansible/Lab25
git commit -m "feat(lab25): playbook installing Docker, kubectl and Jenkins"
```
