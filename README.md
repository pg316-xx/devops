# DevOps Notes: Linux, JSON & YAML

A quick reference for everyday DevOps work. Practice these commands on the lab VMs (`vagrant ssh web01`).

## Contents

- [Linux](#linux)
  - [Navigation & files](#1-navigation--files)
  - [Viewing files](#2-viewing-files)
  - [Searching & text processing](#3-searching--text-processing)
  - [Permissions & ownership](#4-permissions--ownership)
  - [Users & groups](#5-users--groups)
  - [Processes](#6-processes)
  - [Services (systemd)](#7-services-systemd)
  - [Logs](#8-logs)
  - [Disk & memory](#9-disk--memory)
  - [Networking](#10-networking)
  - [SSH & file transfer](#11-ssh--file-transfer)
  - [Packages](#12-packages)
  - [Archives](#13-archives)
  - [Environment variables](#14-environment-variables)
  - [Cron (scheduled jobs)](#15-cron-scheduled-jobs)
  - [Redirection & pipes](#16-redirection--pipes)
  - [Bash scripting basics](#17-bash-scripting-basics)
  - [Important files & directories](#18-important-files--directories)
  - [Troubleshooting checklist](#19-troubleshooting-checklist)
- [Bash scripting checklist](#bash-scripting-checklist)
- [JSON](#json)
- [YAML](#yaml)
- [JSON vs YAML](#json-vs-yaml)
- [Vagrant lab commands](#vagrant-lab-commands)

---

# Linux

## 1. Navigation & files

```bash
pwd                      # where am I?
ls -la                   # list all files (incl. hidden) with details
ls -lh                   # human-readable sizes
cd /var/log              # go to a directory
cd ~                     # home directory
cd -                     # previous directory

mkdir -p app/src/utils   # create nested directories
touch file.txt           # create empty file / update timestamp
cp file.txt backup.txt   # copy file
cp -r dir1 dir2          # copy directory
mv old.txt new.txt       # move / rename
rm file.txt              # delete file
rm -rf dir/              # delete directory (careful! no undo)
ln -s /path/target link  # symbolic link

find / -name "nginx.conf" 2>/dev/null      # find file by name
find . -type f -size +100M                 # files bigger than 100MB
find /var/log -name "*.log" -mtime +7      # logs older than 7 days
which nginx              # where is a command located
```

## 2. Viewing files

```bash
cat file.txt             # print whole file
less file.txt            # scroll (q = quit, / = search)
head -n 20 file.txt      # first 20 lines
tail -n 50 file.txt      # last 50 lines
tail -f /var/log/syslog  # follow live (great for logs)
wc -l file.txt           # count lines
diff file1 file2         # compare files
```

## 3. Searching & text processing

```bash
grep "error" app.log              # lines containing "error"
grep -i "error" app.log           # case-insensitive
grep -r "TODO" /etc/nginx         # search recursively
grep -v "debug" app.log           # lines NOT matching
grep -n "error" app.log           # show line numbers
grep -c "error" app.log           # count matches
grep -E "error|fail" app.log      # multiple patterns (regex)

awk '{print $1}' access.log                 # print 1st column
awk -F: '{print $1}' /etc/passwd            # custom separator → usernames
sed 's/old/new/g' file.txt                  # replace (print only)
sed -i 's/old/new/g' file.txt               # replace in file
cut -d',' -f2 data.csv                      # 2nd column of CSV
sort file.txt | uniq -c | sort -rn          # count duplicates, most first

# Top 10 IPs hitting nginx
awk '{print $1}' /var/log/nginx/access.log | sort | uniq -c | sort -rn | head
```

## 4. Permissions & ownership

```
-rwxr-xr--  1 vagrant vagrant  script.sh
│└┬┘└┬┘└┬┘
│ │  │  └── others: r--  (read)
│ │  └───── group:  r-x  (read, execute)
│ └──────── owner:  rwx  (read, write, execute)
└────────── type: - file, d directory, l link
```

| Number | Permission | Meaning |
|---|---|---|
| 4 | r | read |
| 2 | w | write |
| 1 | x | execute |

```bash
chmod 755 script.sh      # rwxr-xr-x  (scripts, directories)
chmod 644 file.txt       # rw-r--r--  (normal files)
chmod 600 id_rsa         # rw-------  (private keys, secrets)
chmod +x script.sh       # make executable
chmod -R 755 dir/        # recursive

chown user:group file    # change owner and group
chown -R www-data:www-data /var/www   # recursive

sudo command             # run as root
sudo -i                  # become root
```

## 5. Users & groups

```bash
whoami                   # current user
id                       # user ID, groups
sudo useradd -m -s /bin/bash pavan    # create user with home dir
sudo passwd pavan        # set password
sudo usermod -aG sudo pavan           # add to sudo group (Ubuntu)
sudo usermod -aG docker pavan         # add to docker group
sudo userdel -r pavan    # delete user + home
groups pavan             # show user's groups
cat /etc/passwd          # all users
cat /etc/group           # all groups
```

## 6. Processes

```bash
ps aux                   # all running processes
ps aux | grep nginx      # find a process
top                      # live view (q = quit)
htop                     # nicer live view (apt install htop)
pgrep nginx              # get PID by name
kill 1234                # stop process gracefully (SIGTERM)
kill -9 1234             # force kill (SIGKILL), last resort
pkill nginx              # kill by name
nohup ./app.sh &         # run in background, survives logout
jobs / fg / bg           # manage background jobs
```

## 7. Services (systemd)

```bash
sudo systemctl status nginx      # is it running?
sudo systemctl start nginx
sudo systemctl stop nginx
sudo systemctl restart nginx
sudo systemctl reload nginx      # reload config without downtime
sudo systemctl enable nginx      # start on boot
sudo systemctl disable nginx
sudo systemctl enable --now nginx    # enable + start
systemctl list-units --type=service --state=running
sudo systemctl daemon-reload     # after editing a .service file
```

Example custom service, `/etc/systemd/system/myapp.service`:

```ini
[Unit]
Description=My FastAPI app
After=network.target

[Service]
User=vagrant
WorkingDirectory=/home/vagrant/app
ExecStart=/usr/bin/python3 -m uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always

[Install]
WantedBy=multi-user.target
```

## 8. Logs

```bash
journalctl -u nginx              # logs for a service
journalctl -u nginx -f           # follow live
journalctl -u nginx --since "1 hour ago"
journalctl -p err -b             # errors since last boot
tail -f /var/log/syslog          # system log (Ubuntu)
tail -f /var/log/nginx/error.log
dmesg | tail                     # kernel messages
```

## 9. Disk & memory

```bash
df -h                    # disk space per filesystem
du -sh /var/log          # size of a directory
du -sh * | sort -h       # sizes in current dir, sorted
free -h                  # RAM usage
lsblk                    # disks and partitions
uptime                   # load average
nproc                    # number of CPUs
```

## 10. Networking

```bash
ip a                     # IP addresses (ip -br a = short)
ip route                 # routing table
ping -c 4 google.com     # check connectivity
curl http://localhost    # HTTP request
curl -I https://site.com # headers only
curl -X POST -H "Content-Type: application/json" \
     -d '{"name":"test"}' http://localhost:8000/api
wget https://url/file    # download a file
ss -tulnp                # listening ports + process (replaces netstat)
sudo lsof -i :80         # what's using port 80
nslookup google.com      # DNS lookup
dig google.com           # detailed DNS lookup
traceroute google.com    # network path
nc -zv db01 3306         # test if a port is open
cat /etc/hosts           # local hostname → IP mapping
cat /etc/resolv.conf     # DNS servers

# Firewall (Ubuntu)
sudo ufw status
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw enable
```

**Common ports**

| Port | Service | Port | Service |
|---|---|---|---|
| 22 | SSH | 3306 | MySQL |
| 53 | DNS | 5432 | PostgreSQL |
| 80 | HTTP | 6379 | Redis |
| 443 | HTTPS | 8080 | Jenkins / alt HTTP |
| 25 | SMTP | 9090 | Prometheus |
| 6443 | Kubernetes API | 3000 | Grafana |

## 11. SSH & file transfer

```bash
ssh user@192.168.56.11                     # connect
ssh -i key.pem ubuntu@<aws-ip>             # connect with key (AWS EC2)
ssh-keygen -t ed25519 -C "you@email.com"   # create key pair
ssh-copy-id user@server                    # install your public key on server
scp file.txt user@server:/tmp/             # copy file to server
scp user@server:/var/log/app.log .         # copy file from server
scp -r dir/ user@server:/home/user/        # copy directory
rsync -avz dir/ user@server:/backup/       # efficient sync
```

`~/.ssh/config` lets you use short names (`ssh web01`):

```
Host web01
    HostName 192.168.56.11
    User vagrant
    IdentityFile ~/.ssh/id_ed25519
```

## 12. Packages

```bash
# Ubuntu / Debian (apt)
sudo apt update                  # refresh package list
sudo apt upgrade -y              # upgrade everything
sudo apt install -y nginx git    # install
sudo apt remove nginx            # remove
apt search redis                 # search
apt list --installed

# RHEL / CentOS / Amazon Linux (dnf / yum)
sudo dnf install -y nginx
sudo yum install -y nginx
```

## 13. Archives

```bash
tar -czvf backup.tar.gz dir/     # create compressed archive
tar -xzvf backup.tar.gz          # extract
tar -tzvf backup.tar.gz          # list contents
zip -r backup.zip dir/
unzip backup.zip
```

Mnemonic: **c**reate / e**x**tract, **z** = gzip, **v** = verbose, **f** = file.

## 14. Environment variables

```bash
echo $HOME               # print a variable
env                      # all variables
export APP_ENV=prod      # set for this session
echo 'export APP_ENV=prod' >> ~/.bashrc   # make permanent
source ~/.bashrc         # reload
echo $PATH               # where commands are searched
export PATH=$PATH:/opt/mytool/bin
```

## 15. Cron (scheduled jobs)

```bash
crontab -e               # edit your jobs
crontab -l               # list your jobs
```

```
┌───── minute (0-59)
│ ┌─── hour (0-23)
│ │ ┌─ day of month (1-31)
│ │ │ ┌ month (1-12)
│ │ │ │ ┌ day of week (0-6, Sun=0)
│ │ │ │ │
* * * * *  command

0 2 * * *     /home/vagrant/backup.sh      # every day at 2 AM
*/5 * * * *   /home/vagrant/health.sh      # every 5 minutes
0 9 * * 1     /home/vagrant/report.sh      # every Monday 9 AM
```

Use [crontab.guru](https://crontab.guru) to check cron expressions.

## 16. Redirection & pipes

```bash
cmd > out.txt            # write output (overwrite)
cmd >> out.txt           # append
cmd 2> err.txt           # errors only
cmd > all.txt 2>&1       # output + errors
cmd > /dev/null 2>&1     # discard everything
cmd1 | cmd2              # pipe output into next command
cmd1 && cmd2             # run cmd2 only if cmd1 succeeds
cmd1 || cmd2             # run cmd2 only if cmd1 fails
cmd | tee out.txt        # show on screen AND save
```

## 17. Bash scripting basics

```bash
#!/bin/bash
set -euo pipefail        # stop on errors, unset vars, pipe failures

NAME="web01"             # variable (no spaces around =)
echo "Server: $NAME"
TODAY=$(date +%F)        # command output into variable

# Arguments
echo "First arg: $1, all args: $@, count: $#"

# If
if [ -f /etc/nginx/nginx.conf ]; then
    echo "nginx config exists"
elif [ -d /etc/nginx ]; then
    echo "dir exists, no config"
else
    echo "nginx not installed"
fi

# Loop over list
for server in web01 web02 db01; do
    ping -c 1 "$server" > /dev/null && echo "$server UP" || echo "$server DOWN"
done

# Function
check_service() {
    if systemctl is-active --quiet "$1"; then
        echo "$1 is running"
    else
        echo "$1 is DOWN, restarting"
        sudo systemctl restart "$1"
    fi
}
check_service nginx

# Exit code of last command: 0 = success
echo $?
```

| Test | Meaning |
|---|---|
| `-f file` | file exists |
| `-d dir` | directory exists |
| `-z "$var"` | string is empty |
| `"$a" == "$b"` | strings equal |
| `$a -eq $b` | numbers equal (`-ne -gt -lt -ge -le`) |

## 18. Important files & directories

| Path | What's there |
|---|---|
| `/etc` | System configuration |
| `/etc/hosts` | Local hostname → IP mapping |
| `/etc/passwd`, `/etc/group` | Users and groups |
| `/etc/ssh/sshd_config` | SSH server config |
| `/etc/nginx/` | Nginx config |
| `/etc/systemd/system/` | Custom service files |
| `/var/log` | Logs |
| `/var/www` | Web files |
| `/home/<user>` | User home directories |
| `/root` | Root user's home |
| `/tmp` | Temporary files (cleared on reboot) |
| `/opt` | Optional / third-party software |
| `/usr/bin`, `/usr/local/bin` | Programs |
| `/proc` | Live system info (`/proc/cpuinfo`, `/proc/meminfo`) |

## 19. Troubleshooting checklist

When "the app is down":

1. **Is the service running?** `systemctl status <svc>`
2. **What do the logs say?** `journalctl -u <svc> -n 50` / `tail /var/log/...`
3. **Is it listening on the port?** `ss -tulnp | grep <port>`
4. **Can I reach it locally?** `curl localhost:<port>`
5. **Firewall?** `sudo ufw status` (on AWS: Security Groups)
6. **Network / DNS?** `ping`, `nc -zv host port`, `nslookup`
7. **Disk full?** `df -h`
8. **Out of memory / CPU?** `free -h`, `top`
9. **Permissions?** `ls -la`, check the owner and user

---

# Bash scripting checklist

Tick each item when you can write it **without looking**.

## Level 1: basics

- [ ] **Shebang + run a script**
  ```bash
  #!/bin/bash
  chmod +x script.sh && ./script.sh
  ```
- [ ] **Comments:** `# this is a comment`
- [ ] **Variables** (no spaces around `=`)
  ```bash
  NAME="web01"; echo "Server: $NAME"
  ```
- [ ] **Command output into a variable**
  ```bash
  TODAY=$(date +%F); FREE_RAM=$(free -m | awk '/Mem/{print $4}')
  ```
- [ ] **Quoting:** `"$VAR"` expands, `'$VAR'` is literal. Always quote variables.
- [ ] **User input:** `read -p "Enter name: " NAME`
- [ ] **Script arguments:** `$0` script name, `$1 $2` args, `$#` count, `$@` all args
- [ ] **Exit codes:** `$?` (0 = success), `exit 1` to fail

## Level 2: logic

- [ ] **If / elif / else**
  ```bash
  if [ -f /etc/httpd/conf/httpd.conf ]; then
      echo "httpd installed"
  else
      echo "not installed"
  fi
  ```
- [ ] **Test conditions**

  | Files | Strings | Numbers |
  |---|---|---|
  | `-f` file exists | `"$a" == "$b"` | `-eq` equal |
  | `-d` dir exists | `-z "$a"` empty | `-ne` not equal |
  | `-x` executable | `-n "$a"` not empty | `-gt` `-lt` `-ge` `-le` |

- [ ] **AND / OR:** `cmd1 && cmd2` (run cmd2 if cmd1 succeeds), `cmd1 || cmd2` (if it fails)
- [ ] **For loop**
  ```bash
  for host in web01 web02 web03; do
      echo "Checking $host"
  done
  ```
- [ ] **While loop**
  ```bash
  while true; do date; sleep 5; done
  ```
- [ ] **Loop over lines of a file**
  ```bash
  while read -r host; do echo "$host"; done < hosts.txt
  ```
- [ ] **Case** (menus and options)
  ```bash
  case "$1" in
      start) systemctl start httpd ;;
      stop)  systemctl stop httpd ;;
      *)     echo "Usage: $0 start|stop" ;;
  esac
  ```

## Level 3: real DevOps patterns

- [ ] **Functions**
  ```bash
  check_service() {
      systemctl is-active --quiet "$1" && echo "$1 UP" || echo "$1 DOWN"
  }
  check_service httpd
  ```
- [ ] **Safe-script settings** at the top
  ```bash
  set -euo pipefail   # stop on errors, unset vars, failed pipes
  ```
- [ ] **Check that you're root**
  ```bash
  [ "$EUID" -ne 0 ] && echo "Run as root" && exit 1
  ```
- [ ] **Detect the OS** (yum vs apt)
  ```bash
  if command -v yum &>/dev/null; then
      sudo yum install -y httpd
  else
      sudo apt install -y apache2
  fi
  ```
- [ ] **Run commands on remote servers** (needs SSH keys: `ssh-keygen` + `ssh-copy-id`)
  ```bash
  for host in web01 web02 web03; do
      ssh devops@$host "sudo systemctl status httpd"
  done
  ```
- [ ] **Copy a script to servers and run it**
  ```bash
  for host in $(cat remhosts); do
      scp setup.sh devops@$host:/tmp/
      ssh devops@$host "sudo /tmp/setup.sh"
  done
  ```
- [ ] **Redirect output / logs**
  ```bash
  cmd > out.log 2>&1             # all output to file
  cmd &>/dev/null                # silence everything
  echo "done" | tee -a run.log   # screen + file
  ```
- [ ] **Idempotent commands** (safe to run twice): `mkdir -p`, `rm -f`, `ln -sf`, `grep -q ... || echo ... >>`
- [ ] **Temp work in `/tmp`** (not `/temp`!) and cleanup at the end
- [ ] **Environment variables:** `export VAR=value`; `~/.bashrc` or `/etc/profile` for permanent ones

## Level 4: text processing

- [ ] `grep` (search), `grep -q` (silent, for if-checks)
- [ ] `awk '{print $1}'` (pick columns)
- [ ] `sed -i 's/old/new/g' file` (edit config files from scripts)
- [ ] `cut`, `sort`, `uniq -c`, `wc -l`
- [ ] **Heredoc** (write multi-line config files)
  ```bash
  cat > /etc/nginx/sites-available/app <<EOF
  server { listen 80; }
  EOF
  ```

## Level 5: good habits

- [ ] Meaningful variable names (`PACKAGE`, `SVC`, `URL`) at the top of the script
- [ ] Print progress: `echo "### Installing httpd..."`
- [ ] Check before acting: does the file, user or service already exist?
- [ ] Test on one server before running on all
- [ ] Debug with `bash -x script.sh` (shows each command as it runs)
- [ ] Lint with **shellcheck** (`dnf install ShellCheck` or shellcheck.net)
- [ ] Schedule with cron: `crontab -e`
- [ ] Keep scripts in Git

## Practice projects

1. **System info script:** hostname, IP, RAM, disk, uptime
2. **Service monitor:** if httpd is down, restart it and log it; run every 5 min with cron
3. **Website setup script:** `websitesetup.sh` with variables, `set -e` and OS detection
4. **Multi-server deploy:** run #3 on web01–web03 from scriptbox over SSH
5. **Backup script:** tar a folder with the date in its name, keep only the last 7 backups

If you can do all 5 without copying from the course, you're ready for Ansible and Jenkins.

---

# JSON

**JavaScript Object Notation**: used for APIs, AWS IAM policies, `package.json`, and Terraform state.

## Syntax rules

- Data is in **key–value pairs**: `"key": value`
- Keys **must** be in **double quotes** (`"name"`, never `'name'`)
- Items separated by **commas**, with **no trailing comma** after the last item
- `{ }` = object, `[ ]` = array
- **No comments** allowed

## Data types

```json
{
  "string": "hello",
  "number": 42,
  "float": 3.14,
  "boolean": true,
  "null_value": null,
  "array": ["nginx", "git", "docker"],
  "object": {
    "host": "db01",
    "port": 3306
  },
  "array_of_objects": [
    { "name": "web01", "ip": "192.168.56.11" },
    { "name": "web02", "ip": "192.168.56.12" }
  ]
}
```

## Real DevOps example: AWS IAM policy

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject"],
      "Resource": "arn:aws:s3:::my-bucket/*"
    }
  ]
}
```

## `jq`: work with JSON in the terminal

```bash
sudo apt install -y jq

cat data.json | jq .                       # pretty-print
jq '.name' data.json                       # get a field
jq '.object.host' data.json                # nested field
jq '.array[0]' data.json                   # first array item
jq '.array_of_objects[].name' data.json    # field from every item
jq -r '.name' data.json                    # raw output (no quotes)
jq '.array_of_objects[] | select(.name=="web01")' data.json   # filter
jq 'keys' data.json                        # list keys

# Real use: get EC2 instance IDs from AWS CLI
aws ec2 describe-instances | jq -r '.Reservations[].Instances[].InstanceId'

# API response
curl -s https://api.github.com/users/octocat | jq '.name, .public_repos'
```

## Common JSON mistakes

```json
{ 'name': 'web01' }          ❌ single quotes
{ name: "web01" }            ❌ key not quoted
{ "a": 1, "b": 2, }          ❌ trailing comma
{ "a": 1 // comment }        ❌ comments not allowed
{ "a": True }                ❌ must be lowercase: true
```

Validate quickly: `jq . file.json` (prints an error if the JSON is invalid).

---

# YAML

**YAML Ain't Markup Language**: used for Kubernetes, Docker Compose, GitHub Actions, Ansible, and CloudFormation.

## Syntax rules

- **Indentation defines structure.** Use **spaces only, never tabs** (2 spaces is the convention)
- `key: value`, with **a space after the colon**
- `-` starts a list item
- `#` for comments
- Quotes are usually optional
- `---` separates multiple documents in one file
- File extension: `.yaml` or `.yml`

## Data types

```yaml
# Scalars
string: hello
quoted_string: "hello: world"     # quote if it contains special characters like : or #
number: 42
float: 3.14
boolean: true                     # true / false
null_value: null                  # or ~

# List
packages:
  - nginx
  - git
  - docker

# Inline list (JSON style also works)
ports: [80, 443]

# Object (map)
database:
  host: db01
  port: 3306

# Inline object
database_inline: { host: db01, port: 3306 }

# List of objects
servers:
  - name: web01
    ip: 192.168.56.11
  - name: web02
    ip: 192.168.56.12
```

## Multi-line strings

```yaml
# | keeps line breaks (good for scripts)
script: |
  apt-get update
  apt-get install -y nginx

# > folds lines into one (good for long text)
description: >
  This is a long description
  that becomes a single line.
```

## Anchors & aliases (reuse values)

```yaml
defaults: &defaults        # & creates an anchor
  memory: 1024
  cpus: 1

web01:
  <<: *defaults            # * reuses it, << merges it
  ip: 192.168.56.11

web02:
  <<: *defaults
  ip: 192.168.56.12
  memory: 2048             # override
```

## Real DevOps examples

### Docker Compose (`docker-compose.yml`)

```yaml
services:
  api:
    build: ./api
    ports:
      - "8000:8000"
    environment:
      - DATABASE_URL=postgresql://user:pass@db:5432/app
    depends_on:
      - db

  db:
    image: postgres:16
    environment:
      POSTGRES_USER: user
      POSTGRES_PASSWORD: pass
      POSTGRES_DB: app
    volumes:
      - db_data:/var/lib/postgresql/data

volumes:
  db_data:
```

### Kubernetes Deployment + Service

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
  labels:
    app: web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
          resources:
            limits:
              memory: "128Mi"
              cpu: "250m"
---
apiVersion: v1
kind: Service
metadata:
  name: web-svc
spec:
  selector:
    app: web
  ports:
    - port: 80
      targetPort: 80
  type: ClusterIP
```

### GitHub Actions (`.github/workflows/ci.yml`)

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Install dependencies
        run: pip install -r requirements.txt

      - name: Run tests
        run: pytest
```

### Ansible playbook

```yaml
- name: Install and start nginx
  hosts: webservers
  become: true
  tasks:
    - name: Install nginx
      apt:
        name: nginx
        state: present
        update_cache: true

    - name: Start nginx
      service:
        name: nginx
        state: started
        enabled: true
```

## `yq`: work with YAML in the terminal

```bash
sudo snap install yq                       # or download from GitHub releases

yq '.spec.replicas' deployment.yaml        # read a value
yq '.spec.replicas = 5' -i deployment.yaml # edit in place
yq -o json deployment.yaml                 # convert YAML → JSON
yq -P file.json                            # convert JSON → YAML
```

## Common YAML mistakes

```yaml
name:web01            # ❌ missing space after colon
	port: 80            # ❌ tab used for indentation
servers:
  - name: web01
     ip: 1.2.3.4      # ❌ wrong indentation level
version: 1.10         # ⚠️ becomes number 1.1, use "1.10"
country: NO           # ⚠️ may become false in older parsers, use "NO"
ports:
  - 22:22             # ⚠️ quote port mappings: "22:22"
```

Validate:
- `yamllint file.yaml` (`pip install yamllint`)
- `kubectl apply --dry-run=client -f file.yaml` (Kubernetes)
- `docker compose config` (Docker Compose)
- VS Code: install the **YAML** extension by Red Hat

---

# JSON vs YAML

| | JSON | YAML |
|---|---|---|
| Structure | `{ }` `[ ]` and commas | Indentation |
| Quotes | Required | Usually optional |
| Comments | ❌ No | ✅ `#` |
| Readability | OK | Easier for people |
| Common errors | Missing / extra commas | Wrong indentation, tabs |
| Parsing speed | Faster | Slower |
| Used for | APIs, IAM policies, data exchange | Config files, K8s, CI/CD, Ansible |

**Rule of thumb:** people write it (config) → YAML. Programs exchange it (APIs) → JSON.

YAML 1.2 is a superset of JSON, so any valid JSON is also valid YAML.

---

# Vagrant lab commands

This folder's `vagrantfile` creates 3 VMs in VirtualBox:

| VM | IP | Role |
|---|---|---|
| web01 | 192.168.56.11 | nginx |
| web02 | 192.168.56.12 | nginx |
| db01 | 192.168.56.21 | MySQL |

```powershell
vagrant up               # start all VMs
vagrant up web01         # start one VM
vagrant status           # state of all VMs
vagrant ssh web01        # log in (VM name required)
vagrant halt             # stop all VMs
vagrant reload db01      # restart a VM (fixes network issues)
vagrant provision        # re-run setup scripts
vagrant destroy -f       # delete all VMs
vagrant global-status    # all Vagrant VMs on this PC
vagrant box list         # downloaded base images
```
