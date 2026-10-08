# DevOps Learning Checklist

Everything covered so far, in the order it was learned.

- `[x]` = done and checked
- `[ ]` = learned the idea, still needs hands-on practice

Change `[ ]` to `[x]` as you complete items. Exact commands are in [README.md](README.md).

---

## 1. Vagrant & VirtualBox

- [x] Understand what Vagrant is: VMs from a `Vagrantfile` (infrastructure as code)
- [x] Basic commands: `vagrant up`, `ssh <name>`, `status`, `halt`, `destroy -f`
- [x] Multi-VM Vagrantfile (several VMs in one file, with names)
- [x] Private network (`private_network`, 192.168.56.x / 192.168.10.x)
- [x] Set RAM and CPU per VM (`vb.memory`, `vb.cpus`)
- [x] Mix OS boxes (CentOS Stream 9 + Ubuntu in one file)
- [x] `vagrant ssh` needs a VM name in multi-VM setups
- [x] `vagrant reload <name>` fixes a VM whose network didn't come up
- [x] Provisioning runs only on first boot (`vagrant provision` re-runs it)
- [ ] Automated provisioning: test `provision/*.sh` with `destroy` + `up`
- [x] `/vagrant` synced folder (rsync = one-time copy; `vagrant rsync` to update)
- [x] Run `vagrant` commands from **PowerShell**, not inside VMs or WSL
- [x] Know where Vagrant fits: a local practice lab; the concepts carry over to Terraform

## 2. Linux essentials

- [x] Read the prompt: `PS C:\...>` = Windows, `[root@db01 ~]#` = inside VM as root
- [x] `$` in tutorials = normal user, `#` = root (`sudo -i`)
- [x] Package managers: `dnf`/`yum` (CentOS) vs `apt` (Ubuntu)
- [x] EPEL repository: what it is and why (`dnf install epel-release`)
- [x] Where installed files go: `dnf`/`apt` = system folders; manual = `/tmp` then `/usr/local` or `/opt`
- [x] `cp -r` for folders (`-d` is for symlinks, not directories)
- [x] `rsync -a` = exact copy (permissions, owners, times); trailing `/` = copy the contents
- [x] `folder/*` copies the contents, not the folder itself
- [x] `/tmp` (not `/temp`) for temporary work
- [ ] Edit files with `vi` (`i`, paste, `Esc`, `:wq`) without looking it up
- [ ] systemd: `start`, `stop`, `restart`, `enable`, `status`, `daemon-reload`
- [ ] Write a custom `.service` file (e.g. `tomcat.service`)
- [ ] Logs: `journalctl -u <svc>`, `tail -f /var/log/...`
- [ ] Reset a forgotten WSL password (`wsl -u root` then `passwd <user>`)

## 3. Networking & security

- [x] How VMs talk: same private network + hostnames in `/etc/hosts` + app config
- [x] Service must listen on `0.0.0.0`, not `127.0.0.1`, to accept other VMs
- [x] Firewall concept: allow or block by port and source IP
- [ ] firewalld: `firewall-cmd --permanent --add-port=<port>/tcp` + `--reload`
- [ ] ufw on Ubuntu: `ufw allow 80/tcp`
- [ ] Check ports: `ss -tlnp`, `nc -zv host port`
- [ ] nmap: `nmap host`, `nmap -p 3306 db01`, `nmap -sn 192.168.56.0/24` (only on your own machines)
- [x] Ports: 22 SSH, 80 HTTP, 8080 Tomcat, 3306 MySQL, 5672 RabbitMQ, 11211 Memcache

## 4. SSH between servers

- [x] Concept: log in from one VM to another with `ssh user@ip` (not `vagrant ssh`)
- [x] Key-based login: `ssh-keygen` on the controller, `ssh-copy-id` the **public** key to servers
- [x] Private key stays secret (permissions `600`); public key goes to `authorized_keys`
- [ ] Enable `PasswordAuthentication yes` in `/etc/ssh/sshd_config` (+ `sshd_config.d/`)
- [ ] Set up keys from scriptbox to web01–web03
- [ ] Run remote commands: `ssh devops@web01 "uptime"`

