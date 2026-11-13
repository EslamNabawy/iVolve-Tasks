# Lab 24: Ansible control node, keys, inventory and an ad-hoc command

> **Deck task:** install and configure Ansible on the control node, generate a
> key, copy the public key to the managed node with `ssh-copy-id`, create an
> inventory that lists the managed node, then run an ad-hoc command that
> installs Docker on it.

## What the lab asks for

- [x] Ansible installed and configured on the control node
- [x] A dedicated key pair, generated for this lab
- [x] The public key installed on the managed node(s) with `ssh-copy-id`
- [x] An inventory listing the managed node(s)
- [x] An ad-hoc command that installs Docker, run through Ansible
- [x] The result verified on the managed node

---

## 1. What is the control node here

The control node is this WSL machine, nothing is installed specially:

```
ansible [core 2.16.3]
  config file = None
```

`config file = None` is normal: Ansible works without an `ansible.cfg`, and the
inventory path is passed with `-i`.

## 2. The managed node

The deck assumes a second machine reachable over SSH. This host has no
passwordless `sudo`, so it cannot run a second `sshd` of its own, a managed node
is therefore a **container with `sshd` in the foreground**, built by
`Dockerfile.node`:

- Ubuntu 24.04, `openssh-server`, `python3`, `python3-apt`, `sudo`
- a user `ansible` / `ansible` with `NOPASSWD:ALL` in `/etc/sudoers.d/ansible`
- password authentication enabled **only** so `ssh-copy-id` can log in once

Two of them, on different host ports:

```
managed2 0.0.0.0:2223->22/tcp, [::]:2223->22/tcp
managed1 0.0.0.0:2222->22/tcp, [::]:2222->22/tcp
```

Two nodes rather than one, because an inventory of a single host hides
mistakes, `hosts: all` and `hosts: managed` behave identically with one entry.

## 3. The key

A dedicated key, not the user's default:

```
Generating public/private ed25519 key pair.
Your identification has been saved in /home/eslam/.ssh/ivolve_lab24
Your public key has been saved in /home/eslam/.ssh/ivolve_lab24.pub
The key fingerprint is:
SHA256:aXmW7iC1rLf+sD+DhVBPqHLMF9Fb+JG+pxLyO6oXwSk ivolve-ansible-lab
-rw------- 1 eslam eslam 411 Nov 12 03:49 /home/eslam/.ssh/ivolve_lab24
-rw-r--r-- 1 eslam eslam 100 Nov 12 03:49 /home/eslam/.ssh/ivolve_lab24.pub
```

## 4. `ssh-copy-id` without typing a password

`ssh-copy-id` insists on reading the password from a terminal, and `sshpass` is
not installed here. `SSH_ASKPASS` with `SSH_ASKPASS_REQUIRE=force` makes it read
the password from a script instead, and `setsid` detaches it from the terminal
that would otherwise take precedence:

```bash
printf '#!/bin/sh\necho ansible\n' > /tmp/lab24-askpass.sh
chmod +x /tmp/lab24-askpass.sh
SSH_ASKPASS=/tmp/lab24-askpass.sh SSH_ASKPASS_REQUIRE=force setsid -w \
  ssh-copy-id -i ~/.ssh/ivolve_lab24.pub -o StrictHostKeyChecking=no \
  -p 2222 ansible@127.0.0.1
```

```
/usr/bin/ssh-copy-id: INFO: attempting to log in with the new key(s), to filter out any that are already installed
/usr/bin/ssh-copy-id: INFO: 1 key(s) remain to be installed -- if you are prompted now it is to install the new keys
Number of key(s) added: 1
```

Twice, once per port.

## 5. The inventory

`inventory.ini`:

```ini
[managed]
managed1 ansible_host=127.0.0.1 ansible_port=2222 ansible_user=ansible
managed2 ansible_host=127.0.0.1 ansible_port=2223 ansible_user=ansible

[managed:vars]
ansible_ssh_private_key_file=/home/eslam/.ssh/ivolve_lab24
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
ansible_python_interpreter=/usr/bin/python3
```

Parsed back by Ansible:

```
@all:
  |--@ungrouped:
  |--@managed:
  |  |--managed1
  |  |--managed2
```

`ansible-inventory --graph` is the cheapest way to catch a typo before a
playbook runs against the wrong hosts.

## 6. Reachability

```bash
ansible -i inventory.ini managed -m ping
```

```
managed2 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
managed1 | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
```

`ping` here is not ICMP. It is a module that connects over SSH, uploads a small
Python program and reports success. "pong" therefore proves the whole chain:
network, key, user, Python.

## 7. The ad-hoc command: install Docker

```bash
ansible -i inventory.ini managed -b -m apt \
  -a "name=docker.io state=present update_cache=yes"
```

`-b` is `become` (sudo). Verified afterwards:

```
managed1 | CHANGED | rc=0 | (stdout) Docker version 29.1.3, build 29.1.3-0ubuntu3~24.04.2
managed2 | CHANGED | rc=0 | (stdout) Docker version 29.1.3, build 29.1.3-0ubuntu3~24.04.2
```

---

## Notes from this one

1. **`ansible ping` says nothing about ICMP.** It is a module executed over
   SSH with Python; a green `ping` means SSH, key auth, Python and sudo all work.
2. **`-b` is not automatic.** Every task that changes system state needs
   `become`, either on the command line or `become: true` in the playbook.
3. **`ssh-copy-id` prefers a terminal over `SSH_ASKPASS`.** Without
   `SSH_ASKPASS_REQUIRE=force` plus `setsid -w` it ignores the askpass script and
   waits for input that never comes.
4. **Ansible needs Python on the managed node,** not just SSH. A minimal image
   without `python3` fails with `MODULE FAILURE` before anything runs.
5. **`docker.io` is the distro package.** It installs a working Docker 29.1.3
   but inside these containers there is no systemd, so the daemon is not started
, the lab installs and reports the version, and says so rather than pretending
   a daemon is running.
6. **The inventory points at `127.0.0.1`, not at host names.** Only the port
   differs between the two nodes; that is the one visible difference from two
   cloud VMs.

## Reproduce

```bash
cd ~/iVolve-Tasks/Ansible/Lab24
./commands.sh
```

The nodes are left running for Labs 25–27 (`docker rm -f managed1 managed2` to
remove them).

## Commit

```bash
git add Ansible/Lab24
git commit -m "feat(lab24): Ansible control node, keys, inventory and ad-hoc Docker install"
```
