#!/usr/bin/env bash
# Lab 26 — the same three installs, one role each.
#
# Fresh nodes again, for the same reason as Lab 25: a role that finds its work
# already done reports changed=0, which proves nothing about the role.
set -euo pipefail

LAB="$HOME/iVolve-Tasks/Ansible/Lab26"
LAB24="$HOME/iVolve-Tasks/Ansible/Lab24"
INV="$LAB24/inventory.ini"
KEY="$HOME/.ssh/ivolve_lab24"
ASKPASS=/tmp/ivolve-askpass.sh

# 1. Fresh managed nodes
docker build -q -f "$LAB24/Dockerfile.node" -t ivolve-node:base "$LAB24" >/dev/null
for spec in managed1:2222 managed2:2223; do
  name=${spec%%:*}; port=${spec##*:}
  docker rm -f "$name" >/dev/null 2>&1 || true
  docker run -d --name "$name" --hostname "$name" -p "$port:22" ivolve-node:base >/dev/null
done
for i in $(seq 1 30); do
  docker exec managed1 pgrep -x sshd >/dev/null 2>&1 \
    && docker exec managed2 pgrep -x sshd >/dev/null 2>&1 && break
  sleep 1
done

# 2. Hand over the Lab 24 key
printf '#!/bin/sh\necho ansible\n' > "$ASKPASS"
chmod +x "$ASKPASS"
for port in 2222 2223; do
  ssh-keygen -R "[127.0.0.1]:$port" >/dev/null 2>&1 || true
  SSH_ASKPASS="$ASKPASS" SSH_ASKPASS_REQUIRE=force setsid -w \
    ssh-copy-id -i "$KEY.pub" -o StrictHostKeyChecking=no -p "$port" ansible@127.0.0.1 >/dev/null
done
ansible -i "$INV" managed -m ping -o

# 3. What a role actually is on disk
echo "== role tree"
find "$LAB" -type f | sed "s|$LAB/||" | sort
echo "== role defaults (the only place versions and URLs live)"
grep -H . "$LAB"/roles/*/defaults/main.yml | sed "s|$LAB/roles/||"

# 4. First run: the roles install everything
ansible-playbook -i "$INV" "$LAB/site.yml"

# 5. Second run: idempotence
ansible-playbook -i "$INV" "$LAB/site.yml" | tail -8

# 6. Verification, straight from the nodes
ansible -i "$INV" managed -b -m shell \
  -a "docker --version; kubectl version --client; dpkg-query -W -f='\${Version}\n' jenkins" -o
