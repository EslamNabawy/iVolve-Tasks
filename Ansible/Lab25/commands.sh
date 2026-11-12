#!/usr/bin/env bash
# Lab 25 — Docker, kubectl and Jenkins from one playbook.
#
# The two managed nodes are rebuilt from scratch first. That matters: a playbook
# run against nodes that were already provisioned reports changed=0 and proves
# nothing. Here the first run installs, and the second run is the idempotence
# check.
set -euo pipefail

LAB="$HOME/iVolve-Tasks/Ansible/Lab25"
LAB24="$HOME/iVolve-Tasks/Ansible/Lab24"
INV="$LAB24/inventory.ini"
KEY="$HOME/.ssh/ivolve_lab24"
ASKPASS=/tmp/ivolve-askpass.sh

# 1. Fresh managed nodes (Lab 24's image and credentials, empty filesystem)
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

# 2. Fresh containers have no authorized_keys: hand the Lab 24 key over again
printf '#!/bin/sh\necho ansible\n' > "$ASKPASS"
chmod +x "$ASKPASS"
for port in 2222 2223; do
  ssh-keygen -R "[127.0.0.1]:$port" >/dev/null 2>&1 || true
  SSH_ASKPASS="$ASKPASS" SSH_ASKPASS_REQUIRE=force setsid -w \
    ssh-copy-id -i "$KEY.pub" -o StrictHostKeyChecking=no -p "$port" ansible@127.0.0.1 >/dev/null
done
ansible -i "$INV" managed -m ping -o

# 3. The playbook: install everything
ansible-playbook -i "$INV" "$LAB/playbook.yml"

# 4. Read the three versions back from every managed node
ansible -i "$INV" managed -b -m shell \
  -a "docker --version; kubectl version --client; dpkg-query -W -f='\${Version}\n' jenkins" -o

# 5. A second run must change nothing
ansible-playbook -i "$INV" "$LAB/playbook.yml" | tail -8
