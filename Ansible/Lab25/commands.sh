#!/usr/bin/env bash
# Lab 25 — one playbook, three installs, verified on both managed nodes.
set -euo pipefail

LAB="$HOME/iVolve-Tasks/Ansible/Lab25"
INV="$HOME/iVolve-Tasks/Ansible/Lab24/inventory.ini"

# Managed nodes are shared with Lab 24; recreate them if they are gone.
docker build -q -f "$HOME/iVolve-Tasks/Ansible/Lab24/Dockerfile.node" \
  -t ivolve-node:base "$HOME/iVolve-Tasks/Ansible/Lab24" >/dev/null
for spec in managed1:2222 managed2:2223; do
  name=${spec%%:*}; port=${spec##*:}
  docker ps --format '{{.Names}}' | grep -qx "$name" \
    || docker run -d --name "$name" --hostname "$name" -p "$port:22" ivolve-node:base >/dev/null
done
ansible -i "$INV" managed -m ping -o

# The playbook
ansible-playbook -i "$INV" "$LAB/playbook.yml"

# Verification, from the control node, on every managed node
for cmd in "docker --version" "kubectl version --client" "dpkg-query -W -f='\${Version}' jenkins"; do
  echo "== $cmd"
  ansible -i "$INV" managed -b -m shell -a "$cmd" -o
done

# Idempotence: the second run must not change anything
ansible-playbook -i "$INV" "$LAB/playbook.yml" | grep -E 'changed=' | tail -2
