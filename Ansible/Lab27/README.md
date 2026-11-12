# Lab 27 — Securing sensitive data with Ansible Vault

> **Deck task:** create a MySQL role that installs MySQL, creates the `ivolve`
> database and an `ivolveuser` with all privileges on it; keep the password in
> Ansible Vault; then prove the account works by connecting as it and listing
> the databases.

## Requirements

- [x] A **MySQL role**
- [x] … that installs MySQL
- [x] … that creates the `ivolve` database
- [x] … that creates `ivolveuser` with all privileges on `ivolve`
- [x] The password lives in an **Ansible Vault** file, not in the role
- [x] Validation: connect as `ivolveuser` and list the databases

## Layout

```
Lab27/
├── site.yml                     # one play, one role
├── group_vars/managed/vault.yml # AES-256 ciphertext (committed)
├── roles/mysql/
│   ├── defaults/main.yml        # names, packages, retry knobs — nothing secret
│   └── tasks/main.yml           # install → start → database → account → proof
├── commands.sh
└── .gitignore                   # .vault-pass
```

The managed nodes are the Lab 24 containers (`managed1:2222`, `managed2:2223`),
rebuilt from the Lab 24 image before every run.

---

## The role

### Install

```yaml
- name: Install MySQL and the Python driver the modules use
  ansible.builtin.apt:
    name:
      - "{{ mysql_package }}"
      - "{{ mysql_python_driver }}"
```

`python3-pymysql` is not optional: `community.mysql.mysql_db` and
`mysql_user` are Python modules that run **on the managed node** and need a
MySQL driver there.

The install is wrapped in `until: mysql_install is succeeded` with six retries,
and `/etc/apt/apt.conf.d/99-ivolve-retries` sets `Acquire::Retries 10` and
120-second timeouts. Same reason as Lab 26: this network drops large apt
transfers.

### Start — without systemd

The managed nodes are containers. There is no systemd, so
`service: name=mysql state=started` cannot work, and the package's post-install
script cannot start the server either. Two things follow:

```yaml
- name: Create the socket directory
  ansible.builtin.file:
    path: /var/run/mysqld
    state: directory
    owner: mysql
    group: mysql

- name: Start mysqld
  ansible.builtin.command: /usr/sbin/mysqld --daemonize --user=mysql
  when: mysqld_running.rc != 0
```

On a VM `/var/run/mysqld` is a tmpfs created by `systemd-tmpfiles`; in a
container nothing creates it and `mysqld` exits without saying why. The start
task is guarded by a `pgrep` so the second playbook run does not start a second
server.

A `mysqladmin ping` loop with 30 retries / 2 s waits for the socket before any
module talks to it — the first version raced the server and failed with
`Can't connect to local MySQL server through socket`.

### Database and account

```yaml
- name: Create the ivolve database
  community.mysql.mysql_db:
    name: "{{ mysql_db }}"
    state: present
    login_unix_socket: "{{ mysql_socket }}"

- name: Create ivolveuser with all privileges on ivolve
  community.mysql.mysql_user:
    name: "{{ mysql_user }}"
    password: "{{ vault_mysql_user_password }}"
    priv: "{{ mysql_db }}.*:ALL"
    host: "%"
    state: present
    login_unix_socket: "{{ mysql_socket }}"
  no_log: true
```

`login_unix_socket` is what makes root usable: Ubuntu's `root@localhost` is
authenticated by `auth_socket`, and Ansible runs the role as root, so no root
password exists anywhere in this lab.

`no_log: true` matters more than it looks: without it Ansible prints the module
arguments — password included — in the task result on every run.

`host: "%"` creates `ivolveuser` for any source address. The validation below
connects over TCP to 127.0.0.1, which only matches `%` (a `localhost`-only
account would refuse a TCP login on some MySQL builds).

### The proof

```yaml
- name: Log in as ivolveuser and list the databases
  ansible.builtin.shell: |
    set -eu
    mysql -u {{ mysql_user }} -p"$MYSQL_PWD" -h 127.0.0.1 -N -e 'SHOW DATABASES;' | sort
  environment:
    MYSQL_PWD: "{{ vault_mysql_user_password }}"
  no_log: true
```

The password goes through `MYSQL_PWD`, not `-p<password>` on the command line:
arguments are visible in `ps` to every user on the host, environment variables
are not.

---

## The vault

The secret is one file, and it is committed as ciphertext:

