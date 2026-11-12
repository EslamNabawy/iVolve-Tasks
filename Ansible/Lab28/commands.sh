#!/usr/bin/env bash
# Lab 28 — dynamic inventory.
#
# The deck asks for an EC2 instance tagged `server:ivolve`. This environment has
# no AWS account and no credentials, so the aws_ec2 lookup cannot return hosts
# (part 3 records the real error instead of hiding it). Parts 4-6 run the same
# dynamic-inventory mechanism against the Docker daemon, which does have hosts.
set -uo pipefail

LAB="$HOME/iVolve-Tasks/Ansible/Lab28"
DINV="$LAB/inventory.docker.yml"
AINV="$LAB/inventory.aws_ec2.yml"

echo "== 1. the plugins this lab needs"
ansible-galaxy collection list 2>/dev/null | grep -E 'amazon.aws|community.docker'
ansible-doc -t inventory amazon.aws.aws_ec2 2>/dev/null | head -4

echo "== 2. the EC2 inventory file (what the deck asks for)"
cat "$AINV"

echo "== 3. aws_ec2 lookup — no credentials in this environment, so:"
ansible-inventory -i "$AINV" --graph 2>&1 | grep -iE 'unable to locate credentials|failed to describe' || true

echo "== 4. docker_containers lookup — the same mechanism, real hosts"
ansible-inventory -i "$DINV" --graph

echo "== 5. what the plugin discovered about one of them"
ansible-inventory -i "$DINV" --host managed1 | head -20

echo "== 6. start from a known state: remove the marker the play writes, so run 1
     really changes something and run 2 proves idempotence"
ansible -i "$DINV" managed -m ansible.builtin.file \
  -a "path=/etc/ivolve-lab28.txt state=absent" >/dev/null

echo "== 7. playbook, run on the discovered group"
ansible-playbook -i "$DINV" "$LAB/verify.yml" -e lab28_group=managed

echo "== 8. second run (nothing left to change)"
ansible-playbook -i "$DINV" "$LAB/verify.yml" -e lab28_group=managed | tail -8

echo "== 9. verification, straight from the hosts"
ansible -i "$DINV" managed -m shell -a "cat /etc/ivolve-lab28.txt" -o