## 5. vProfile project (multi-tier app)

- [x] Architecture: Nginx → Tomcat → Memcache / RabbitMQ / MySQL
- [x] Setup order: db → mc → rmq → app → web
- [x] Every service follows 5 steps: install, configure, start, enable, open port
- [x] `application.properties` holds hostnames and passwords the app uses
- [x] **db01**: MariaDB installed, running, `accounts` DB + `admin` user created
- [ ] **db01**: load `db_backup.sql` (tables were missing)
- [x] **mc01**: Memcached installed, listening on `0.0.0.0:11211`, tested from app01
- [ ] **rmq01**: RabbitMQ + user `test`
- [ ] **app01**: Java 17 → Tomcat tar → `/usr/local/tomcat` → `tomcat` user → service file → start
- [ ] **app01**: Maven build → `vprofile-v2.war` → deploy as `ROOT.war`
- [ ] **web01**: Nginx config in `sites-available/vproapp`, linked into `sites-enabled`
- [ ] Log in to the app at http://192.168.56.11 (`admin_vp` / `admin_vp`)
- [x] Understand: change config → rebuild → redeploy (what CI/CD automates)

## 6. Bash scripting

- [x] Write and run a script (`#!/bin/bash`, `chmod +x`, `./script.sh`)
- [x] Website setup script: httpd + download template + copy to `/var/www/html`
- [x] Debug a script from its output (found the `/temp` typo)
- [x] Bash keeps running after errors; add `set -e` to stop
- [ ] Fix `websitesetup.sh` (`/tmp/webfiles`, `mkdir -p`) and clean `/opt/scripts`
- [ ] Variables, arguments, if, loops, functions (see the Bash checklist in README.md)
- [ ] Multi-server script from scriptbox to web01–web03

## 7. Data formats

- [x] JSON: syntax, quotes required, no comments, no trailing commas
- [x] YAML: indentation with spaces (never tabs), `key: value`, `-` for lists, comments allowed
- [x] When to use which: people write config = YAML, programs exchange data = JSON
- [ ] Use `jq` on real JSON (e.g. AWS CLI output)
- [ ] Validate YAML with `yamllint` or the VS Code YAML extension

## 8. Containers (Docker Compose)

- [x] Read a `docker-compose.yml`: services, image, ports `HOST:CONTAINER`, volumes, environment
- [x] Service name = hostname inside the Compose network
- [x] Volumes keep data when containers are removed
- [x] Containers vs VMs: faster and lighter, but images still need the same Linux knowledge
- [ ] Run vprofile with `docker compose up -d` and open it in the browser
- [ ] Write your own Dockerfile (e.g. Tomcat + `ROOT.war`)

## 9. Cloud (AWS EC2)

- [x] EC2 = VMs in AWS; AMI = box, instance type = size, user data = provisioning
- [x] Instance families: t (cheap), m (balanced), c (CPU), r (memory), g/p (GPU)
- [x] EBS storage, security groups, key pairs, Elastic IP, Auto Scaling, load balancers
- [x] Pricing: On-Demand, Spot, Reserved / Savings Plans
- [ ] Set up an AWS Budget alert before launching anything
- [ ] Launch an EC2 instance and SSH in with a `.pem` key

## 10. Career & projects

- [x] Learning order: Linux → Git → Bash → Networking → Docker → CI/CD → AWS → Terraform → Ansible → Kubernetes → Monitoring
- [x] Built AI/ML projects: document Q&A (RAG), job-application assistant
- [x] Picked the next project idea: AI support-ticket system (microservices + AWS)
- [x] Course plan: finish it in order, redo sections without video, push work to GitHub
- [ ] Add what the course skips: GitHub Actions, ArgoCD, Prometheus/Grafana
- [ ] First certification target: AWS Solutions Architect Associate

---

## Next up

1. Fix `websitesetup.sh` and add `set -e`
2. SSH keys from scriptbox to web01–web03
3. Multi-server Bash script (deploy the website to all 3)
4. Finish the vProfile setup (manual or automated) and log in to the app
