# Lab 28 — Automated host discovery with Ansible dynamic inventory

> **Deck task:** create an AWS EC2 instance tagged `server:ivolve`, set up a
> dynamic inventory that discovers running EC2 instances with that tag, list the
> hosts with the `ansible-inventory` command, run a playbook on the instance and
> verify the configuration.

## Requirements

- [ ] EC2 instance tagged `server:ivolve` — **not possible here** (no AWS
      account or credential). See "The honest gap" below.
- [x] A dynamic-inventory configuration that discovers hosts by tag
      (`inventory.aws_ec2.yml`, ready to use)
- [x] `ansible-inventory` listing the discovered hosts
- [x] A playbook run against a **dynamically discovered** group
- [x] Verification on the discovered hosts
- [x] A second run that changes nothing

## Layout

```
Lab28/
├── inventory.aws_ec2.yml   # what the deck asks for: EC2 instances tagged server=ivolve
├── inventory.docker.yml    # the same mechanism against the Docker daemon (runs here)
├── verify.yml              # the playbook: no hostname, port or key inside
└── commands.sh
```

---

## The EC2 inventory the deck asks for

```yaml
plugin: amazon.aws.aws_ec2

regions:
  - us-east-1

filters:
  tag:server: ivolve
  instance-state-name: running

keyed_groups:
  - key: tags.server
    prefix: tag
    separator: "_"
  - key: placement.region
    prefix: region

hostnames:
  - tag:Name
  - instance-id

compose:
  ansible_host: public_ip_address
```

Four things matter in that file:

- **The filename is part of the configuration.** Every inventory plugin
  registers a suffix, and `aws_ec2` only accepts files whose name ends with
  `aws_ec2.yml` / `aws_ec2.yaml`. Rename it `ec2.yml` and Ansible silently tries
  the YAML inventory parser instead, then reports the file as unparsable.
- **`filters` is the tag selection.** `tag:server: ivolve` keeps only the
  instances carrying the deck's tag; the state filter keeps stopped ones out of
  a play that would otherwise wait for an IP that is not there.
- **`keyed_groups` turns the tag into a group.** `tag_server_ivolve` is the
  group a play can target without knowing a single instance id — that is the
  whole point of a dynamic inventory.
- **`compose` decides what "the host" is.** By default the plugin hands Ansible
  the private IP of a VPC instance, which is not reachable from outside; mapping
  `ansible_host` to `public_ip_address` is the fix, and forgetting it is the
  most common "inventory found my instance but SSH times out" cause.

Also required, and not installed by `ansible-core`:

```
$ ansible-galaxy collection list | grep amazon.aws
amazon.aws   7.2.0
```

and `boto3`/`botocore` on the **control node** — the plugin is a Python client
of the EC2 API:

```
$ python3 -c 'import boto3; print(boto3.__version__)'
1.44.2
```

## The honest gap

This environment has no AWS account, so there is nothing to tag and no API to
ask. The lookup fails at the first call, and the failure is recorded rather than
replaced with invented output:

```
$ ansible-inventory -i inventory.aws_ec2.yml --graph
Tasks/Ansible/Lab28/inventory.aws_ec2.yml with auto plugin: Failed to describe
instances: Unable to locate credentials
```

What *is* proven below is the mechanism itself: a plugin queries a live API for
hosts that no file lists, builds groups from the response, and a play runs
against the result. The Docker daemon on this host plays the part of EC2,
because it is the one API here that really returns hosts.

## The same mechanism, with hosts that exist

```yaml
plugin: community.docker.docker_containers
docker_host: unix:///var/run/docker.sock
add_legacy_groups: false

groups:
  managed: inventory_hostname.startswith('managed')

compose:
  ansible_connection: community.docker.docker
  ansible_python_interpreter: /usr/bin/python3
```

- `groups:` is the tag filter's equivalent: whatever the daemon returns, only
  the `managed*` containers join the `managed` group. That matters on this host,
  which also runs the three kind nodes, the registry and another project's
  `aiops-*` containers — a play run against "everything the daemon knows" would
  have touched all of them.
- `ansible_connection: community.docker.docker` replaces SSH entirely: the
  container is the transport, so no port and no key has to appear anywhere.

