# AWS Notes

My AWS reference: EC2, security groups, network interfaces, EBS, key pairs, SSM and the errors I've hit. Related notes: [README.md](README.md) (Linux, JSON, YAML, Bash) and [LEARNING-CHECKLIST.md](LEARNING-CHECKLIST.md).

## Contents

1. [Account safety & billing](#1-account-safety--billing)
2. [Regions & Availability Zones](#2-regions--availability-zones)
3. [EC2 instances](#3-ec2-instances)
4. [Key pairs & SSH](#4-key-pairs--ssh)
5. [Security groups](#5-security-groups)
6. [Network interfaces (ENI) & IPs](#6-network-interfaces-eni--ips)
7. [EBS volumes](#7-ebs-volumes)
8. [IAM roles for EC2](#8-iam-roles-for-ec2)
9. [SSM (Systems Manager)](#9-ssm-systems-manager)
10. [MariaDB on Amazon Linux](#10-mariadb-on-amazon-linux)
11. [AWS CLI commands](#11-aws-cli-commands)
12. [Cleanup checklist](#12-cleanup-checklist)
13. [Errors I've hit](#13-errors-ive-hit)

---

## 1. Account safety & billing

**Do first:**
- [ ] MFA on the **root** account
- [ ] Create an **IAM user** (with MFA) for daily work; don't use root
- [ ] **Budget alert** ($10 / $25 / $50); track usage **before credits** (uncheck "Credits" in the budget's cost options)
- [ ] Free Tier usage alerts (Billing → Billing preferences)
- [ ] Pick **one region** and stick to it

**Credits:** about $140 available. Check balance and **expiry date** under Billing → Credits. The free plan (2025+) may have a time limit, so check account plan details.

**Never** put AWS access keys in GitHub. Bots find leaked keys within minutes.

**Practice pattern:** launch → use for a few hours → **terminate** → check leftovers.

| Usage | Approx. cost |
|---|---|
| `t3.micro` (1 GB) | ~$0.01/hr |
| `t3.medium` (4 GB) | ~$0.04/hr |
| `t3.large` (8 GB) | ~$0.08/hr → 4 hrs ≈ $0.35 |
| `t3.large` left on 24/7 | ~$65/month ⚠️ |

**Fastest credit burners:** NAT Gateway, EKS control plane, RDS, load balancers. They all charge **hourly even when idle**.

---

## 2. Regions & Availability Zones

| Term | Meaning | Example |
|---|---|---|
| **Region** | Geographic area with its own resources | `us-east-1` (N. Virginia), `ap-south-1` (Mumbai) |
| **Availability Zone (AZ)** | Separate data center inside a region | `us-east-1a`, `us-east-1d` |

- The console only shows resources in the **selected region** (top right), so check it when something seems missing.
- **EBS volumes and subnets live in one AZ.** An instance and its volume must be in the **same AZ**.
- Spread instances across AZs for high availability.

---

## 3. EC2 instances

**EC2** = virtual machines in AWS, like Vagrant VMs but in the cloud.

| Vagrant | EC2 |
|---|---|
| Box (`ubuntu/jammy64`) | **AMI** (machine image) |
| `vb.memory = 600` | **Instance type** (`t3.micro`) |
| Shell provisioning | **User data** (runs once at first boot) |
| `vagrant ssh` | `ssh -i key.pem user@ip` or Session Manager |
| Private network | VPC + subnets |
| VirtualBox firewall / firewalld | **Security group** |

### Instance types

| Family | For | Example |
|---|---|---|
| **t** (burstable) | Cheap, general, labs | `t3.micro` 2 vCPU / 1 GB |
| **m** | Balanced | `m7i.large` |
| **c** | CPU heavy | `c7i.xlarge` |
| **r** | Memory heavy (DBs, caches) | `r7i.large` |
| **g / p** | GPU (ML) | `g5.xlarge` |
| **…g** suffix (`t4g`) | ARM / Graviton, ~20% cheaper | `t4g.micro` |

**Sizing for my projects:** 1 Python service → `t3.micro`. Java Spring Boot + Python microservices + DB → **`t3.medium` (4 GB) or larger**. RAM is the limit, not the LLM API calls.

`t3` defaults to **Unlimited** mode, where sustained high CPU costs extra. Choose *Standard* at launch for a fixed price.

### Instance states

| State | Billing |
|---|---|
| **running** | Instance + disk billed |
| **stopped** | Instance free, **EBS disk still billed** |
| **terminated** | Nothing billed (root disk deleted). Stays visible ~1 hr |

**Stop** = pause (keeps the disk). **Terminate** = delete for good.

### Pricing models

| Model | Discount | Use for |
|---|---|---|
| On-Demand | — | Labs, testing |
| **Spot** | up to ~90% | Practice, batch jobs (AWS can reclaim with 2 min notice) |
| Reserved / Savings Plans | ~40–70% | Always-on production |

### Default users by AMI

| AMI | SSH user | Package manager | Web server |
|---|---|---|---|
| Amazon Linux 2023 | `ec2-user` | `dnf` | `httpd` (runs as `apache`) |
| Ubuntu | `ubuntu` | `apt` | `apache2` (runs as `www-data`) |
| RHEL / CentOS | `ec2-user` | `dnf` | `httpd` |

### User data examples

Amazon Linux:
```bash
#!/bin/bash
dnf install -y httpd
systemctl enable --now httpd
echo "<h1>Hello from $(hostname -f)</h1>" > /var/www/html/index.html
```

Ubuntu:
```bash
#!/bin/bash
apt-get update -y
apt-get install -y apache2
systemctl enable --now apache2
```

- `#!/bin/bash` must be the **first line**.
- It runs as **root**, so no `sudo` is needed.
- It runs **only once**, at first boot.
- Debug it with `sudo cat /var/log/cloud-init-output.log`

---

## 4. Key pairs & SSH

- AWS keeps the **public key** on the instance (`~/.ssh/authorized_keys`).
- You download the **private key** (`.pem`) **once**, at creation. Lose it and you can't log in with that key.
- Same idea as `ssh-keygen` + `ssh-copy-id` in the Vagrant lab.

```powershell
# Windows PowerShell
ssh -i C:\Users\kvssp\.ssh\mykey.pem ec2-user@<public-ip>   # Amazon Linux
ssh -i C:\Users\kvssp\.ssh\mykey.pem ubuntu@<public-ip>     # Ubuntu
```

**"UNPROTECTED PRIVATE KEY FILE"** (Windows): permissions are too open. Fix:
```powershell
icacls C:\Users\kvssp\.ssh\mykey.pem /inheritance:r /grant:r "$($env:USERNAME):R"
```
On Linux/Mac: `chmod 400 mykey.pem`

**First connection:** `The authenticity of host ... can't be established`. Type `yes`. The server's fingerprint is saved in `~/.ssh/known_hosts`.

**`REMOTE HOST IDENTIFICATION HAS CHANGED`**: in labs this means a new instance got the same IP. Remove the old entry:
```powershell
ssh-keygen -R <ip-or-hostname>
```
On a real server that didn't change, **stop and investigate**.

Key pairs are **free**; you can keep them.

---

## 5. Security groups

A **security group (SG)** is a firewall for an instance (attached to its network interface).

- **Inbound rules:** who can connect **to** the instance
- **Outbound rules:** where the instance can connect **out** to
- **Allow-only:** no "deny" rules. Anything not allowed is blocked.
- **Stateful:** replies to allowed traffic are allowed automatically. That's why SSH works even with broken outbound rules.
- Changes apply **immediately**.
- One instance can have several SGs, and one SG can be used by many instances.

### Typical inbound rules

| Type | Port | Source | Why |
|---|---|---|---|
| SSH | 22 | **My IP** (`x.x.x.x/32`) | Only me |
| HTTP | 80 | `0.0.0.0/0` (website) or My IP (testing) | Web traffic |
| HTTPS | 443 | `0.0.0.0/0` | Secure web |
| MYSQL/Aurora | 3306 | **App server's SG** or private IP | **Never** `0.0.0.0/0` |
| Custom TCP | 8080 | Load balancer's SG | Tomcat behind LB |

### Default outbound rule (keep it)

```
All traffic | All | All | 0.0.0.0/0
```
Without an **IPv4** outbound rule, `apt`/`dnf`, SSM agent, `curl` and so on all fail.

### Tips

- **Source = another security group** (e.g. DB allows 3306 from `app-sg`). This is better than IPs, because it keeps working when IPs change.
- **"My IP" changes** at home and on mobile. If SSH suddenly times out, update the rule (`curl.exe -s https://checkip.amazonaws.com`).
- New instances from the wizard often get a **new SG** (`launch-wizard-N`) with only SSH. Add your other rules to the SG **actually attached** (Instance → Security tab).
- **Timeout** = blocked by SG/firewall. **Connection refused** = reachable, but nothing listening.

| | Security group | firewalld / ufw |
|---|---|---|
| Where | AWS, outside the instance | Inside the OS |
| Default | Inbound denied, outbound allowed | Depends on distro |
| Amazon Linux 2023 | Main firewall | firewalld **not installed** by default |

---

## 6. Network interfaces (ENI) & IPs

An **ENI (Elastic Network Interface)** is a virtual network card. Every instance has a **primary ENI** (`eth0` / `ens5`).

An ENI holds:
- **Private IPv4** (e.g. `172.31.16.30`): used inside the VPC, stays the same for the instance's life
- **Public IPv4** (optional): changes on every **stop/start**
- **Security groups** (SGs are attached to ENIs, not directly to instances)
- MAC address, optional IPv6, optional Elastic IP

### Public IP vs Elastic IP

| | Auto public IP | Elastic IP |
|---|---|---|
| Changes on stop/start | ✅ Yes | ❌ No, fixed |
| Cost | ~$0.005/hr while assigned | ~$0.005/hr, **also charged when not attached** |
| Use for | Labs | Servers needing a fixed address |

**Release unused Elastic IPs.**

### Secondary ENIs

- You can create extra ENIs and attach them (same AZ), e.g. for a management network or to move an IP between instances (failover).
- The primary ENI can't be detached.
- Labs rarely need them.

### Hostname

`ip-172-31-16-30` = the private IP in hostname form. Public DNS looks like `ec2-54-80-165-213.compute-1.amazonaws.com`.

### VPC basics (default VPC is fine for labs)

| Part | What |
|---|---|
| **VPC** | Your private network in AWS (`172.31.0.0/16` default) |
| **Subnet** | A slice of the VPC in **one AZ** |
| **Internet Gateway (IGW)** | Door to the internet |
| **Route table** | Public subnet has `0.0.0.0/0 → igw-…` |
| **NACL** | Subnet-level firewall (stateless; default allows all) |

---

## 7. EBS volumes

**EBS** = a network disk for EC2, **locked to one AZ**, survives stop/start.

### Volume types

| Type | Use |
|---|---|
| **gp3** ⭐ | Default for everything (root, apps, small DBs) |
| gp2 | Older general SSD; prefer gp3 |
| io2 / io1 | Busy production DBs (expensive) |
| st1 | Big sequential data (HDD), no boot |
| sc1 | Cold, rarely used data (cheapest), no boot |

### Root vs extra volumes

| | Root | Extra |
|---|---|---|
| Delete on terminate | ✅ Yes (default) | ❌ **No**, so delete it yourself |

### Snapshots

- Point-in-time **backup**, stored by AWS (in S3), **incremental**
- Restore = create a **new volume** from the snapshot, in **any AZ** (this is how you move data between AZs)
- Can be copied to other regions; used to build AMIs
- Automate with **Data Lifecycle Manager**

### Add a new disk (Linux)

Console: Volumes → **Create volume** (same AZ!) → **Attach volume** to the instance.

```bash
lsblk                                  # new disk = no mountpoint (e.g. nvme1n1)
sudo mkfs -t ext4 /dev/nvme1n1         # format: NEW EMPTY disk only (erases it!)
sudo mkdir -p /data
sudo mount /dev/nvme1n1 /data
df -h /data
```

Make it permanent:
```bash
UUID=$(sudo blkid -s UUID -o value /dev/nvme1n1)
echo "UUID=$UUID  /data  ext4  defaults,nofail  0  2" | sudo tee -a /etc/fstab
sudo mount -a                          # no output = OK
```
- Use the **UUID**, not `/dev/nvme1n1`, because device names change after detach/reattach.
- `nofail` lets the instance still boot if the disk is missing.

### Mount explained

Linux has **no drive letters**. **Mount** = attach a disk to a folder (the **mount point**). Files saved in that folder go to that disk. `umount` disconnects it; the data stays on the disk.

**Partitions** aren't needed for a data disk. Format the whole disk.

### Move a service's data to a new disk

**"Stop, copy, swap, save, start, check."**

```bash
systemctl stop mariadb                              # STOP
mkfs -t ext4 /dev/nvme1n1                           # (only if new)
mkdir -p /mnt/new && mount /dev/nvme1n1 /mnt/new
rsync -a /var/lib/mysql/ /mnt/new/                  # COPY (-a keeps owners!)
umount /mnt/new
mv /var/lib/mysql /var/lib/mysql.bak                # SWAP
mkdir /var/lib/mysql
mount /dev/nvme1n1 /var/lib/mysql
chown mysql:mysql /var/lib/mysql
restorecon -R /var/lib/mysql 2>/dev/null || true
UUID=$(blkid -s UUID -o value /dev/nvme1n1)         # SAVE
echo "UUID=$UUID  /var/lib/mysql  ext4  defaults,nofail  0  2" >> /etc/fstab
mount -a
systemctl start mariadb                             # START
df -h /var/lib/mysql                                # CHECK
mysql -u root -p -e "SHOW DATABASES;"
rm -rf /var/lib/mysql.bak                           # only after it works
```

The same pattern works for `/var/lib/docker`, `/var/lib/pgsql`, `/var/www/html`.

Mounting a disk **directly** on `/var/lib/mysql` shows `#mysql50#lost+found` as a "database". It's harmless. Best practice: mount on `/data` and set `datadir=/data/mysql`.

### Resize a volume

Console → Modify (increase only, never decrease), then:
```bash
sudo growpart /dev/nvme0n1 1        # grow the partition (root disk)
sudo resize2fs /dev/nvme0n1p1       # ext4 (Ubuntu)
sudo xfs_growfs -d /                # xfs (Amazon Linux)
```

### Remove a disk

```bash
sudo umount /data
sudo sed -i '/<UUID>/d' /etc/fstab   # remove its fstab line
```
Console: Volumes → **Detach** → **Delete**.

`sudo wipefs -a /dev/nvme1n1` erases the filesystem but keeps the volume.

**Never touch `nvme0n1`**, the root disk. Run `lsblk` first and check the name and size.

### Storage comparison

| | EBS | Instance store | EFS | S3 |
|---|---|---|---|---|
| Kind | Block disk | Local disk | Shared NFS | Objects |
| Survives stop | ✅ | ❌ | ✅ | ✅ |
| Many instances | ❌ | ❌ | ✅ | ✅ |
| Scope | 1 AZ | 1 instance | Region | Region |

**Cost:** pay per **provisioned GB** (gp3 ~$0.08/GB/month), even when unattached. Snapshots ~$0.05/GB/month.

---

## 8. IAM roles for EC2

An **IAM role** gives an instance permissions **without storing access keys** on it.

- **Trust policy** = who can use the role. For EC2 it must be:
  ```json
  "Principal": { "Service": "ec2.amazonaws.com" }
  ```
- **Permissions policies** = what the role can do (e.g. `AmazonSSMManagedInstanceCore`, `AmazonS3ReadOnlyAccess`)
- Attach it: Instance → Actions → Security → **Modify IAM role**
- Create it with **use case = EC2**. Picking another service creates the wrong trust policy.

IAM policies are **JSON** (`Effect`, `Action`, `Resource`).

---

## 9. SSM (Systems Manager)

### Requirements

1. **SSM Agent** (pre-installed on Amazon Linux and Ubuntu AMIs)
2. **IAM role** with trust `ec2.amazonaws.com` + policy **`AmazonSSMManagedInstanceCore`**
3. **Outbound internet** (SG outbound IPv4 rule!) or VPC endpoints

Check: Systems Manager → **Fleet Manager** → Ping status **Online**.

### Most useful features (free)

| Feature | What it does |
|---|---|
| **Session Manager** ⭐ | Shell access **without SSH**: no port 22, no keys, no public IP needed, sessions logged |
| **Parameter Store** ⭐ | Store config and secrets (`SecureString`) instead of hard-coding passwords |
| **Run Command** | Run scripts on many instances at once (`AWS-RunShellScript`), target by tag |
| Fleet Manager | List managed nodes and status |
| Patch Manager / State Manager / Inventory | OS updates, desired state, installed software |

```bash
aws ssm start-session --target i-0abc123
aws ssm put-parameter --name "/app/db/password" --value "secret" --type SecureString
aws ssm get-parameter --name "/app/db/password" --with-decryption
aws ssm send-command --document-name "AWS-RunShellScript" \
  --targets "Key=tag:Role,Values=web" --parameters 'commands=["uptime"]'
```

### Troubleshooting "unable to acquire credentials"

1. Role **trust** = `ec2.amazonaws.com`
2. Role has **`AmazonSSMManagedInstanceCore`**
3. SG has an **outbound IPv4** rule (`0.0.0.0/0`)
4. **Reboot** or restart the agent:
   ```bash
   sudo snap restart amazon-ssm-agent          # Ubuntu
   sudo systemctl restart amazon-ssm-agent     # Amazon Linux
   ```
5. Logs: `sudo tail -30 /var/log/amazon/ssm/amazon-ssm-agent.log`

"Default Host Management Configuration not enabled" is an optional feature. Ignore it when using an instance role.

---

## 10. MariaDB on Amazon Linux

| OS | Package | Service |
|---|---|---|
| **Amazon Linux 2023** | `mariadb105-server` | `mariadb` |
| Ubuntu | `mariadb-server` | `mariadb` |
| CentOS / RHEL | `mariadb-server` | `mariadb` |

```bash
#!/bin/bash
set -e
DB_ROOT_PASS='admin123'          # labs only! real projects: Parameter Store

dnf install -y mariadb105-server
systemctl enable --now mariadb

mysql -u root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASS}';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
CREATE DATABASE IF NOT EXISTS accounts;
CREATE USER IF NOT EXISTS 'admin'@'%' IDENTIFIED BY 'admin123';
GRANT ALL PRIVILEGES ON accounts.* TO 'admin'@'%';
FLUSH PRIVILEGES;
EOF
```

| Path | What |
|---|---|
| `/var/lib/mysql` | Data |
| `/etc/my.cnf.d/mariadb-server.cnf` | Config |
| `/var/log/mariadb/mariadb.log` | Log |

Remote access: SG inbound **3306 from the app server's SG**. Amazon Linux 2023 has no firewalld by default.

---

## 11. AWS CLI commands

```bash
aws configure                                  # set keys + default region
aws sts get-caller-identity                    # who am I?

# Running instances as a table
aws ec2 describe-instances \
  --filters "Name=instance-state-name,Values=running" \
  --query "Reservations[].Instances[].[Tags[?Key=='Name']|[0].Value,InstanceId,InstanceType,State.Name,PublicIpAddress]" \
  --output table

aws ec2 describe-volumes --query "Volumes[].[VolumeId,State,Size,AvailabilityZone]" --output table
aws ec2 describe-addresses --output table      # Elastic IPs
aws ec2 describe-security-groups --query "SecurityGroups[].[GroupId,GroupName]" --output table

# Check every region for forgotten instances
for r in $(aws ec2 describe-regions --query "Regions[].RegionName" --output text); do
  echo "== $r"
  aws ec2 describe-instances --region $r \
    --filters "Name=instance-state-name,Values=running,stopped" \
    --query "Reservations[].Instances[].[InstanceId,State.Name]" --output text
done
```

- `describe-instances` = **one region**, **all states** (including stopped and recently terminated).
- `--query` uses JMESPath; you can also pipe into `jq`.
- **AWS CloudShell** (`>_` in the console) has the CLI ready to use, no setup needed.

---

## 12. Cleanup checklist

After **every** lab, in the region you used:

- [ ] EC2 → **Instances**: terminate (not just stop)
- [ ] EC2 → **Volumes**: none left in state `available`
- [ ] EC2 → **Elastic IPs**: release unattached ones
- [ ] EC2 → **Snapshots / AMIs**: delete the ones you don't need
- [ ] EC2 → **Load Balancers / Target groups**: delete
- [ ] **RDS**, **NAT Gateways**, **EKS**: delete
- [ ] Remove fstab lines for disks you deleted (if the instance stays)
- [ ] Check **Billing → Bills** every few days (updates are a few hours late)

Free to keep: security groups, key pairs, launch templates, IAM roles.

---

## 13. Errors I've hit

| Problem | Cause | Fix |
|---|---|---|
| Site not loading, but httpd running | Browser forced **https://** | Type `http://<ip>`; test with `curl.exe -I http://<ip>` |
| Port 80 **timeout**, SSH works, `Total requests: 0` | New instance got a **new SG** without HTTP | Add HTTP 80 to the SG attached to *that* instance |
| `apt` "Network is unreachable", SSM offline, SSH fine | SG outbound rules were **IPv6 only** | Add outbound **All traffic → 0.0.0.0/0** |
| SSM "unable to acquire credentials" | Role / policy / no outbound / agent not retried | See [SSM troubleshooting](#troubleshooting-unable-to-acquire-credentials) |
| `apt install mariadb105-server` fails | Amazon Linux package name used on **Ubuntu** | Ubuntu: `mariadb-server` |
| `fdisk -l` Permission denied | Not root | `sudo -i` |
| `wipefs: No such file or directory` | Volume was detached; device names changed | `lsblk` first; use UUIDs |
| `REMOTE HOST IDENTIFICATION HAS CHANGED` | New instance reused the IP | `ssh-keygen -R <ip>` |
| `#mysql50#lost+found` database | Disk mounted directly on `/var/lib/mysql` | Harmless; or mount on `/data` + `datadir=/data/mysql` |
| Pager stuck at `lines 1-20 (END)` | `systemctl status` opened a pager | Press `q`, or add `--no-pager` |