```
$ head -2 Lab27/group_vars/managed/vault.yml
$ANSIBLE_VAULT;1.1;AES256
66386439653236336464393439643238393436363564303336393564323564383239613033313038
```

`group_vars/managed/` is where it has to live: Ansible loads it for the
`managed` group automatically, so the role refers to
`{{ vault_mysql_user_password }}` and never to a file path.

**The key is not committed.** `commands.sh` writes `.vault-pass` (which
`.gitignore` excludes) with a throwaway string, and every Ansible call passes
`--vault-password-file`. That is the whole mechanism — and the honest caveat:
the throwaway string is in `commands.sh` because the ciphertext here protects
lab data. A real vault password is never stored next to the ciphertext; it is
typed, or read from a secret manager, or from a file the playbook user owns.

One consequence caught this lab: `group_vars/` is loaded for **ad-hoc** commands
too. The first version ran `ansible -m ping` before creating `.vault-pass` and
died with:

```
ERROR! Attempting to decrypt but no vault secrets found
```

The key file is now created before anything else runs.

---

## Result

First run, against freshly rebuilt nodes — six changes each, `failed=0`:

```
PLAY RECAP *********************************************************************
managed1                   : ok=11   changed=6    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
managed2                   : ok=11   changed=6    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

The six changes are the six state-changing tasks: the apt retry file, the MySQL
package + driver, the socket directory, the `mysqld` start, the `ivolve`
database and the `ivolveuser` account.

What `ivolveuser` can see, read back by logging in **as that user**:

```
TASK [mysql : Show what ivolveuser can see] ************************************
ok: [managed1] => {
    "msg": "databases visible to ivolveuser: information_schema, ivolve, performance_schema"
}
ok: [managed2] => {
    "msg": "databases visible to ivolveuser: information_schema, ivolve, performance_schema"
}
```

Second run, same role, same nodes:

```
managed1                   : ok=10   changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
managed2                   : ok=10   changed=0    unreachable=0    failed=0    skipped=1    rescued=0    ignored=0
```

`changed=0` is the idempotence claim; the one skip is the `Start mysqld` task,
correctly skipped because `pgrep` found the server already running.

An independent check that does not use the vault at all — root over the socket:

```
managed1 | CHANGED | rc=0 | (stdout) information_schema\nivolve\nmysql\nperformance_schema\nsys\nivolveuser	%
managed2 | CHANGED | rc=0 | (stdout) information_schema\nivolve\nmysql\nperformance_schema\nsys\nivolveuser	%
```

`ivolve` exists on both nodes and `ivolveuser` is present for host `%`.

And what sits in git:

```
$ head -2 Lab27/group_vars/managed/vault.yml
$ANSIBLE_VAULT;1.1;AES256
66663635383763323737643965656135646234626630626131343138303664313532373562383133

$ ansible-vault view --vault-password-file .vault-pass group_vars/managed/vault.yml | sed 's/: .*/: <redacted>/'
---
# Lab 27 — the one secret this lab has: <redacted>
```

---

## Things worth knowing

1. **`group_vars/` is not just for playbooks.** Ad-hoc `ansible` commands in the
   same directory load it, so they need `--vault-password-file` too.
2. **A container has no systemd, but MySQL does not care.** Start `mysqld`
   directly with `--daemonize`, create the socket directory yourself, and guard
   the start with `pgrep` so the second run stays idempotent.
3. **`no_log: true` is part of the design, not decoration.** Module arguments
   are printed on success; a password in `mysql_user:` without `no_log` ends up
   in the terminal and in any log the run is piped to.
4. **`MYSQL_PWD` over `-p<password>`.** Command-line arguments are world-readable
   in `ps`.
5. **Ubuntu's `root@localhost` uses `auth_socket`.** That is why the role never
   has a root password: Ansible is already root, and the socket proves it.
6. **`host: "%"` is a real decision.** It allows the account from any address —
   fine for a lab with a loopback-bound server, too broad for production, where
   the account would be `ivolveuser@10.0.%`.
7. **Encrypted ≠ safe by itself.** A committed ciphertext plus a committed key is
   obfuscation. The value of the vault is that the key can be kept out of the
   repository, which is what `.gitignore` here does.

---

## Reproduce

```bash
cd ~/iVolve-Tasks/Ansible/Lab27
./commands.sh
```

## Clean up

```bash
docker rm -f managed1 managed2
```

## Commit

```bash
git add Ansible/Lab27
git commit -m "feat(lab27): MySQL role with an Ansible Vault password"
```
