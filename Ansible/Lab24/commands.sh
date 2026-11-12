#!/usr/bin/env bash
# Lab 24 — Ansible control node → key → ssh-copy-id → inventory → ad-hoc run.
set -euo pipefail

LAB="$HOME/iVolve-Tasks/Ansible/Lab24"
KEY="$HOME/.ssh/ivolve_lab24"
ASKPASS=/tmp/lab24-askpass.sh

# 1. The control node already is this machine (WSL Ubuntu 24.04)
ansible --version | head -2

# 2. Managed nodes: two containers, sshd in the foreground, ports 2222/2223
docker build -t ivolve-node:base -f "$LAB/Dockerfile.node" "$LAB"
for spec in managed1:2222 managed2:2223; do
  name=${spec%%:*}; port=${spec##*:}
  docker rm -f "$name" >/dev/null 2>&1 || true
  docker run -d --name "$name" --hostname "$name" -p "$port:22" ivolve-node:base >/dev/null
done
for i in $(seq 1 30); do
  docker exec managed1 pgrep -x sshd >/dev/null && docker exec managed2 pgrep -x sshd >/dev/null && break
  sleep 1
done
docker ps --filter name=managed --format '{{.Names}} {{.Ports}}'

# 3. A key, generated once and reused by Labs 24-27
[ -f "$KEY" ] || ssh-keygen -t ed25519 -f "$KEY" -N '' -C 'ivolve-ansible-lab'
ls -l "$KEY" "$KEY.pub"

# 4. ssh-copy-id. It reads the password from the terminal, and there is no
#    sshpass on this host, so SSH_ASKPASS + setsid supplies it instead.
printf '#!/bin/sh\necho ansible\n' > "$ASKPASS"; chmod +x "$ASKPASS"
for port in 2222 2223; do
  SSH_ASKPASS="$ASKPASS" SSH_ASKPASS_REQUIRE=force setsid -w \
    ssh-copy-id -i "$KEY.pub" -o StrictHostKeyChecking=no -p "$port" ansible@127.0.0.1
done

# 5. Inventory
cat "$LAB/inventory.ini"
ansible-inventory -i "$LAB/inventory.ini" --graph

# 6. Reachability of every managed node
ansible -i "$LAB/inventory.ini" managed -m ping

# 7. Ad-hoc task: install Docker on both nodes
ansible -i "$LAB/inventory.ini" managed -b -m apt \
  -a "name=docker.io state=present update_cache=yes" | tail -6
ansible -i "$LAB/inventory.ini" managed -b -m command -a "docker --version"
ansible -i "$LAB/inventory.ini" managed -b -m command -a "docker --version" -o | tail -3
