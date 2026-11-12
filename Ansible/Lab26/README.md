# Lab 26 — Roles: Docker, kubectl and Jenkins as reusable units

> **Deck task:** convert the Lab 25 playbook into roles, so the same three
> installations can be reused by any playbook.

## Requirements

- [x] Three roles — `docker`, `kubectl`, `jenkins`
- [x] `site.yml` is nothing but a list of role names
- [x] Every version, URL and path lives in that role's `defaults/`
- [x] The roles install everything on both managed nodes
- [x] A second run changes nothing
- [x] Versions read back from the nodes

## What a role actually is

A role is a directory with a fixed shape. Ansible looks for `tasks/main.yml`
automatically; nothing in `site.yml` names a file.

```
roles/docker/
├── defaults/main.yml     ← the role's knobs, overridable, lowest precedence
└── tasks/main.yml        ← what the role does
```

The tree on disk:

```
commands.sh
roles/docker/defaults/main.yml
roles/docker/tasks/main.yml
roles/jenkins/defaults/main.yml
roles/jenkins/tasks/main.yml
roles/kubectl/defaults/main.yml
roles/kubectl/tasks/main.yml
site.yml
```

`defaults/` is the important half. `vars/main.yml` would look identical and
behave very differently: defaults sit at the **bottom** of Ansible's variable
precedence, so a play, an inventory file or `--extra-vars` can override them.
Vars sit near the top and are effectively frozen. Packaging a role with
`vars/` produces a role nobody can configure.

## site.yml

```yaml
- name: Provision managed nodes with roles
  hosts: managed
  become: true
  gather_facts: true

  roles:
    - docker
    - kubectl
    - jenkins
```

That is the whole play. Compare it with Lab 25's fifteen tasks.

**`roles:` is play order.** The three entries run top to bottom, in exactly the
order written — roles are not sorted or parallelised. Here the order is not
cosmetic: `kubectl` and `jenkins` both use `apt`, and `docker`'s
`cache_valid_time: 3600` gets the index warm so the later two do not pay for a
refresh.

## How the roles differ from the Lab 25 playbook

Not much — and that is the point. The tasks moved, the logic did not:

| Lab 25 (flat playbook) | Lab 26 (roles) |
|---|---|
| `vars:` block, 6 entries | each role's `defaults/main.yml` |
| 15 tasks in one file | 18 tasks across three roles (4 + 6 + 8) |
| every host gets everything | a play names only the roles it needs |

Three things did change, all intentional:

1. **`kubectl` verifies with `sha256sum -c`** against the published `.sha256`
   instead of comparing two strings in `failed_when:`. The file is checked by
   the tool the checksum was designed for, and a failure names the file.
2. **`jenkins` reads the version with `dpkg-query`** — the same command the
   verification step uses, so the role's own output and the final proof cannot
   disagree.
3. **`docker` retries the install.** `docker.io` pulls 45 packages and 93 MB
   from `archive.ubuntu.com`. On the first attempt of this lab both nodes died
   mid-download:

   ```
   E: Failed to fetch http://archive.ubuntu.com/ubuntu/pool/main/c/containerd-app/
      containerd_2.2.1-0ubuntu1~24.04.4_amd64.deb  Connection timed out
   E: Unable to fetch some archives, maybe run apt-get update or try with --fix-missing?
   Fetched 33.6 MB in 7min 40s (73.0 kB/s)
   ```

   The role now writes `/etc/apt/apt.conf.d/99-ivolve-retries`
   (`Acquire::Retries "10"`, `http::Timeout "120"`) and retries the whole task
   six times with `until: docker_install is succeeded`. The `apt` module keeps
   the `.deb`s it already fetched, so each retry resumes rather than restarts.

The three downloads keep the shape that made Lab 25 work: **fetched once on the
control node**, guarded by `creates:`, then copied to every node.

```yaml
- name: Download the Jenkins package on the control node
  ansible.builtin.command:
    cmd: "curl -fsSL --retry 5 --retry-delay 5 --retry-all-errors -o {{ jenkins_deb_local }} {{ jenkins_deb_url }}"
    creates: "{{ jenkins_deb_local }}"
  delegate_to: localhost
  become: false
  run_once: true
```

The defaults for that role:

```yaml
jenkins_version: 2.580.2
jenkins_key_url: https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key
jenkins_deb_url: "https://get.jenkins.io/debian-stable/jenkins_{{ jenkins_version }}_all.deb"
jenkins_key_local: /tmp/jenkins-keyring.asc
jenkins_key_dest: /usr/share/keyrings/jenkins-keyring.asc
jenkins_deb_local: "/tmp/jenkins_{{ jenkins_version }}_all.deb"
```

