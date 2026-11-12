#!/usr/bin/env bash
# Lab 27 — a MySQL role driven by Ansible Vault.
#
# Both managed nodes are rebuilt from the Lab 24 image first: a role that finds
# its work already done reports changed=0 and proves nothing.
set -euo pipefail

LAB="$HOME/iVolve-Tasks/Ansible/Lab27"
LAB24="$HOME/iVolve-Tasks/Ansible/Lab24"
INV="$LAB24/inventory.ini"
KEY="$HOME/.ssh/ivolve_lab24"
ASKPASS=/tmp/ivolve-askpass.sh
VAULT_PASS="$LAB/.vault-pass"
VP=(--vault-password-file "$VAULT_PASS")

# 0. The committed vault file is ciphertext; the throwaway key that opens it is
#    generated here and stays out of git (see .gitignore in this folder).
#    It has to exist before ANY ansible command: group_vars/ applies to ad-hoc
#    runs as well, and an ad-hoc `ping` without the key fails with
#    "Attempting to decrypt but no vault secrets found".
printf 'ivolve-lab27\n' > "$VAULT_PASS"
chmod 600 "$VAULT_PASS"

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
ansible -i "$INV" managed -m ping -o "${VP[@]}"

# 3. What the vault looks like on disk, and what it contains once opened
echo "== vault file as stored in git"
head -2 "$LAB/group_vars/managed/vault.yml"
echo "== decrypted (values redacted)"
ansible-vault view "${VP[@]}" "$LAB/group_vars/managed/vault.yml" | sed 's/: .*/: <redacted>/'

# 4. First run: install, create the database and the account
ansible-playbook -i "$INV" "$LAB/site.yml" "${VP[@]}"

# 5. Second run: idempotence
ansible-playbook -i "$INV" "$LAB/site.yml" "${VP[@]}" | tail -8

# 6. Independent verification, straight from the nodes, without the vault:
#    as root over the socket, show the databases and the account.
ansible -i "$INV" managed -b -m shell "${VP[@]}" \
  -a "mysql -N -e 'SHOW DATABASES; SELECT user, host FROM mysql.user WHERE user = \"ivolveuser\";'" -o