## The playbook

```yaml
- name: Verify the discovered hosts
  hosts: "{{ lab28_group | default('managed') }}"
```

That one line is the point of the lab: the target set is not written down, it is
whatever the inventory discovered. The tasks print the facts that prove the run
landed on a real host (distribution, kernel, python, memory, group membership)
and write `/etc/ivolve-lab28.txt` as evidence that survives the play.

---

## Result

The daemon knows about more containers than this lab may touch, and `--graph`
shows the split — everything else stays outside the group:

```
  |  |--jenkins
  |  |--aiops-platform-api-1
  |  |--aiops-platform-postgres-1
  |  |--aiops-platform-redis-1
  |  |--aiops-platform-mesh-1
  |  |--aiops-db
  |  |--aiops-control-plane
  |--@managed:
  |  |--managed2
  |  |--managed1
```

What the plugin built for one discovered host:

```
$ ansible-inventory -i inventory.docker.yml --host managed1
{
    "ansible_connection": "community.docker.docker_api",
    "ansible_docker_api_version": "auto",
    "ansible_docker_docker_host": "unix:///var/run/docker.sock",
    "ansible_docker_timeout": 60,
    "ansible_docker_tls": false,
    "ansible_docker_use_ssh_client": false,
    "ansible_docker_validate_certs": false,
    "ansible_host": "managed1",
    "docker_name": "managed1",
    "docker_short_id": "77cca05fbe36f"
}
```

`ansible_connection` there is `community.docker.docker_api`, not the
`community.docker.docker` a `compose:` entry asked for: the plugin's
`connection_type` option wins, and it has to — that is how the host becomes
reachable without an address. (The compose line was removed after this output
showed it was being overridden.)

First run, against the discovered group (`changed=1`: the marker file):

```
PLAY RECAP *********************************************************************
managed1                   : ok=5    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
managed2                   : ok=5    changed=1    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Second run, nothing left to do:

```
managed1                   : ok=5    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
managed2                   : ok=5    changed=0    unreachable=0    failed=0    skipped=0    rescued=0    ignored=0
```

Verification, read back from the hosts themselves:

```
managed1 | CHANGED | rc=0 | (stdout) written by Lab 28\nhost=managed1\nos=Ubuntu 24.04\npython=3.12.3
managed2 | CHANGED | rc=0 | (stdout) written by Lab 28\nhost=managed2\nos=Ubuntu 24.04\npython=3.12.3
```

---

## Things worth knowing

1. **The filename selects the plugin.** `*.aws_ec2.yml`, `*.docker.yml`,
   `*.gcp.yml` — a plugin that does not match its suffix pattern never even
   runs, and the error you get (`not YAML inventory`) points at the file, not at
   the cause.
2. **`ansible-inventory --graph` is the debugging tool.** It shows the groups
   the plugin built *before* any play runs; when a play "does nothing", this is
   the first command to run.
3. **`compose: ansible_host` is not optional in a cloud.** Private IPs are the
   default and are usually unreachable from the control node.
4. **`groups:`/`filters:` differ per plugin.** The docker plugin's `filters`
   takes Jinja `include`/`exclude` conditions (not Docker API filters), which is
   why the tag-equivalent here is the `groups:` expression.
5. **A dynamic inventory on a shared host is a foot-gun.** Without a name or tag
   condition it returns every container, including other people's; the group
   expression is what keeps the play scoped.
6. **Credentials never go in the inventory file.** `aws_ec2` reads
   `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`, `~/.aws/credentials` or
   `profile:` — the file only says *what* to look for.
7. **A second run must change nothing.** The marker file is rewritten only when
   its content differs, which is what makes `changed=0` on run 2 meaningful.

---

## Reproduce

```bash
cd ~/iVolve-Tasks/Ansible/Lab28
./commands.sh
```

With AWS credentials and a tagged instance, the same play runs with:

```bash
ansible-inventory -i inventory.aws_ec2.yml --graph
ansible-playbook -i inventory.aws_ec2.yml verify.yml -e lab28_group=tag_server_ivolve
```

## Commit

```bash
git add Ansible/Lab28
git commit -m "feat(lab28): dynamic inventory, EC2 config and a real discovery run"
```