To install a different Jenkins on a different host, only this file changes —
which is the entire argument for roles.

---

## Result

Both managed nodes were rebuilt from the Lab 24 image first, so this is a real
install and not a re-read of an already-provisioned machine.

First run:

```
managed1                   : ok=19   changed=7    unreachable=0    failed=0
managed2                   : ok=14   changed=7    unreachable=0    failed=0
```

`managed2` shows five fewer `ok` because the `run_once` tasks — the three
control-node downloads, the checksum read and the verification — are counted
only on the first host.

`changed=7` is the seven state changes each node receives: the apt retry config,
Docker, the kubectl binary, the keyring, the apt repository, the copied `.deb`
and the Jenkins package. The three downloads themselves were already in `/tmp`
on the control node from the previous attempt, so `creates:` skipped them — that
is the guard doing its job, not a missing install.

Second run, same nodes, same `site.yml`:

```
managed1                   : ok=19   changed=0    unreachable=0    failed=0
managed2                   : ok=14   changed=0    unreachable=0    failed=0
```

Versions, read back from each node in one ad-hoc task:

```
managed1 | CHANGED | rc=0 | (stdout) Docker version 29.1.3, build 29.1.3-0ubuntu3~24.04.2\nClient Version: v1.37.1\nKustomize Version: v5.8.1\n2.580.2
managed2 | CHANGED | rc=0 | (stdout) Docker version 29.1.3, build 29.1.3-0ubuntu3~24.04.2\nClient Version: v1.37.1\nKustomize Version: v5.8.1\n2.580.2
```

Three versions, one line per host — the roles and the flat playbook leave the
nodes in exactly the same state.

---

## Things worth knowing

1. **`defaults/` versus `vars/` is the first design decision in any role.**
   Defaults are meant to be overridden; vars are not. A role shipped with
   `vars/` cannot be reconfigured without editing the role.
2. **`roles:` order is execution order.** Ansible runs the listed roles in
   sequence; there is no dependency graph inside a single play. If `jenkins`
   needs `docker`, put `docker` first — or declare the dependency in
   `meta/main.yml` instead.
3. **A role is only a directory convention.** `tasks/main.yml` is found
   automatically, which is why `site.yml` names a directory and never a file.
   There is no `import` anywhere.
4. **`run_once: true` still counts per play, not per role.** Adding roles does
   not turn three control-node downloads into six; each `run_once` task counts
   once, whether it lives in a play or in a role.
5. **Roles make the *play* reusable but not the *host* reusable.** Pointing
   `hosts:` at another group is now a one-word change — that is what turned
   Labs 24–28 from nine separate scripts into one set of units.
6. **`gather_facts: true` is explicit here.** It is the default, but a role that
   reads `ansible_os_family` should not silently depend on a default someone
   may later turn off.
7. **`apt` has no retry knob in Ansible; apt itself does.** `apt.conf.d`'s
   `Acquire::Retries` retries individual files inside one apt run, and
   `until: result is succeeded` retries the task. One without the other is not
   enough: the task retry alone restarts a 93 MB fetch from zero when the file
   list has already been partly cached, and the file retry alone gives up when
   the connection is dropped outright.
8. **A slow mirror looks like a broken playbook.** `Fetched 33.6 MB in 7min 40s
   (73.0 kB/s)` is a network fact, and the honest fix is retries — not
   `--fix-missing` and not a `ignore_errors: true`.
9. **`changed_when` overrides `creates:`.** The first version of these roles
   had `changed_when: reg.rc == 0` on the three downloads so they counted as
   changes when they actually ran. It also made them report `changed` when
   `creates:` skipped them — the second run showed `changed=3` on the first
   host and nothing was wrong except the guard. The `command` module already
   reports `changed` only when the command really ran; the guard was deleted and
   the recap became `changed=0`.

---

## Reproduce

```bash
cd ~/iVolve-Tasks/Ansible/Lab26
./commands.sh
```

The script rebuilds the two managed nodes, re-installs the Lab 24 SSH key,
prints the role tree and every role's defaults, runs `site.yml`, runs it a
second time for the idempotence proof, then reads the three versions back.

## Clean up

```bash
docker rm -f managed1 managed2
docker rmi ivolve-node:base
```

## Commit

```bash
git add Ansible/Lab26
git commit -m "feat(lab26): Docker, kubectl and Jenkins as reusable roles"
```
