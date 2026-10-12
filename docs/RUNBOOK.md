# Complete CI/CD with Terraform — Standalone Runbook

## Verified cleanup — October 11, 2026 (America/Vancouver)

The application was successfully deployed and verified before teardown.
The deployment evidence describes that completed demonstration; the application
endpoint is no longer live.

- Application Terraform: 14 resources destroyed; state is empty.
- EC2 instance: termination verified.
- Application root EBS volume: deletion verified.
- Backend Terraform: 5 resources destroyed; state is empty.
- S3 state bucket: deletion verified after removing all object versions and delete markers.
- Jenkins Droplet: deletion confirmed by the operator.
- Dedicated Jenkins AWS user: both access keys verified Inactive.
- Capstone Docker Hub token: revocation confirmed by the operator.
- Private backups: all 15 S3 object versions and bootstrap state preserved locally.
- GitHub/GitLab repositories and published Docker Hub images retained.

Earlier references to running infrastructure or pending cleanup describe the
deployment phase. This record supersedes those status statements.
DigitalOcean snapshot, volume, and billing inventory has not been independently
verified. Inactive IAM keys and the dedicated IAM user/policy remain in AWS.

## 1. Scope and verification boundary

This guide reproduces the verified Jenkins → Maven → AMD64 Docker image → Docker Hub → Terraform EC2 → SSH/Compose → HTTP workflow. Jenkins runs on DigitalOcean; the application and its state backend run in AWS. Appendix A contains all 36 tracked implementation files verbatim, including provider locks. Local secrets, private keys, state, and plans are deliberately excluded.

Source checkpoint: `b87ac5d96a24e141202bd9e565260a8c2e7c36cd`. Both successful pipeline builds used application commit `ec97d3ef64fb336db647cf51a781f3bc94be76c1`. Verification occurred October 11, 2026 in America/Vancouver; build logs are dated October 12 UTC.

| Procedure | Verified evidence |
|---|---|
| Starter import | Independent Git history and SOURCES.md |
| Local application | Maven package; native and AMD64 container HTTP checks passed |
| Static checks | Bash syntax; Terraform validation; six inline host-key parser checks |
| Backend bootstrap | 5 resources created; versioning, encryption, public access and HTTPS policy checked |
| Dedicated IAM preflight | Exact user identity; S3 init and 14 planned creates passed |
| Fresh host | Ubuntu updates/reboot, administrative login/sudo, SSH restrictions, UFW and Docker passed |
| Jenkins image | Official base, required tools/plugins, socket access and localhost binding passed |
| Build #1 | SUCCESS; 14 resources created; image published/deployed by digest; exact homepage passed |
| Independent Mac check | Exact EC2 homepage comparison passed after build #1 |
| Build #2 | SUCCESS; 0 infrastructure changes; same EC2 instance; new image deployed |
| Controller code preservation | Commit b87ac5d pushed to GitHub and GitLab |
| Teardown, rollback, backup restore, branch release | Procedures documented below; not yet executed/verified |

`mvn verify` reported **no tests to run**. No application test sources are committed. The six host-key parser tests were run inline during implementation, not saved as a test suite. `Application.getStatus()` is an ordinary method, not a mapped HTTP endpoint; the verified endpoint is `/`.

The assignment does not require EKS, ECR, Ansible, a database, Nexus, or a Jenkins shared library. No webhook or automatic build trigger was configured. This is a manually triggered Pipeline job using a version-controlled Jenkinsfile.

### Recorded inventory

| Item | Historical value |
|---|---|
| AWS account / region | `002184382122` / `ca-central-1` |
| Administrative profile | `default`, IAM user `myusercli` |
| Jenkins IAM user / policy | `jenkins-terraform-capstone` / `JenkinsTerraformCapstone` |
| State bucket | `gafari-tf-cicd-002184382122-ca-central-1` |
| State key | `complete-cicd-with-terraform/application/terraform.tfstate` |
| AMI / instance type | `ami-0bf6dbeae330f5823` / `t3.micro` |
| EC2 instance / address | `i-063e9387fb8155c11` / `3.99.49.109` |
| VPC / subnet | `vpc-0f021721555eecf37` / `subnet-037ae5ed47fb39d3f` |
| Security group | `sg-084a35ec0b823da83` |
| VPC / subnet CIDRs | `10.30.0.0/16` / `10.30.1.0/24` |
| Fresh Jenkins Droplet | `159.203.63.2`, `jenkins-terraform-clean` |
| Operator IPv4 | `162.156.99.186` |
| Operator / EC2 SSH users | `gafari` / `ec2-user` |
| Jenkins admin | `admin` |
| New Jenkins volume | `jenkins_terraform_clean_home` |

Addresses/IDs are evidence, not permanent values. Update them for a new environment. The application is restricted to approved networks; its historical URL is not a public portfolio endpoint.

## 2. Read before running commands

Commands are labeled **Mac**, **Droplet**, or **EC2**. Execute multi-line examples in Bash (the Mac default may be zsh). Never run the whole document as one script: apply, user creation, credential rotation, and teardown require their stated preconditions and review.

There are two Terraform roots:

- `bootstrap/backend/`: administrator provisions the protected S3 bucket; state is **local** and must be backed up privately.
- `terraform/`: Jenkins manages the application resources; state is in S3 using native lock files.

Use the default Terraform workspace. Mac operations and Jenkins must agree on account, region, bucket, key, and workspace. Never operate concurrently or create a new backend to bypass an error. An application destroy must not delete its state bucket.

Provision paid servers late: first obtain/validate source and bootstrap the small state backend; create the Jenkins host after local checks; let Jenkins create EC2 only after publishing the image. Review current provider pricing before creation; this guide does not assert fixed costs.

After compromise, use a fresh OS and fresh Jenkins volume. A new SSH key does not establish that an old snapshot is clean. Keep secrets out of Git, chat, command tracing, screenshots, and shared logs.

## 3. Obtain and adapt source — Mac

### 3.1 Clone the finished project

```bash
mkdir -p "$HOME/Documents/tech-workspace/devops-capstone-projects"
cd "$HOME/Documents/tech-workspace/devops-capstone-projects"
git clone --branch feature/terraform-cicd \
  https://github.com/younghadiz/complete-cicd-with-terraform.git
cd complete-cicd-with-terraform
git remote add gitlab git@gitlab.com:devops-engineering-projects/complete-cicd-with-terraform.git
git status --short --branch
git log -1 --oneline
```

Do not clone over an existing project. For the existing checkout, simply `cd` into it and inspect `git remote -v` / `git status`. The full source checkpoint is recorded above; use a temporary branch at that SHA if exact source recovery is required. Appendix A provides the relative path and complete content of every source file if Git is unavailable. After reconstructing files, restore script permissions:

```bash
chmod +x server-cmds.sh terraform/scripts/bootstrap.sh
```

The original application starter came from TechWorld with Nana, module 12, branch `feature/starting-code`, SHA `12112fb528497fe87f0c30f50a879b29d6c0a6a7`. It was imported via `git archive` into an empty independent repository and attributed in `SOURCES.md`. The upstream `jenkinsfile-sshagent` branch served as implementation reference. The local project created main/develop/feature branches and GitHub/GitLab remotes. The normal reproduction path is the finished checkout, not importing the starter and then trying to reconstruct undocumented edits.

For another portfolio repository, copy only the finished tracked files without `.git`, retain SOURCES.md, initialize your own repository and commit. Do not copy ignored secrets or state.

### 3.2 Porting to another account/namespace

The examples below match the recorded account. For another environment, review these together before any apply:

| Value | Matching locations |
|---|---|
| Account | Bootstrap variables/overrides, application tfvars, Jenkinsfile account check, IAM ARNs |
| Region | Bootstrap, tfvars, backend, Jenkinsfile exports, IAM region condition, regional AMI |
| Bucket and state key | Bootstrap name, backend file, all S3 policy resource ARNs |
| Docker Hub namespace | Jenkinsfile repository, username assertions, deployment-digest regex, credential |
| Project name | tfvars, resource names, deployment paths/bootstrap/Compose defaults if renamed |
| IP ranges | DO firewall/UFW operator source; application tfvars and Jenkins uploaded file |

Editing tfvars alone will not change literal Jenkinsfile account/username/region assertions. The EC2 IAM policy uses Resource `*` within its region: it is not project-tag isolation or fully minimized production least privilege. Review the VPC range if it will connect to other networks.

## 4. Local tools and application verification — Mac

Install Git, JDK 17, Maven, Docker Desktop/Compose, Terraform 1.15.6, AWS CLI v2, Python 3, curl, and OpenSSH from trusted distributions. References are in Section 15. These are recorded/compatible tools, not a claim of latest versions.

```bash
git --version
uname -m
java -version
mvn --version
docker --version
docker compose version
terraform version
aws --version
python3 --version
open -a Docker
docker info --format 'Docker server: {{.ServerVersion}}'
```

Wait for Docker Desktop to be ready. Missing `~/.docker/run/docker.sock` was fixed by starting the engine, not changing folders.

In the repository root:

```bash
set -euo pipefail
mvn --batch-mode --no-transfer-progress clean verify
bash -n server-cmds.sh
bash -n terraform/scripts/bootstrap.sh
git diff --check

export IMAGE="complete-cicd-with-terraform:amd64-check"
export APP_BIND_ADDRESS="127.0.0.1"
export APP_PORT="18080"
export COMPOSE_PROJECT_NAME="terraform-local-check-$$"
export PULL_IMAGE="false"
docker build --platform linux/amd64 --tag "$IMAGE" .
test "$(docker image inspect "$IMAGE" --format '{{.Architecture}}')" = "amd64"
trap 'docker compose -f docker-compose.yaml down' EXIT

VERIFY_METHOD=container ./server-cmds.sh "$IMAGE"
VERIFY_METHOD=host ./server-cmds.sh "$IMAGE"
curl --fail --silent --show-error --max-time 5 \
  http://127.0.0.1:18080/ -o target/local-homepage.html
cmp src/main/resources/static/index.html target/local-homepage.html
```

Omit `--platform` for an optional native build. AMD64 emulation warnings on Apple Silicon are expected. The container probe uses BusyBox wget inside the application container; the host probe uses curl from the script's host. Jenkins mounts the host Docker socket, so its own localhost is not the host's localhost: `VERIFY_METHOD=container` is essential in CI. It does not itself verify published host ports; EC2 later adds host and external HTTP checks.

Initial connection refusals may occur while Spring Boot starts. The bounded retry loop must eventually pass. On failure the script prints container status/logs. Local tests leave an image and build output but remove the isolated Compose containers/network.

## 5. Bootstrap the S3 state bucket — Mac administrator

Use a trusted administrative profile. Verify account before creating the bucket; the Jenkins policy deliberately cannot create/administer it.

```bash
aws configure list-profiles
aws --profile default --region ca-central-1 sts get-caller-identity \
  --query '{Account:Account,Arn:Arn}' --output json
```

For a brand-new bucket in the recorded account:

```bash
set -euo pipefail
export AWS_PROFILE="default"
export AWS_REGION="ca-central-1"
export AWS_DEFAULT_REGION="$AWS_REGION"
test "$(aws sts get-caller-identity --query Account --output text)" = "002184382122"
terraform -chdir=bootstrap/backend init -input=false -lockfile=readonly
terraform -chdir=bootstrap/backend fmt -check
terraform -chdir=bootstrap/backend validate
terraform -chdir=bootstrap/backend plan -input=false -out=backend.tfplan
```

Review correct name/account/region and **5 creates, no changes/deletions**. Only then:

```bash
terraform -chdir=bootstrap/backend apply -input=false backend.tfplan
terraform -chdir=bootstrap/backend output
```

If the bucket already exists, reuse its original bootstrap state. Do not blindly create again or destroy/recreate it. Lost local bootstrap state requires recovery from private backups or reviewed import of all five resources before planning; that recovery was not tested here.

Verify protections:

```bash
aws --profile default --region ca-central-1 s3api get-bucket-versioning \
  --bucket gafari-tf-cicd-002184382122-ca-central-1 --expected-bucket-owner 002184382122
aws --profile default --region ca-central-1 s3api get-bucket-encryption \
  --bucket gafari-tf-cicd-002184382122-ca-central-1 --expected-bucket-owner 002184382122
aws --profile default --region ca-central-1 s3api get-public-access-block \
  --bucket gafari-tf-cicd-002184382122-ca-central-1 --expected-bucket-owner 002184382122
aws --profile default --region ca-central-1 s3api get-bucket-policy \
  --bucket gafari-tf-cicd-002184382122-ca-central-1 --expected-bucket-owner 002184382122 \
  --query Policy --output text
```

Expect versioning Enabled, AES256, all four public-access blocks true, and DenyInsecureTransport for bucket/objects. Preserve `bootstrap/backend/terraform.tfstate` and its backup securely outside Git. Application backend initialization does **not** migrate this local bootstrap state.

## 6. Dedicated Jenkins AWS identity — Mac administrator

### 6.1 Validate and attach policy

```bash
python3 -m json.tool iam/jenkins-terraform-policy.json >/dev/null
aws --profile default --region ca-central-1 accessanalyzer validate-policy \
  --policy-document file://iam/jenkins-terraform-policy.json --policy-type IDENTITY_POLICY \
  --query 'findings[].{Type:findingType,Code:issueCode,Details:findingDetails}' --output json
```

Verified findings: `[]`. This is policy validation, not proof of complete least privilege/runtime permissions. For an entirely fresh IAM setup, create once:

```bash
set -euo pipefail
test "$(aws --profile default sts get-caller-identity --query Account --output text)" = "002184382122"
aws --profile default iam create-user --user-name jenkins-terraform-capstone \
  --tags Key=Project,Value=complete-cicd-with-terraform
policy_arn="$(aws --profile default iam create-policy \
  --policy-name JenkinsTerraformCapstone \
  --policy-document file://iam/jenkins-terraform-policy.json \
  --tags Key=Project,Value=complete-cicd-with-terraform \
  --query Policy.Arn --output text)"
aws --profile default iam attach-user-policy \
  --user-name jenkins-terraform-capstone --policy-arn "$policy_arn"
aws --profile default iam list-attached-user-policies \
  --user-name jenkins-terraform-capstone --output table
```

If already present, inspect/reuse the user/policy. Do not attach AdministratorAccess as a troubleshooting shortcut. Updating policy JSON in Git does not change the live managed policy; a reviewed new default policy version is required.

### 6.2 Create key without displaying secrets

Inspect metadata first:

```bash
aws --profile default iam list-access-keys --user-name jenkins-terraform-capstone \
  --query 'AccessKeyMetadata[].{KeyId:AccessKeyId,Status:Status,Created:CreateDate}' --output table
```

For a fresh user with zero keys:

```bash
set -euo pipefail
umask 077
key_dir="$HOME/.config/complete-cicd-with-terraform"
key_file="$key_dir/jenkins-aws-key.json"
mkdir -p "$key_dir"
chmod 700 "$key_dir"
test ! -e "$key_file"
key_count="$(aws --profile default iam list-access-keys \
  --user-name jenkins-terraform-capstone --query 'length(AccessKeyMetadata)' --output text)"
test "$key_count" = "0"
aws --profile default iam create-access-key --user-name jenkins-terraform-capstone \
  --output json > "$key_file"
chmod 600 "$key_file"
```

For rotation, inspect ownership, deactivate the old key using its real ID, and create a replacement in a new file after checking key slots. IAM permits at most two keys per user. Never reactivate potentially exposed keys. The verified rotation left the old key Inactive and replacement Active; actual key identifiers are omitted here.

Template only (replace ID; do not run literally):

```bash
aws --profile default iam update-access-key --user-name jenkins-terraform-capstone \
  --access-key-id REPLACE_WITH_OLD_ACCESS_KEY_ID --status Inactive
```

Old `aws_ecr_creds` credentials from another project are separate and require their own review/rotation after an incident.

## 7. EC2 deployment SSH key and AMI — Mac

Generate a key distinct from the DigitalOcean operator key:

```bash
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
ssh-keygen -t ed25519 -C "gafari-terraform-capstone-ec2-clean" \
  -f "$HOME/.ssh/complete-cicd-with-terraform-ec2-clean"
ssh-keygen -lf "$HOME/.ssh/complete-cicd-with-terraform-ec2-clean.pub"
```

Choose a passphrase; do not overwrite existing keys. Historical public-key fingerprint: `SHA256:u5sjqhV6LzPZjC7COFGuH+G9D0y3AhZVatAZlH7OoLE`. New keys differ. Private keys are never supplied to Terraform.

Verify the regional Amazon-owned AMI before reuse:

```bash
aws --profile default --region ca-central-1 ec2 describe-images \
  --owners amazon --image-ids ami-0bf6dbeae330f5823 \
  --query 'Images[].{ImageId:ImageId,Name:Name,Architecture:Architecture,State:State,RootDeviceType:RootDeviceType}' \
  --output table
```

Recorded image: available Amazon Linux 2023 x86_64, EBS-backed. If unavailable for a future fresh deployment, an administrator can discover/verify a new regional AL2023 image and explicitly pin it in tfvars:

```bash
ami_id="$(aws --profile default --region ca-central-1 ssm get-parameter \
  --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
  --query Parameter.Value --output text)"
aws --profile default --region ca-central-1 ec2 describe-images --owners amazon \
  --image-ids "$ami_id" \
  --query 'Images[].{ImageId:ImageId,Name:Name,Architecture:Architecture,State:State}' --output table
```

The Jenkins policy does not include SSM discovery. Changing AMI on an existing instance can cause replacement; the pipeline rejects it. Do not make that change silently.


## 8. Fresh DigitalOcean host, restricted before startup

### 8.1 Operator SSH key and firewall — Mac/control panel

```bash
ssh-keygen -t ed25519 -C "gafari-jenkins-capstone-clean" \
  -f "$HOME/.ssh/jenkins-capstone-clean"
pbcopy < "$HOME/.ssh/jenkins-capstone-clean.pub"
curl -4 --fail --silent --show-error https://checkip.amazonaws.com
```

Choose a passphrase; upload only the public key to DigitalOcean Settings → Security → SSH Keys. Keep the private key on your Mac. A public key/fingerprint is not secret; a private key starts with `-----BEGIN OPENSSH PRIVATE KEY-----` and must be replaced if exposed.

Create a Cloud Firewall **before** the Droplet and apply it to tag `jenkins-capstone-clean`:

| Direction | Rule | Peer |
|---|---|---|
| Inbound | TCP 22 only | Current operator IPv4 `/32` |
| Outbound | Default ICMP, TCP, UDP | Retained for packages, registries, Git, AWS and EC2 SSH |

Remove public 3000, 8080–8083, 50000 and unrestricted SSH rules. Inspect all firewalls attached to the host; another permissive firewall can broaden allowed traffic. Broad outbound rules are an implementation limitation, not malware containment.

Create the Droplet from **Distributions → official Ubuntu 24.04 LTS**, x86_64, Basic 2 vCPU/4 GB RAM, the new SSH key only, hostname `jenkins-terraform-clean`, and the firewall tag. The verified host had about 80 GB disk. Review current pricing. Do not select a snapshot/Marketplace Jenkins image or restore an old volume. Verify the firewall is attached and applied before continuing. Historical new address: `159.203.63.2`.

### 8.2 Initial access/inventory — Mac, then root Droplet

```bash
ssh -o IdentitiesOnly=yes -i "$HOME/.ssh/jenkins-capstone-clean" root@159.203.63.2
```

Replace the IP for a different host. Verify host fingerprint through a trusted provider console where available before accepting it. On the server:

```bash
hostname
cat /etc/os-release
uname -m
free -h
df -h /
```

### 8.3 Update Ubuntu and UFW — Droplet root

```bash
set -euo pipefail
client_ip="${SSH_CONNECTION%% *}"
test -n "$client_ip"
printf 'Allowing SSH from: %s\n' "$client_ip"
cloud-init status --wait
apt-get update
apt-get upgrade -y
apt-get install -y ufw unattended-upgrades ca-certificates curl
ufw default deny incoming
ufw default allow outgoing
ufw allow from "$client_ip" to any port 22 proto tcp
ufw --force enable
ufw status verbose
ss -lntp
if [ -f /var/run/reboot-required ]; then
  cat /var/run/reboot-required
fi
```

If required, run `reboot`, wait, reconnect and verify `uname -r` and `ufw status verbose`. Verified kernel: `6.8.0-146-generic`. Installing unattended-upgrades alone does not prove the local schedule is enabled; inspect `/etc/apt/apt.conf.d/20auto-upgrades` and APT timers if automatic patching is required.

### 8.4 Non-root administrator — root Droplet

Keep the root session open and run this interactive command separately:

```bash
adduser gafari
```

Set a strong sudo password; optional profile fields can be blank. Then:

```bash
set -euo pipefail
usermod -aG sudo gafari
install -d -m 700 -o gafari -g gafari /home/gafari/.ssh
test -s /root/.ssh/authorized_keys
test ! -e /home/gafari/.ssh/authorized_keys
install -m 600 -o gafari -g gafari \
  /root/.ssh/authorized_keys /home/gafari/.ssh/authorized_keys
id gafari
```

Copy only trusted authorized public keys from this fresh root account. In a second Mac terminal:

```bash
ssh -o IdentitiesOnly=yes -i "$HOME/.ssh/jenkins-capstone-clean" gafari@159.203.63.2
```

In the new session:

```bash
whoami
sudo -v
sudo whoami
```

Expect `gafari`, then `root`. Only after that succeeds, restrict SSH.

### 8.5 Key-only SSH and no root login — Droplet as gafari

```bash
sudo bash <<'BASH'
set -euo pipefail
config="/etc/ssh/sshd_config.d/00-capstone-hardening.conf"
test ! -e "$config"
cat > "$config" <<'EOF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AuthenticationMethods publickey
AllowUsers gafari
EOF
chmod 644 "$config"
trap 'rm -f "$config"' ERR
/usr/sbin/sshd -t
effective="$(/usr/sbin/sshd -T)"
for setting in \
  "permitrootlogin no" "passwordauthentication no" \
  "kbdinteractiveauthentication no" "pubkeyauthentication yes" \
  "authenticationmethods publickey" "allowusers gafari"
do
  if ! printf '%s\n' "$effective" | grep -Fx "$setting"; then
    printf 'Expected SSH setting was not applied: %s\n' "$setting" >&2
    rm -f "$config"
    exit 1
  fi
done
systemctl reload ssh
trap - ERR
BASH
```

Test another fresh `gafari` connection and sudo before closing existing sessions. OpenSSH uses the first value for most settings; validate effective configuration, not only file content. Local sudo passwords remain enabled. If locked out, use the trusted DigitalOcean console/recovery process to correct SSH/UFW.

### 8.6 Install Docker — Droplet as gafari

```bash
sudo bash <<'BASH'
set -euo pipefail
apt-get update
apt-get install -y ca-certificates curl
install -m 0755 -d /etc/apt/keyrings
curl --fail --silent --show-error --location \
  https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
. /etc/os-release
cat > /etc/apt/sources.list.d/docker.sources <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: ${UBUNTU_CODENAME}
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
systemctl enable --now docker
docker version
docker buildx version
docker compose version
docker run --rm hello-world
ss -lntp
BASH
```

Verified Docker 29.9.0, Buildx 0.38.0, Compose 5.6.0. Future repository installs may differ. Use `sudo docker` for host administration; do not expose daemon TCP. Docker-published ports can bypass UFW; cloud rules and explicit loopback binding are required.

## 9. Official-image-based Jenkins controller

### 9.1 Copy only committed configuration — Mac

The initial directory creation requires a remote sudo prompt, hence `ssh -t`:

```bash
ssh -t -o IdentitiesOnly=yes -i "$HOME/.ssh/jenkins-capstone-clean" \
  gafari@159.203.63.2 \
  'sudo install -d -m 0755 -o gafari -g gafari /opt/jenkins-controller'
scp -o IdentitiesOnly=yes -i "$HOME/.ssh/jenkins-capstone-clean" \
  infrastructure/jenkins/Dockerfile infrastructure/jenkins/plugins.txt \
  infrastructure/jenkins/compose.yaml infrastructure/jenkins/base-image.txt \
  gafari@159.203.63.2:/opt/jenkins-controller/
```

Do not copy old snapshots, volumes, credentials, private keys, or `.env`. The committed Dockerfile defaults to the recorded official digest in `base-image.txt`; it does not depend on the previous custom image.

### 9.2 Build and test — Droplet as gafari

```bash
set -euo pipefail
cd /opt/jenkins-controller
sudo docker build --tag custom-jenkins:terraform-capstone-clean .
sudo docker run --rm --entrypoint bash custom-jenkins:terraform-capstone-clean -c '
set -euo pipefail
id
java -version
mvn --version
python3 --version
terraform version
aws --version
docker --version
docker compose version
command -v ssh-agent
command -v ssh-add
for plugin in workflow-aggregator pipeline-model-definition git credentials-binding ssh-agent maven-plugin; do
  test -f "/usr/share/jenkins/ref/plugins/${plugin}.jpi"
  printf "Plugin included: %s\n" "$plugin"
done
'
```

Verified versions: Jenkins 2.580.1, JDK 21.0.12.1, Maven 3.9.9, Python 3.13.5, Terraform 1.15.6, AWS CLI 2.36.49, Docker CLI 29.9.0, Compose 5.6.0. All six requested plugins were included. Terraform's update notice is informational. The archive preserves the exact base digest and CLI versions, but apt/plugin resolutions are unpinned; future builds need revalidation.

### 9.3 New volume and loopback startup — Droplet

First creation only:

```bash
set -euo pipefail
cd /opt/jenkins-controller
if sudo docker volume inspect jenkins_terraform_clean_home >/dev/null 2>&1; then
  printf 'Volume exists; review its provenance before startup.\n'
  exit 1
fi
socket_group="$(stat -c '%g' /var/run/docker.sock)"
printf 'DOCKER_GID=%s\n' "$socket_group" > .env
sudo docker compose config --quiet
sudo docker compose up -d
```

Routine restarts reuse this known-clean volume with `sudo docker compose up -d`; do not rerun the first-creation guard. Detect socket GID rather than copying example 987 to another server.

Wait for Jenkins to respond:

```bash
set -euo pipefail
ready=false
for attempt in $(seq 1 60); do
  status="$(curl --silent --output /dev/null --max-time 3 --write-out '%{http_code}' \
    http://127.0.0.1:8080/login || true)"
  case "$status" in
    200|302|403) ready=true; break ;;
  esac
  sleep 3
done
test "$ready" = true
sudo docker compose ps
sudo docker port jenkins
sudo docker exec jenkins bash -c '
set -euo pipefail
id
docker info --format "Docker server: {{.ServerVersion}}"
'
sudo ss -lntp
```

Expect only `8080/tcp -> 127.0.0.1:8080`; no host port 50000 is mapped. Jenkins runs non-root with the socket's supplementary GID. That socket enables host-level actions even with no-new-privileges; all controller administrators and pipeline code must be trusted.

### 9.4 SSH tunnel and UI setup — Mac/browser

Leave a separate Mac terminal running:

```bash
ssh -N -o IdentitiesOnly=yes -o ExitOnForwardFailure=yes \
  -i "$HOME/.ssh/jenkins-capstone-clean" \
  -L 127.0.0.1:18081:127.0.0.1:8080 gafari@159.203.63.2
```

Open `http://127.0.0.1:18081/`. Privately retrieve unlock password on the Droplet:

```bash
sudo docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

Do not share that output. Complete the wizard and create a new strong admin account (verified username `admin`). Configure the tunnel URL for this access method. Required plugins are already baked in; installing suggested plugins may add others. Do not disable authentication or CSRF protection. Verify anonymous users cannot administer or build.

Manage Jenkins → Tools → Maven installations:

| Setting | Value |
|---|---|
| Name | `Maven` (case-sensitive) |
| Install automatically | Unchecked |
| MAVEN_HOME | `/usr/share/maven` |

Save. JDK 21 builds Java 17 target bytecode; the app runs Corretto 17. The POM's source/target configuration produces a modules-path warning; a future `release=17`/UTF-8 refinement is not part of the archived code. For Git tool warnings, configure `Default` with executable `/usr/bin/git`; observed checkout succeeded via the default binary.

## 10. Application inputs and all five Jenkins credentials

### 10.1 Local tfvars/backend — Mac

Use the actual fresh Jenkins address; this command uses the recorded one. Generate inputs with the new public key and both approved /32 IPs:

```bash
set -euo pipefail
umask 077
cd "$HOME/Documents/tech-workspace/devops-capstone-projects/complete-cicd-with-terraform"
jenkins_host="159.203.63.2"
public_key="$HOME/.ssh/complete-cicd-with-terraform-ec2-clean.pub"
test -s "$public_key"
mac_ip="$(curl -4 --fail --silent --show-error --connect-timeout 5 --max-time 15 \
  https://checkip.amazonaws.com)"
python3 - "$jenkins_host" "$mac_ip" "$public_key" <<'PY'
from pathlib import Path
import ipaddress
import json
import sys
jenkins = str(ipaddress.IPv4Address(sys.argv[1]))
operator = str(ipaddress.IPv4Address(sys.argv[2].strip()))
key = Path(sys.argv[3]).read_text().strip()
if not key.startswith("ssh-ed25519 ") or "\n" in key or "\r" in key:
    raise SystemExit("Unexpected public key format.")
cidrs = list(dict.fromkeys([f"{jenkins}/32", f"{operator}/32"]))
content = f'''aws_region          = "ca-central-1"
expected_account_id = "002184382122"
project_name        = "complete-cicd-with-terraform"
ami_id              = "ami-0bf6dbeae330f5823"
instance_type       = "t3.micro"
ssh_public_key = {json.dumps(key)}
ssh_allowed_cidrs = {json.dumps(cidrs)}
app_allowed_cidrs = {json.dumps(cidrs)}
'''
p = Path("terraform/local.auto.tfvars")
p.write_text(content)
p.chmod(0o600)
print("Approved EC2 access:", ", ".join(cidrs))
PY
cat > terraform/backend.local.hcl <<'EOF'
bucket       = "gafari-tf-cicd-002184382122-ca-central-1"
key          = "complete-cicd-with-terraform/application/terraform.tfstate"
region       = "ca-central-1"
encrypt      = true
use_lockfile = true
EOF
chmod 600 terraform/backend.local.hcl
terraform -chdir=terraform fmt
git check-ignore terraform/local.auto.tfvars terraform/backend.local.hcl
git status --short --branch
```

These local files contain no AWS secret, but remain ignored environment inputs. The committed examples contain placeholder key/empty lists; do not deploy them unchanged. Empty lists are syntactically valid but block deployment/testing connections. Updating a local file does not update the uploaded Jenkins Secret file.

### 10.2 Docker Hub

Create `younghadiz/complete-cicd-with-terraform`. Visibility can be public or private; authenticated pulls are supported. A Docker Desktop image is local until pushed. Generate a project PAT with Read and Write permission in Docker account settings → Personal access tokens. Use a replacement for any revoked/exposed token.

### 10.3 Credentials — Jenkins UI through the tunnel

Manage Jenkins → Credentials → System → Global credentials → Add Credentials. All IDs must match exactly:

| ID | Kind | Value |
|---|---|---|
| `terraform-cicd-dockerhub` | Username with password | Username younghadiz; password Docker Hub Read/Write PAT |
| `terraform-cicd-aws` | Username with password | Username IAM access key ID; password IAM secret access key |
| `terraform-cicd-ec2-ssh` | SSH Username with private key | ec2-user; Enter directly; EC2 private key and passphrase |
| `terraform-cicd-tfvars` | Secret file | Completed local.auto.tfvars |
| `terraform-cicd-backend` | Secret file | backend.local.hcl |

Use Global scope. The AWS credential must be Username with password, matching `usernamePassword` in Jenkinsfile, not another plugin's AWS kind. The SSH key is the EC2 deployment key, not the DigitalOcean operator key. In a Mac file picker, Cmd+Shift+G accepts a path.

Copy the private key directly to Jenkins, then clear the clipboard:

```bash
pbcopy < "$HOME/.ssh/complete-cicd-with-terraform-ec2-clean"
```

After saving:

```bash
printf '' | pbcopy
```

For the private AWS JSON from Section 6, copy each field separately without displaying it:

```bash
python3 -c 'import json,pathlib; print(json.loads((pathlib.Path.home()/".config/complete-cicd-with-terraform/jenkins-aws-key.json").read_text())["AccessKey"]["AccessKeyId"],end="")' | pbcopy
```

Paste Username, then:

```bash
python3 -c 'import json,pathlib; print(json.loads((pathlib.Path.home()/".config/complete-cicd-with-terraform/jenkins-aws-key.json").read_text())["AccessKey"]["SecretAccessKey"],end="")' | pbcopy
```

Paste Password, save, clear clipboard. If rotating with filename `jenkins-aws-key-replacement.json`, use that filename consistently. AWS keys, Docker PATs and Jenkins API tokens are different credentials. Keep every private file outside the repository and protect Jenkins volume backups.

## 11. Dedicated-user preflight — Mac

Run from repository root. `key_name` must match Section 6 (recorded rotation used the replacement filename). This loads secrets privately into subprocesses, checks exact identity, initializes the same backend, and plans only:

```bash
python3 <<'PY'
import json
import os
from pathlib import Path
import subprocess
key_name = "jenkins-aws-key.json"
key_file = Path.home() / ".config/complete-cicd-with-terraform" / key_name
key = json.loads(key_file.read_text())["AccessKey"]
env = os.environ.copy()
for name in (
    "AWS_PROFILE", "AWS_DEFAULT_PROFILE", "AWS_SESSION_TOKEN",
    "AWS_SECURITY_TOKEN", "AWS_ROLE_ARN", "AWS_WEB_IDENTITY_TOKEN_FILE",
):
    env.pop(name, None)
env.update({
    "AWS_ACCESS_KEY_ID": key["AccessKeyId"],
    "AWS_SECRET_ACCESS_KEY": key["SecretAccessKey"],
    "AWS_SHARED_CREDENTIALS_FILE": "/dev/null",
    "AWS_CONFIG_FILE": "/dev/null",
    "AWS_REGION": "ca-central-1", "AWS_DEFAULT_REGION": "ca-central-1",
    "AWS_PAGER": "", "TF_IN_AUTOMATION": "true",
})
result = subprocess.run(
    ["aws", "sts", "get-caller-identity", "--output", "json"],
    env=env, capture_output=True, text=True, check=True,
)
identity = json.loads(result.stdout)
expected = "arn:aws:iam::002184382122:user/jenkins-terraform-capstone"
if identity["Account"] != "002184382122" or identity["Arn"] != expected:
    raise SystemExit("Unexpected AWS identity; Terraform was not run.")
print(json.dumps({"Account": identity["Account"], "Arn": identity["Arn"]}, indent=2), flush=True)
for command in [
    ["terraform", "-chdir=terraform", "init", "-input=false", "-lockfile=readonly",
     "-reconfigure", "-backend-config=backend.local.hcl"],
    ["terraform", "-chdir=terraform", "validate"],
    ["terraform", "-chdir=terraform", "plan", "-input=false", "-lock-timeout=5m",
     "-out=application-preflight.tfplan"],
]:
    subprocess.run(command, env=env, check=True)
print("Preflight complete. No Terraform apply was performed.")
PY
```

Fresh state with two CIDRs in each set gives **14 creates**: ten base resources plus two SSH and two application ingress rules. Review AMI, account, region, t3.micro, encrypted 10 GiB gp3, IMDSv2, approved IPs and bootstrap. Subnet default automatic public-IP assignment is false; the app instance explicitly requests a public IPv4.

Planning checks backend/read/lock permissions, not every creation permission. **Do not apply this Mac preflight plan.** Jenkins generates/applies its own plan after image publication. Delete stale ignored plans when no longer needed; they contain configuration and may contain sensitive values.

## 12. Job configuration, validation and deployment

### 12.1 Declarative validation — Mac, optional for future edits

The Jenkinsfile passed the Declarative validator during implementation and executed twice on fresh Jenkins 2.580.1. To validate an edit, generate a Jenkins API token from your user profile Configure/Security → API Token. With the SSH tunnel open, in Bash at repository root:

```bash
read -r -p "Jenkins username: " jenkins_username </dev/tty
curl --fail --silent --show-error --user "$jenkins_username" \
  --form 'jenkinsfile=<Jenkinsfile' \
  http://127.0.0.1:18081/pipeline-model-converter/validate
printf '\n'
```

When curl asks for password, paste the API token privately. API-token authentication does not need a CSRF crumb. Use the tunnel, not public HTTP. Expected: `Jenkinsfile successfully validated.` This validates syntax/structure, not external permissions.

### 12.2 Create the job — Jenkins

New Item → `complete-cicd-with-terraform` → **Pipeline** → OK. Leave all build triggers unchecked:

| Setting | Value |
|---|---|
| Definition | Pipeline script from SCM |
| SCM | Git |
| Repository URL | https://github.com/younghadiz/complete-cicd-with-terraform.git |
| Credentials | None for this public repository |
| Branch Specifier | `*/feature/terraform-cicd` |
| Script Path | `Jenkinsfile` |
| Lightweight checkout | Checked |

Save. A private fork needs a separate restricted repository-read credential. This is a single Pipeline job, not a Multibranch job. No webhook was verified; a public Git service cannot directly reach a localhost-only UI. If automatic builds are later needed, design polling or a secured ingress separately rather than reopening public 8080.

### 12.3 Run once, inspect, then repeat once

Click **Build Now once** and inspect Console Output. This publishes an image and applies billable AWS resources. The eight named stages are in the full Jenkinsfile in Appendix A.

The pipeline pins provider 6.67.0 via lock file, plans to `terraform/application.tfplan`, checks JSON for any `delete` action (including replacement), then applies the saved plan. Creation and in-place updates proceed automatically; there is no manual approval gate. Terraform outputs are written to `target/terraform-outputs.json`. Temporary plan/JSON files are removed by traps. Credentials are bound by exact IDs and are not put in source/backend files.

The host-key helper confirms the EC2 instance's public address, reads ED25519 only inside cloud-init's host-key block from authenticated AWS console output, validates encoding, rejects conflicting keys and writes known_hosts mode 0600. SSH uses StrictHostKeyChecking=yes and that file. Do not substitute unauthenticated ssh-keyscan as proof of identity.

EC2 bootstrap installs Docker, checksum-verifies pinned Compose v2.39.4, configures log rotation, grants Docker access to ec2-user, creates `/opt/complete-cicd-with-terraform`, starts Docker and sets `/var/lib/capstone/bootstrap-ready` only after checks. Jenkins waits for marker/daemon/Compose/writable directory, transfers the Compose file/script, and sends the Docker PAT on SSH stdin.

The script uses a private temporary registry configuration, pulls the exact recorded digest, starts Compose, checks homepage/image/running state, and removes the temporary config on exit. Jenkins fetches EC2 `/` externally and compares it byte for byte with the source HTML. It archives `target/*.jar` and `target/published-image.txt`, fingerprints them, and removes build image tags locally; registry images remain published.

### 12.4 Verified results

Build #1:

```text
Application commit: ec97d3ef64fb336db647cf51a781f3bc94be76c1
Terraform: 14 added, 0 changed, 0 destroyed
Instance: i-063e9387fb8155c11
Application: http://3.99.49.109:8080/
Tag: younghadiz/complete-cicd-with-terraform:ci-ec97d3ef64fb-1
Digest: sha256:1fe6e1566e4561b9ea564aa368794f2be97e58f7fe0907ac3190d58754c948d2
Finished: SUCCESS
```

Independent Mac verification (actual address from outputs):

```bash
set -euo pipefail
curl --fail --silent --show-error --connect-timeout 5 --max-time 30 \
  http://3.99.49.109:8080/ -o target/ec2-homepage-check.html
cmp src/main/resources/static/index.html target/ec2-homepage-check.html
printf 'PASS: EC2 homepage exactly matches the source HTML.\n'
```

Trigger build #2 once after the first success. Recorded result:

```text
No changes. Your infrastructure matches the configuration.
Terraform: 0 added, 0 changed, 0 destroyed
Instance: i-063e9387fb8155c11 (unchanged)
Application: http://3.99.49.109:8080/ (unchanged)
Tag: younghadiz/complete-cicd-with-terraform:ci-ec97d3ef64fb-2
Digest: sha256:fc90198a427321a723843b967365715789ef3287db230a0476b6a2b20d6006aa
Compose: container recreated for new digest
External homepage comparison: PASS
Finished: SUCCESS
```

Rebuilt unchanged source can have different digests due to archive timestamps/build metadata. The verified property is deployment of that build's exact digest, not byte-identical rebuilds. Infrastructure outputs/raw plan JSON are not archived by the committed pipeline.

### 12.5 Evidence, docs and branches — Mac

Download successful console logs and archived JAR/digest. Capture the successful pipeline/application page if portfolio evidence is needed, and review screenshots/logs for secrets. Never publish Jenkins volume/state backups.

Place README.md at the project root and RUNBOOK.md in docs/, review and commit:

```bash
git diff --check
git add README.md docs/RUNBOOK.md
git diff --cached --stat
git commit -m "docs: document verified Terraform CI/CD implementation"
git push origin feature/terraform-cicd
git push gitlab feature/terraform-cicd
git status --short --branch
```

Optional release following existing branch conventions, after review, remote freshness checks and a clean tree:

```bash
git switch develop
git merge --no-ff feature/terraform-cicd -m "feat: integrate verified Terraform CI/CD capstone"
git push origin develop
git push gitlab develop
git switch main
git merge --no-ff develop -m "feat: release verified Terraform CI/CD capstone"
git push origin main
git push gitlab main
```

These release merges were not executed in the reviewed evidence. Do not force-push or overwrite remote work. Changing the job to `*/main` is a separate explicit setting. Do not run duplicate deploy jobs against one state simultaneously; disableConcurrentBuilds is per job, while the S3 lock protects a Terraform operation rather than the entire pipeline.

## 13. Operations and troubleshooting

### 13.1 Routine operations

| Task | Procedure |
|---|---|
| Deploy change | Push job branch; run one build; verify digest and final HTTP result |
| Operator IP changed | Update DO firewall/UFW; update tfvars and replace Jenkins uploaded file; review plan |
| Jenkins host IP changed | Update EC2 ingress tfvars credential before deploying; update access settings |
| Restart controller | Droplet: cd /opt/jenkins-controller; sudo docker compose restart jenkins |
| Inspect controller | sudo docker compose ps; sudo docker port jenkins; tool/socket checks |
| Change AMI/key/user_data | Review replacement; expect guard to reject it; plan explicit maintenance |
| Local Terraform | Exact trusted identity/backend; Jenkins idle; plan before apply |

EC2 binds app port on 0.0.0.0 but security-group ingress restricts access. HTTP is for this restricted demonstration, not a production TLS endpoint. A single-container deployment interrupts service briefly; there is no automated rollback or blue/green rollout.

### 13.2 Common symptoms

| Symptom | Check/resolution |
|---|---|
| Mac Docker socket missing | Start Desktop and wait for docker info |
| Java missing in bash -lc | Login-shell PATH changed; use bash -c and inspect JAVA_HOME |
| Maven tool not found | Exact name Maven; /usr/share/maven; auto-install off |
| Git tool warning | Set Default executable /usr/bin/git; warning alone did not stop checkout |
| Cannot open Jenkins | Tunnel closed/port occupied/stale SSH IP; verify ExitOnForwardFailure and cloud rules |
| Docker permission denied in Jenkins | Detect socket GID, update host .env, recreate controller preserving clean volume |
| First probe connection refusals | Startup retries expected; final failure requires logs |
| CI localhost HTTP wrong | VERIFY_METHOD=container required for socket-based Jenkins |
| Docker Hub denied | Namespace/username assertions, repo existence, PAT Read/Write, exact credential ID |
| Login unencrypted-config warning | Temporary CLI config; check private directory/cleanup traps; masking remains required |
| AWS InvalidClientTokenId | Inactive/wrong key or unexpected session/profile; verify identity, rotate/rebind |
| S3/lock AccessDenied | Backend/policy ARNs agree; tflock needs Get/Put/Delete; do not grant broad admin |
| EC2 API AccessDenied | Inspect denied action/CloudTrail, minimally review live policy change, re-plan partial apply |
| State locked | Confirm no writer remains; inspect lock owner/ID; force-unlock only after that check |
| Deletion/replacement rejected | Investigate changed AMI/key/user_data; do not remove guard blindly |
| Host key unavailable | Console/cloud-init lag or GetConsoleOutput permission; never bypass trust check |
| SSH timeout | Actual host IP, Jenkins /32, SG, routes/IGW, instance checks and bootstrap |
| SSH publickey denied | Public/private mismatch, ec2-user username or wrong passphrase |
| No bootstrap marker | dnf/curl/checksum/Docker failure; inspect bootstrap/cloud-init logs |
| External HTTP timeout | Actual uploaded allowlist/source IP and container port |
| Homepage mismatch | Digest/source mismatch or stale content; investigate before relaxing comparison |
| Disk full | df/docker system df; reviewed unused images/logs; never global volume prune |

After failed apply, some resources may already exist and be in state. Keep the same backend, fix the cause and inspect a fresh plan. Do not delete state, choose a new key/workspace, or routinely use -target to bypass failures.

### 13.3 Verified-key EC2 diagnostics — Mac, then EC2

Use trusted AWS credentials able to read the same application backend and EC2 console:

```bash
set -euo pipefail
mkdir -p target
instance_id="$(terraform -chdir=terraform output -raw instance_id)"
app_host="$(terraform -chdir=terraform output -raw instance_public_ip)"
export AWS_REGION="ca-central-1"
export AWS_DEFAULT_REGION="$AWS_REGION"
python3 scripts/ec2_known_hosts.py --instance-id "$instance_id" --host "$app_host" \
  --output target/ec2-known-hosts
ssh -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes \
  -o "UserKnownHostsFile=$PWD/target/ec2-known-hosts" -o HostKeyAlgorithms=ssh-ed25519 \
  -i "$HOME/.ssh/complete-cicd-with-terraform-ec2-clean" "ec2-user@$app_host"
```

On EC2:

```bash
sudo cloud-init status --long
sudo tail -n 100 /var/log/capstone-bootstrap.log
sudo systemctl status docker --no-pager
docker ps
docker logs --tail 100 complete-cicd-with-terraform-java-maven-app-1
docker inspect --format '{{.Config.Image}}' complete-cicd-with-terraform-java-maven-app-1
curl --fail --silent --show-error http://127.0.0.1:8080/
```

These are operations diagnostics, not extra checks needed by the two successful builds. Review output before sharing.

### 13.4 Manual image rollback — documented, not tested

Use the archived digest from a successful known-good build. Verify it remains in Docker Hub and coordinate with Jenkins: the next build redeploys its own digest. Rollback does not change Terraform. Public image example on EC2:

```bash
bash /opt/complete-cicd-with-terraform/server-cmds.sh \
  'younghadiz/complete-cicd-with-terraform@sha256:1fe6e1566e4561b9ea564aa368794f2be97e58f7fe0907ac3190d58754c948d2'
```

Private images require token stdin and registry username as in the pipeline. Compare the homepage against the rollback image's corresponding source, which may differ from the latest checkout. No automated rollback was implemented.

### 13.5 Backups and incident recovery

Preserve repository, build evidence, private bootstrap state and protected backups of the known-clean Jenkins volume. A Jenkins volume includes both encrypted credentials and decryption keys; backups must not be public. An offline backup requires stopping Jenkins, archiving the known-clean volume through a trusted helper/container to a private destination, restarting, and securely transferring/encrypting the archive. Test restore separately; no Jenkins volume restore was verified here.

S3 versions retain old application state. State restoration requires all writers stopped and deliberate comparison of lineage/serial and real resources. Do not overwrite state to bypass a failed plan.

DigitalOcean reported the earlier restored Droplet 159.203.44.3 sending DDoS traffic (ticket 12891341). It was replaced with the fresh-host method and credentials were rotated. The entry point, compromise time, and old snapshot's safety were not established; no evidence established a chat leak as cause. New SSH keys alone do not clean a restored snapshot.

For suspected compromise: stop builds, contain/power off via provider, revoke all possibly present credentials (including prior-project Git/cloud/SSH credentials), review cloud audit/resource activity, preserve required evidence through trusted recovery, and rebuild from fresh OS/volume. Firewall/password changes alone do not remove malware. Never boot suspect backups as trusted recovery. Powered-off DO Droplets remain billable.

## 14. Explicit teardown and cost verification — not yet executed

Do not run this section until finished with the demonstration and evidence is saved. Cleanup was not performed in the reviewed session. It intentionally separates the application from its protected state storage.

### 14.1 Stop writers and preserve evidence

Disable the Jenkins job or otherwise prevent builds and confirm none is running. Download JAR/digest/console evidence. Retain committed source and private bootstrap state. Do not delete state/bucket before application destruction.

### 14.2 Plan application destroy — Mac trusted administrator

Use the recorded default profile only if still trusted. Never reactivate incident keys. Clear conflicting credential/session environment variables and verify account:

```bash
set -euo pipefail
umask 077
cd "$HOME/Documents/tech-workspace/devops-capstone-projects/complete-cicd-with-terraform"
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_SECURITY_TOKEN
unset AWS_ROLE_ARN AWS_WEB_IDENTITY_TOKEN_FILE
export AWS_PROFILE="default"
export AWS_REGION="ca-central-1"
export AWS_DEFAULT_REGION="$AWS_REGION"
aws sts get-caller-identity --query '{Account:Account,Arn:Arn}' --output json
test "$(aws sts get-caller-identity --query Account --output text)" = "002184382122"
terraform -chdir=terraform init -input=false -lockfile=readonly \
  -reconfigure -backend-config=backend.local.hcl
terraform -chdir=terraform state list
mkdir -p "$HOME/.config/complete-cicd-with-terraform/state-backups"
chmod 700 "$HOME/.config/complete-cicd-with-terraform/state-backups"
terraform -chdir=terraform state pull \
  > "$HOME/.config/complete-cicd-with-terraform/state-backups/application-before-destroy.json"
terraform -chdir=terraform plan -destroy -input=false -lock-timeout=5m \
  -out=application-destroy.tfplan
```

Review **0 add, 0 change, 14 destroy** for this unchanged deployment. All resources must be application addresses; bucket must not be included. Verify exact backend/workspace. Stop on unexpected inventory. Before applying, record the EC2 root volume ID for later deletion verification:

```bash
aws --profile default --region ca-central-1 ec2 describe-instances \
  --instance-ids i-063e9387fb8155c11 \
  --query 'Reservations[].Instances[].BlockDeviceMappings[].Ebs.VolumeId' --output text
```

Only after review, apply the saved destroy plan:

```bash
terraform -chdir=terraform apply -input=false -lock-timeout=5m application-destroy.tfplan
terraform -chdir=terraform state list
```

Expect no application resource addresses. Empty state ordinarily remains in S3. The Jenkins guard intentionally prevents destroy through the deployment pipeline; teardown is a separate operator procedure.

### 14.3 Verify application removal

Historical IDs below must be adapted to current outputs:

```bash
aws --profile default --region ca-central-1 ec2 describe-instances \
  --instance-ids i-063e9387fb8155c11 \
  --query 'Reservations[].Instances[].{Id:InstanceId,State:State.Name}' --output table
aws --profile default --region ca-central-1 ec2 describe-vpcs \
  --filters Name=tag:Project,Values=complete-cicd-with-terraform \
  --query 'Vpcs[].VpcId' --output json
aws --profile default --region ca-central-1 ec2 describe-key-pairs \
  --filters Name=key-name,Values=complete-cicd-with-terraform-deployment \
  --query 'KeyPairs[].KeyName' --output json
```

Expect terminated instance (eventually not found), no project VPC/key pair. Query the **recorded root volume ID** with describe-volumes; not found after eventual deletion confirms removal. An empty attachment filter alone does not prove no detached volume exists. Root EBS is configured delete-on-termination. Inspect billing/resource inventory for other unexpected resources separately.

### 14.4 Retain backend by default; optional full bucket teardown

Keep S3 bucket/bootstrap state unless complete deletion is explicitly needed. The bucket has `prevent_destroy=true`, `force_destroy=false`; application destroy does not touch it. Preserve required versions privately.

Optional complete teardown requires: application state empty, builds disabled, no other bucket users, administrator identity, and secure state/version backups. In a reviewed maintenance checkout, deliberately set only the bootstrap bucket's prevent_destroy to false. Do not remove the whole resource block to evade the guard. Then plan separately:

```bash
terraform -chdir=bootstrap/backend init -input=false -lockfile=readonly
terraform -chdir=bootstrap/backend plan -destroy -input=false -out=backend-destroy.tfplan
```

Expect exactly the five backend resources to be destroyed. Empty all **versions and delete markers** in the confirmed bucket through S3 console/reviewed procedure; `aws s3 rm --recursive` alone does not empty a versioned bucket. Only after validating the bucket is empty and plan scope:

```bash
terraform -chdir=bootstrap/backend apply -input=false backend-destroy.tfplan
```

Verify bucket absence with an administrator and keep the private historical state backup as needed. No automatic bulk version-deletion script is provided; this avoids accidental state-history loss. The normal source should retain protection. Full bucket teardown is not a verified result of this project.

### 14.5 Jenkins/credentials/provider cleanup

After evidence and application teardown:

1. Droplet: `cd /opt/jenkins-controller` then `sudo docker compose down`. Do not add `-v` unless deliberately deleting Jenkins data.
2. Destroy the exact fresh Droplet through DigitalOcean after confirming name/IP and preservation. Power off alone does not end billing.
3. Review separately billed snapshots, backups, volumes and reserved addresses; remove only those no longer needed. Suspect evidence must not be booted as trusted.
4. Remove unused firewall/tag/operator key only if no other host uses them.
5. Revoke project Docker PAT and AWS access key when no automation needs them. Delete the dedicated IAM user/policy only after ensuring not shared and backend cleanup is finished.
6. Registry images may remain as portfolio artifacts. Deleting local image tags does not delete Docker Hub images; registry deletion is separate.

For the project IAM key, inspect actual metadata and deactivate/delete only the intended key through IAM. Remove attached policies before deleting a user; do not delete shared policies. Private workstation keys/state backups require deliberate disposal according to future needs. Avoid global Docker volume pruning or deleting the repository as a cleanup shortcut.

## 15. Primary references and limitations

- Jenkins Docker: https://www.jenkins.io/doc/book/installing/docker/
- Official image: https://github.com/jenkinsci/docker
- Pipeline from SCM: https://www.jenkins.io/doc/book/pipeline/getting-started/
- Pipeline validator: https://www.jenkins.io/doc/book/pipeline/development/
- Credentials: https://www.jenkins.io/doc/book/using/using-credentials/
- SSH Agent: https://plugins.jenkins.io/ssh-agent/
- Jenkins secret storage: https://www.jenkins.io/doc/developer/security/secrets/
- Docker Ubuntu/UFW: https://docs.docker.com/engine/install/ubuntu/
- Docker exec: https://docs.docker.com/reference/cli/docker/container/exec/
- Docker PATs: https://docs.docker.com/security/access-tokens/
- Terraform binary verification: https://developer.hashicorp.com/terraform/tutorials/cli/verify-archive
- S3 backend/locking: https://developer.hashicorp.com/terraform/language/backend/s3
- Terraform lifecycle: https://developer.hashicorp.com/terraform/language/meta-arguments/lifecycle
- AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html
- IAM keys: https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html
- Ubuntu OpenSSH: https://ubuntu.com/server/docs/how-to/security/openssh-server/
- DO firewall tags: https://docs.digitalocean.com/products/networking/firewalls/details/features/
- DO DDoS recovery: https://docs.digitalocean.com/support/my-droplet-is-sending-an-outgoing-flood-or-ddos/
- DO destruction: https://docs.digitalocean.com/products/droplets/how-to/destroy/

This working capstone is not a complete production platform. Limits include controller Docker privilege, region-wide EC2 policy scope, static IAM keys, broad egress, one instance/container, service interruption, no automated rollback/TLS/monitoring, no committed application tests, unpinned OS/plugin/app-base resolution, and no demonstrated backup restore/teardown. Document and test future improvements separately rather than claiming they are implemented.

## Appendix A. Complete archived implementation

All 36 files below are verbatim from source commit `b87ac5d96a24e141202bd9e565260a8c2e7c36cd`. SHA-256 identifies exact bytes. The appendix excludes ignored private keys, credentials, state, plans, local tfvars/backend settings and the newly generated documentation. Recreate listed relative paths if reconstructing without Git; restore executable shell-script permissions as in Section 3.

| File | SHA-256 |
|---|---|
| `.dockerignore` | `318a7e9f5fbbcf68baa3d2bfe8fb0c877e228d29b0379fb3dd6dc05175522702` |
| `.gitignore` | `cbc91a83743d45a31b76ff3254d9b926a5d6a6a50030a16d7924b84ac7c3668c` |
| `Dockerfile` | `b6f883e0be3acd02cad2394dfc466ca5c4d1427f779568b395ce18fb5aa893ce` |
| `Jenkinsfile` | `90e05320d8d018df130555a6ebdbc5ede3468ed52a10c5d3e6c2323b59ff1511` |
| `SOURCES.md` | `a3cd62559203003510bd97bbd1060d9f093683280a6862451a8855746634faff` |
| `bootstrap/backend/.terraform.lock.hcl` | `74387162325cd88bdc9551821273c717501f7aedee0d70f221bd65f7fe470c93` |
| `bootstrap/backend/main.tf` | `65e035312e44484a3b9eeb4b9cc0629faec423d3fa913b53363249650e66b751` |
| `bootstrap/backend/outputs.tf` | `34d75a955764a422a8497b3ca7f3ceb94067cdb399b48ad8e59f6e2feb627e29` |
| `bootstrap/backend/providers.tf` | `a052a8b52935c7a9b66b799b80eba4172a8d0b0888611298ec3798887efa5a2d` |
| `bootstrap/backend/variables.tf` | `89f0d36363a35153944e19651dba9addbb6f42d409f54a3d6cf12d56e53d6d53` |
| `bootstrap/backend/versions.tf` | `bac9f9351b731959b931f5c3c3747a0e184cdecd1030abed39257523f68cbeee` |
| `docker-compose.yaml` | `12dd38a84b719a248e6c949c011f100e3b1a8db40c245546dd49e3da261bb8ff` |
| `iam/jenkins-terraform-policy.json` | `60a0c30f2cb230b9b886b85cb96fcc63008a0bed604e4760adc50109de115a12` |
| `infrastructure/jenkins/.env.example` | `4c1aaa108d781dd0e96d2470716de3812a434c97ef2903b12d30dc9f739e7f77` |
| `infrastructure/jenkins/Dockerfile` | `3b8f08957ed1f58557c6cf695476a42cdbb9cfa6e08d474fd784616193a34ded` |
| `infrastructure/jenkins/base-image.txt` | `34e18aa801ccbebeddcdfc7d552424aa4138e912d3496f2145f6c780829b500d` |
| `infrastructure/jenkins/compose.yaml` | `34cc586962b6e07e1af5f2c6904203ebda93cdd4e85f2a64632831edcd854251` |
| `infrastructure/jenkins/plugins.txt` | `acac2d00928084af6fd184df6c1e7d6b73336bd7953a82750302f504e4a61794` |
| `pom.xml` | `d82292c6f4ea75e35555c59ce3782c780249c1aeecbddd18945cb299a51019cb` |
| `scripts/ec2_known_hosts.py` | `4765db68ca4b418569c2c459ebd242e9fa5827b53b239ca6b1ab013835fe2e31` |
| `server-cmds.sh` | `6fb0025e4b2e121c603ece08f18e54808e000b5f3905d7461d0976af527508a9` |
| `src/main/java/com/example/Application.java` | `b3abe95803c452d0b9b512d6f3b8ba86026037422d2e69a00959221b0fdc413b` |
| `src/main/resources/static/index.html` | `d3f934e7c81a00ef8a04e036653954b3cb92b2e9a592c9ea005c02f8b96b9e43` |
| `terraform/.terraform.lock.hcl` | `74387162325cd88bdc9551821273c717501f7aedee0d70f221bd65f7fe470c93` |
| `terraform/access-variables.tf` | `7601b850ac363f39c3d15a78ede9a650b2734484408d8278b263706a5af92b26` |
| `terraform/access.tf` | `5d0145f51ccdd63122438da33e8083dc74b60a66056b1afad91ac19656d22ba0` |
| `terraform/backend.example.hcl` | `ae0ab8791b9c7d216a7994597ea7f1bea5e41f8a02676b530e0518b0df59730e` |
| `terraform/compute-variables.tf` | `af3509790c9cae83aea906e7337b9ba2257099d609b093d94298073f17db4f42` |
| `terraform/compute.tf` | `45bf72250c3e908829121f356d30c87dfc5d484ac46a73068b1b990a957f20f4` |
| `terraform/network.tf` | `43305223b6aea09375d2808b2cde5af1254ed49b591a09dec5751c77ee7deeb1` |
| `terraform/outputs.tf` | `01c77f21569322335bbddc36bddb9a2856c71fc3231931abd2db37a8f7c2a62b` |
| `terraform/providers.tf` | `21e1d1d915d84f34627317c3f9a2e7d275737955371bb263eab2b65bd06a027b` |
| `terraform/scripts/bootstrap.sh` | `4063c6ce1cb5ca9c07a2409808de584c0ad4a3a4872072f40e64c91a223985b0` |
| `terraform/terraform.example.tfvars` | `070230555b5a1c1b2a695ea0b93a9ac14ad579a29104e2f5b8feca8dd276f7d3` |
| `terraform/variables.tf` | `eabafa3d4441a9758486e3f7eda675adfbed664bb8712e33091853483e55ccec` |
| `terraform/versions.tf` | `7fc270f8d7b9172eb27cb7c651ec8063044b6e6451a677ec3b40da05816ed146` |

### A.1. .dockerignore

```
**
!Dockerfile
!target/
!target/java-maven-app-*.jar
```

### A.2. .gitignore

```
# Editors and macOS
.idea/
.vscode/
.DS_Store

# Maven build output
target/

# Terraform generated files and sensitive state
**/.terraform/*
*.tfstate
*.tfstate.*
*.tfplan
*.tfplan.*
crash.log
crash.*.log
*.tfvars
*.tfvars.json
!*.example.tfvars
!*.example.tfvars.json

# Local environment files
.env
.env.*
!.env.example
!.env.*.example

# Private keys
*.pem
*.key
id_rsa
id_ed25519

# Local Terraform backend settings
/terraform/backend.local.hcl
```

### A.3. Dockerfile

```dockerfile
FROM amazoncorretto:17-alpine-jdk

WORKDIR /app

COPY target/java-maven-app-*.jar /app/app.jar

USER 10001:10001

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
```

### A.4. Jenkinsfile

```groovy
pipeline {
    agent any

    tools {
        maven 'Maven'
    }

    options {
        skipDefaultCheckout()
        disableConcurrentBuilds()
        timeout(time: 30, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
    }

    environment {
        DOCKER_HUB_REPOSITORY = 'younghadiz/complete-cicd-with-terraform'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm

                script {
                    def commit = sh(
                        script: 'git rev-parse HEAD',
                        returnStdout: true
                    ).trim()

                    env.IMAGE_NAME =
                        "complete-cicd-with-terraform:ci-${commit.take(12)}-${env.BUILD_NUMBER}"
                }
            }
        }

        stage('Check build tools') {
            steps {
                sh '''#!/usr/bin/env bash
set -euo pipefail

java -version
mvn -version
docker version
docker compose version
docker info >/dev/null
'''
            }
        }

        stage('Build application') {
            steps {
                sh 'mvn --batch-mode --no-transfer-progress clean verify'
            }
        }

        stage('Build AMD64 image') {
            steps {
                sh '''#!/usr/bin/env bash
set -euo pipefail

docker build \
  --platform linux/amd64 \
  --tag "$IMAGE_NAME" \
  .

architecture="$(
  docker image inspect "$IMAGE_NAME" --format '{{.Architecture}}'
)"

test "$architecture" = "amd64"
'''
            }
        }

        stage('Verify container deployment') {
            steps {
                sh '''#!/usr/bin/env bash
set -euo pipefail

export IMAGE="$IMAGE_NAME"
export APP_BIND_ADDRESS="127.0.0.1"
export APP_PORT="18080"
export COMPOSE_PROJECT_NAME="terraform-ci-check-$$"
export PULL_IMAGE="false"
export VERIFY_METHOD="container"

cleanup() {
  docker compose -f docker-compose.yaml down
}
trap cleanup EXIT

./server-cmds.sh "$IMAGE"
'''
            }
        }
        stage('Publish image') {
            steps {
                script {
                    env.REGISTRY_IMAGE =
                        "${env.DOCKER_HUB_REPOSITORY}:${env.IMAGE_NAME.tokenize(':').last()}"
                }

                withCredentials([
                    usernamePassword(
                        credentialsId: 'terraform-cicd-dockerhub',
                        usernameVariable: 'DOCKER_HUB_USER',
                        passwordVariable: 'DOCKER_HUB_TOKEN'
                    )
                ]) {
                    sh '''#!/usr/bin/env bash
set -euo pipefail
set +x

test "$DOCKER_HUB_USER" = "younghadiz"

# Preserve the Docker daemon endpoint before changing the CLI config.
docker_endpoint="$(
  docker context inspect --format '{{.Endpoints.docker.Host}}'
)"
export DOCKER_HOST="${DOCKER_HOST:-$docker_endpoint}"

# This project uses a local Unix Docker socket.
case "$DOCKER_HOST" in
  unix://*) ;;
  *)
    printf 'Expected a Unix Docker socket for this Jenkins setup.\n' >&2
    exit 1
    ;;
esac

registry_config="$(mktemp -d)"
chmod 700 "$registry_config"
trap 'rm -rf "$registry_config"' EXIT

export DOCKER_CONFIG="$registry_config"

printf '%s' "$DOCKER_HUB_TOKEN" |
  docker login \
    --username "$DOCKER_HUB_USER" \
    --password-stdin

docker tag "$IMAGE_NAME" "$REGISTRY_IMAGE"
docker push "$REGISTRY_IMAGE"

docker image inspect "$REGISTRY_IMAGE" \
  --format '{{range .RepoDigests}}{{println .}}{{end}}' |
  awk -v prefix="${DOCKER_HUB_REPOSITORY}@" \
    'index($0, prefix) == 1 {print; exit}' \
  > target/published-image.txt

test -s target/published-image.txt

printf 'Published image digest:\n'
cat target/published-image.txt
'''
                }
            }
        }

        stage('Provision EC2 with Terraform') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'terraform-cicd-aws',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    ),
                    file(
                        credentialsId: 'terraform-cicd-tfvars',
                        variable: 'TFVARS_FILE'
                    ),
                    file(
                        credentialsId: 'terraform-cicd-backend',
                        variable: 'BACKEND_FILE'
                    )
                ]) {
                    sh '''#!/usr/bin/env bash
set -euo pipefail
set +x

export AWS_REGION="ca-central-1"
export AWS_DEFAULT_REGION="$AWS_REGION"
export TF_IN_AUTOMATION="true"

# The project credential uses an IAM access key, not a local AWS profile.
unset AWS_PROFILE AWS_DEFAULT_PROFILE AWS_SESSION_TOKEN

terraform version
aws --version
python3 --version

account_id="$(
  aws sts get-caller-identity --query Account --output text
)"
test "$account_id" = "002184382122"

# Publication must have produced an exact image digest.
test -s target/published-image.txt

terraform -chdir=terraform fmt -check

terraform -chdir=terraform init \
  -input=false \
  -lockfile=readonly \
  -reconfigure \
  -backend-config="$BACKEND_FILE"

terraform -chdir=terraform validate

plan_file="application.tfplan"
plan_json="$WORKSPACE/target/terraform-plan.json"

cleanup_plan() {
  rm -f "terraform/$plan_file" "$plan_json"
}
trap cleanup_plan EXIT

terraform -chdir=terraform plan \
  -input=false \
  -lock-timeout=5m \
  -var-file="$TFVARS_FILE" \
  -out="$plan_file"

terraform -chdir=terraform show \
  -json "$plan_file" > "$plan_json"

# Repeated application deployments must not silently replace infrastructure.
python3 - "$plan_json" <<'PLAN_CHECK'
import json
import sys

with open(sys.argv[1]) as stream:
    plan = json.load(stream)

blocked = [
    change["address"]
    for change in plan.get("resource_changes", [])
    if "delete" in change["change"]["actions"]
]

if blocked:
    print("Plan contains deletion or replacement; investigate before applying:")
    for address in blocked:
        print(f"  {address}")
    sys.exit(1)

print("Plan check passed: no resource deletion or replacement.")
PLAN_CHECK

terraform -chdir=terraform apply \
  -input=false \
  -lock-timeout=5m \
  "$plan_file"

terraform -chdir=terraform output \
  -json > target/terraform-outputs.json

printf 'Provisioned instance: '
terraform -chdir=terraform output -raw instance_id

printf '\nApplication server IP: '
terraform -chdir=terraform output -raw instance_public_ip
printf '\n'
'''
                }
            }
        }

        stage('Deploy application to EC2') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'terraform-cicd-aws',
                        usernameVariable: 'AWS_ACCESS_KEY_ID',
                        passwordVariable: 'AWS_SECRET_ACCESS_KEY'
                    ),
                    usernamePassword(
                        credentialsId: 'terraform-cicd-dockerhub',
                        usernameVariable: 'DOCKER_HUB_USER',
                        passwordVariable: 'DOCKER_HUB_TOKEN'
                    )
                ]) {
                    sshagent(['terraform-cicd-ec2-ssh']) {
                        sh '''#!/usr/bin/env bash
set -euo pipefail
set +x

export AWS_REGION="ca-central-1"
export AWS_DEFAULT_REGION="$AWS_REGION"
unset AWS_PROFILE AWS_DEFAULT_PROFILE AWS_SESSION_TOKEN

instance_id="$(
  python3 -c 'import json; print(json.load(open("target/terraform-outputs.json"))["instance_id"]["value"])'
)"
host="$(
  python3 -c 'import json; print(json.load(open("target/terraform-outputs.json"))["instance_public_ip"]["value"])'
)"
deployment_image="$(cat target/published-image.txt)"

[[ "$deployment_image" =~ ^younghadiz/complete-cicd-with-terraform@sha256:[0-9a-f]{64}$ ]]
test "$DOCKER_HUB_USER" = "younghadiz"

known_hosts="$WORKSPACE/target/ec2-known-hosts"

python3 scripts/ec2_known_hosts.py \
  --instance-id "$instance_id" \
  --host "$host" \
  --output "$known_hosts"

ssh_options=(
  -o BatchMode=yes
  -o StrictHostKeyChecking=yes
  -o "UserKnownHostsFile=$known_hosts"
  -o HostKeyAlgorithms=ssh-ed25519
  -o ConnectTimeout=10
  -o ServerAliveInterval=15
  -o ServerAliveCountMax=3
)

destination="ec2-user@$host"
ready=false

for attempt in {1..60}; do
  if ssh -n "${ssh_options[@]}" "$destination" \
    'test -f /var/lib/capstone/bootstrap-ready &&
     docker info >/dev/null &&
     docker compose version &&
     test -w /opt/complete-cicd-with-terraform'; then
    ready=true
    break
  fi
  sleep 5
done

if [ "$ready" != "true" ]; then
  printf 'EC2 bootstrap or SSH readiness check failed.\n' >&2
  exit 1
fi

scp "${ssh_options[@]}" \
  server-cmds.sh \
  docker-compose.yaml \
  "$destination:/opt/complete-cicd-with-terraform/"

# Only the token travels on stdin; it is not part of the remote command.
printf '%s' "$DOCKER_HUB_TOKEN" |
  ssh "${ssh_options[@]}" "$destination" \
    "bash /opt/complete-cicd-with-terraform/server-cmds.sh '$deployment_image' '$DOCKER_HUB_USER'"

curl --fail --silent --show-error \
  --connect-timeout 5 \
  --max-time 30 \
  "http://$host:8080/" \
  -o target/deployed-homepage.html

cmp \
  src/main/resources/static/index.html \
  target/deployed-homepage.html

printf 'PASS: EC2 serves the expected application at http://%s:8080/\n' "$host"
'''
                    }
                }
            }
        }

    }

    post {
        success {
            archiveArtifacts(
                artifacts: 'target/*.jar,target/published-image.txt',
                fingerprint: true
            )
            echo 'Application build, publication, provisioning and EC2 deployment passed.'
        }

        always {
            script {
                if (env.IMAGE_NAME) {
                    sh '''#!/usr/bin/env bash
set -eu
if [ -n "${REGISTRY_IMAGE:-}" ]; then
  docker image rm "$REGISTRY_IMAGE" || true
fi
docker image rm "$IMAGE_NAME" || true
'''
                }
            }
        }
    }
}
```

### A.5. SOURCES.md

```markdown
# Source Attribution

## Starting application

This project imports the Java Maven application and starter deployment
files from TechWorld with Nana's DevOps Bootcamp repository.

- Repository: https://gitlab.com/twn-devops-bootcamp/latest/12-terraform/java-maven-app
- Branch: feature/starting-code
- Baseline commit: 12112fb528497fe87f0c30f50a879b29d6c0a6a7

The starter files were imported without the upstream Git history.
This repository maintains an independent implementation history.

## Implementation reference

The upstream jenkinsfile-sshagent branch is the reference for integrating
Terraform provisioning with Jenkins and deploying to EC2 using Docker Compose.

Project-specific changes are recorded in this repository's commits.
```

### A.6. bootstrap/backend/.terraform.lock.hcl

```hcl
# This file is maintained automatically by "terraform init".
# Manual edits may be lost in future updates.

provider "registry.terraform.io/hashicorp/aws" {
  version     = "6.67.0"
  constraints = "~> 6.0"
  hashes = [
    "h1:EB9ixYOZrSlYD7wtJxf88qwoyyWrlKDKxhzaCLIb3t4=",
    "h1:OgdIUAQDtJBxlKjoPgChD1w57vl6hm6PyJHiBYgsgQA=",
    "zh:111d5686a1f4ccbc888bb5e2229308bcdd9149898c6af97969fcdfb0e7bd2aa0",
    "zh:21b3b7693bd9754c039fd546f03ed09e7510c6189aa5ee37176f144cf8dd5f95",
    "zh:25e03c7f025ff4851889537605aa560d2e39bd738b33a5204b8037eb164b475f",
    "zh:2817a046f1060e25bf04b0eb78f4e251130bb92dc82ec1264ce156dc9bf78e67",
    "zh:2d318d674c3ec9dbd97ddb10b12ad4827be4f508c43ba2ae1e0523baa9e367e3",
    "zh:2f07ab356718267299e10b6072472ded29d82753883027bf43bcd687ac72feb2",
    "zh:32307e67f83bc0dc94d38cfcd23d782166a09e0e975e2a5aa7d7a3e7ca5d3da8",
    "zh:4ce94853264097dd7f4542b3cfd18d2b98b06d23321db45d5e384ea275a57f63",
    "zh:869656c41cc7c7412f213e488f98167cff61deafcb8cf245d25d056e8dfdc263",
    "zh:8fd8c814e9d8edf152552047db23bf5b5d63f22e6b0b5d47b2af851376e99349",
    "zh:9b12af85486a96aedd8d7984b0ff811a4b42e3d88dad1a3fb4c0b580d04fa425",
    "zh:9cbc02ceef9bd469da497a1e7065ff984bdacfbe919ac3cce804a86c13b6e2c6",
    "zh:9ea55dda2767acfc1f6337fc7d29b1d4d79d6f8f04871f8ad99a6078d2865994",
    "zh:d7149df0819fb57a160489db45d33951765b8f0118daa3b4cd549a0135bc97a1",
    "zh:e5819937bb7043d08c9829b32d52d9fb55a5b9a4d8d55d550d47a3d7392db546",
    "zh:f93bc38dbc0ad53842303f30eec7a22c525c4d56209b54ec33a8d375cfc4e4fd",
  ]
}
```

### A.7. bootstrap/backend/main.tf

```hcl
resource "aws_s3_bucket" "state" {
  bucket        = var.state_bucket_name
  force_destroy = false

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "https_only" {
  bucket = aws_s3_bucket.state.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.state.arn,
          "${aws_s3_bucket.state.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}
```

### A.8. bootstrap/backend/outputs.tf

```hcl
output "state_bucket_name" {
  description = "Bucket used by the application Terraform backend."
  value       = aws_s3_bucket.state.id
}

output "state_bucket_region" {
  description = "Region used in the application backend configuration."
  value       = var.aws_region
}
```

### A.9. bootstrap/backend/providers.tf

```hcl
provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.expected_account_id]

  default_tags {
    tags = {
      Project   = "complete-cicd-with-terraform"
      Component = "TerraformState"
      ManagedBy = "Terraform"
      Owner     = "Gafari"
    }
  }
}
```

### A.10. bootstrap/backend/variables.tf

```hcl
variable "aws_region" {
  description = "Region for the Terraform state bucket."
  type        = string
  default     = "ca-central-1"
}

variable "expected_account_id" {
  description = "Account permitted to manage the state bucket."
  type        = string
  default     = "002184382122"
}

variable "state_bucket_name" {
  description = "Globally unique bucket name matching the application backend configuration."
  type        = string
  default     = "gafari-tf-cicd-002184382122-ca-central-1"
}
```

### A.11. bootstrap/backend/versions.tf

```hcl
terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "local" {
    path = "terraform.tfstate"
  }
}
```

### A.12. docker-compose.yaml

```yaml
services:
  java-maven-app:
    image: "${IMAGE:?Set IMAGE to the application image reference}"
    ports:
      - "${APP_BIND_ADDRESS:-127.0.0.1}:${APP_PORT:-8080}:8080"
    restart: unless-stopped
```

### A.13. iam/jenkins-terraform-policy.json

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ManageCapstoneEC2Region",
      "Effect": "Allow",
      "Action": [
        "ec2:Describe*",
        "ec2:GetConsoleOutput",
        "ec2:CreateVpc",
        "ec2:DeleteVpc",
        "ec2:ModifyVpcAttribute",
        "ec2:CreateSubnet",
        "ec2:DeleteSubnet",
        "ec2:ModifySubnetAttribute",
        "ec2:CreateInternetGateway",
        "ec2:DeleteInternetGateway",
        "ec2:AttachInternetGateway",
        "ec2:DetachInternetGateway",
        "ec2:CreateRouteTable",
        "ec2:DeleteRouteTable",
        "ec2:CreateRoute",
        "ec2:DeleteRoute",
        "ec2:ReplaceRoute",
        "ec2:AssociateRouteTable",
        "ec2:DisassociateRouteTable",
        "ec2:ReplaceRouteTableAssociation",
        "ec2:CreateSecurityGroup",
        "ec2:DeleteSecurityGroup",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:RevokeSecurityGroupIngress",
        "ec2:AuthorizeSecurityGroupEgress",
        "ec2:RevokeSecurityGroupEgress",
        "ec2:ModifySecurityGroupRules",
        "ec2:UpdateSecurityGroupRuleDescriptionsIngress",
        "ec2:UpdateSecurityGroupRuleDescriptionsEgress",
        "ec2:ImportKeyPair",
        "ec2:DeleteKeyPair",
        "ec2:RunInstances",
        "ec2:TerminateInstances",
        "ec2:StartInstances",
        "ec2:StopInstances",
        "ec2:ModifyInstanceAttribute",
        "ec2:ModifyInstanceMetadataOptions",
        "ec2:ModifyInstanceCreditSpecification",
        "ec2:ModifyVolume",
        "ec2:CreateTags",
        "ec2:DeleteTags"
      ],
      "Resource": "*",
      "Condition": {
        "StringEquals": {
          "aws:RequestedRegion": "ca-central-1"
        }
      }
    },
    {
      "Sid": "AccessStateBucketMetadata",
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": "arn:aws:s3:::gafari-tf-cicd-002184382122-ca-central-1"
    },
    {
      "Sid": "ReadAndWriteApplicationState",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject"
      ],
      "Resource": "arn:aws:s3:::gafari-tf-cicd-002184382122-ca-central-1/complete-cicd-with-terraform/application/terraform.tfstate"
    },
    {
      "Sid": "ManageApplicationStateLock",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::gafari-tf-cicd-002184382122-ca-central-1/complete-cicd-with-terraform/application/terraform.tfstate.tflock"
    }
  ]
}
```

### A.14. infrastructure/jenkins/.env.example

```
DOCKER_GID=987
```

### A.15. infrastructure/jenkins/Dockerfile

```dockerfile
ARG JENKINS_BASE=jenkins/jenkins@sha256:a660310e39ade10631f774bacd5219de767dfd08947ea5c32a739b5e5bb382c1
FROM ${JENKINS_BASE}

USER root

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates curl unzip python3 maven \
       git openssh-client \
    && rm -rf /var/lib/apt/lists/*

# Docker client and plugins; the daemon runs on the host.
RUN set -eu; \
    install -m 0755 -d /etc/apt/keyrings; \
    curl -fsSL --retry 3 \
      https://download.docker.com/linux/debian/gpg \
      -o /etc/apt/keyrings/docker.asc; \
    chmod a+r /etc/apt/keyrings/docker.asc; \
    . /etc/os-release; \
    printf 'deb [arch=%s signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian %s stable\n' \
      "$(dpkg --print-architecture)" "$VERSION_CODENAME" \
      > /etc/apt/sources.list.d/docker.list; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      docker-ce-cli docker-buildx-plugin docker-compose-plugin; \
    rm -rf /var/lib/apt/lists/*

ARG TERRAFORM_VERSION=1.15.6

RUN set -eu; \
    test "$(dpkg --print-architecture)" = "amd64"; \
    mkdir -p /tmp/terraform-install; \
    cd /tmp/terraform-install; \
    archive="terraform_${TERRAFORM_VERSION}_linux_amd64.zip"; \
    checksums="terraform_${TERRAFORM_VERSION}_SHA256SUMS"; \
    release="https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}"; \
    curl -fsSL --retry 3 "${release}/${archive}" -o "${archive}"; \
    curl -fsSL --retry 3 "${release}/${checksums}" -o "${checksums}"; \
    awk -v filename="${archive}" '$2 == filename {print}' \
      "${checksums}" > selected-checksum.txt; \
    test "$(wc -l < selected-checksum.txt)" -eq 1; \
    sha256sum -c selected-checksum.txt; \
    unzip -q "${archive}"; \
    install -m 0755 terraform /usr/local/bin/terraform; \
    cd /; \
    rm -rf /tmp/terraform-install

ARG AWS_CLI_VERSION=2.36.49

RUN set -eu; \
    curl -fsSL --retry 3 \
      "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWS_CLI_VERSION}.zip" \
      -o /tmp/awscliv2.zip; \
    unzip -q /tmp/awscliv2.zip -d /tmp; \
    /tmp/aws/install; \
    rm -rf /tmp/aws /tmp/awscliv2.zip

COPY --chown=jenkins:jenkins plugins.txt /usr/share/jenkins/ref/plugins.txt

USER jenkins

RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt
```

### A.16. infrastructure/jenkins/base-image.txt

```
jenkins/jenkins@sha256:a660310e39ade10631f774bacd5219de767dfd08947ea5c32a739b5e5bb382c1
```

### A.17. infrastructure/jenkins/compose.yaml

```yaml
services:
  jenkins:
    image: custom-jenkins:terraform-capstone-clean
    container_name: jenkins
    restart: unless-stopped
    ports:
      - "127.0.0.1:8080:8080"
    environment:
      JAVA_OPTS: "-Xms256m -Xmx1536m"
    group_add:
      - "${DOCKER_GID:?Set the host Docker socket group ID}"
    security_opt:
      - no-new-privileges:true
    volumes:
      - jenkins_home:/var/jenkins_home
      - /var/run/docker.sock:/var/run/docker.sock
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "3"

volumes:
  jenkins_home:
    name: jenkins_terraform_clean_home
```

### A.18. infrastructure/jenkins/plugins.txt

```
workflow-aggregator
pipeline-model-definition
git
credentials-binding
ssh-agent
maven-plugin
```

### A.19. pom.xml

```xml
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.example</groupId>
    <artifactId>java-maven-app</artifactId>
    <version>1.0-SNAPSHOT</version>

    <build>
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
                <version>3.5.5</version>
                <executions>
                    <execution>
                        <goals>
                            <goal>repackage</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>

            <!-- to handle any Java version mismatch, add the following configuration for maven-compiler-plugin -->
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.11.0</version>
                <configuration>
                    <source>17</source>
                    <target>17</target>
                </configuration>
            </plugin>
        </plugins>
    </build>

    <dependencies>
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-web</artifactId>
            <version>3.5.5</version>
        </dependency>

        <dependency>
            <groupId>junit</groupId>
            <artifactId>junit</artifactId>
            <version>4.13.2</version>
            <scope>test</scope>
        </dependency>

        <dependency>
            <groupId>net.logstash.logback</groupId>
            <artifactId>logstash-logback-encoder</artifactId>
            <version>9.0</version>
        </dependency>
    </dependencies>

</project>
```

### A.20. scripts/ec2_known_hosts.py

```python
#!/usr/bin/env python3
"""Build an SSH known_hosts entry from authenticated EC2 console output."""

import argparse
import base64
import json
from pathlib import Path
import re
import subprocess
import time


def aws_json(*arguments):
    result = subprocess.run(
        [
            "aws",
            "--no-cli-pager",
            "--cli-connect-timeout", "10",
            "--cli-read-timeout", "20",
            "ec2",
            *arguments,
            "--output", "json",
        ],
        check=True,
        capture_output=True,
        text=True,
        timeout=40,
    )
    return json.loads(result.stdout)


def extract_key(console):
    blocks = re.findall(
        r"BEGIN SSH HOST KEY KEYS-----\s*(.*?)"
        r"-----END SSH HOST KEY KEYS",
        console,
        flags=re.DOTALL,
    )

    keys = {
        match
        for block in blocks
        for match in re.findall(
            r"\bssh-ed25519[ \t]+([A-Za-z0-9+/=]+)",
            block,
        )
    }

    if not keys:
        return None

    if len(keys) != 1:
        raise ValueError("Console output contains multiple ED25519 host keys.")

    key = keys.pop()
    blob = base64.b64decode(key, validate=True)

    # OpenSSH ED25519 wire format: key type followed by a 32-byte public key.
    prefix = b"\x00\x00\x00\x0bssh-ed25519\x00\x00\x00\x20"
    if not blob.startswith(prefix) or len(blob) != len(prefix) + 32:
        raise ValueError("Invalid ED25519 public-key encoding.")

    return key


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--instance-id", required=True)
    parser.add_argument("--host", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    response = aws_json(
        "describe-instances",
        "--instance-ids", args.instance_id,
    )
    instances = [
        instance
        for reservation in response.get("Reservations", [])
        for instance in reservation.get("Instances", [])
    ]

    if len(instances) != 1:
        raise ValueError("Expected exactly one EC2 instance.")

    if instances[0].get("PublicIpAddress") != args.host:
        raise ValueError("Terraform address does not match the EC2 instance.")

    deadline = time.monotonic() + 600

    while time.monotonic() < deadline:
        response = aws_json(
            "get-console-output",
            "--instance-id", args.instance_id,
            "--latest",
        )

        if response.get("InstanceId") != args.instance_id:
            raise ValueError("Console output belongs to an unexpected instance.")

        # AWS CLI decodes the console output.
        key = extract_key(response.get("Output") or "")

        if key:
            destination = Path(args.output)
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text(f"{args.host} ssh-ed25519 {key}\n")
            destination.chmod(0o600)
            print(f"Prepared trusted SSH host key for {args.instance_id}.")
            return

        time.sleep(5)

    raise TimeoutError("EC2 console did not provide an ED25519 host key.")


if __name__ == "__main__":
    main()
```

### A.21. server-cmds.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./server-cmds.sh IMAGE [DOCKER_HUB_USERNAME]
# If a username is supplied, provide the registry token on standard input.

export IMAGE="${1:?Usage: server-cmds.sh IMAGE [DOCKER_HUB_USERNAME]}"
registry_user="${2:-}"

if [[ "$IMAGE" == -* || "$IMAGE" =~ [[:space:]] ]]; then
  printf 'Invalid image reference.\n' >&2
  exit 1
fi

export APP_BIND_ADDRESS="${APP_BIND_ADDRESS:-0.0.0.0}"
export APP_PORT="${APP_PORT:-8080}"
export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-complete-cicd-with-terraform}"

pull_image="${PULL_IMAGE:-true}"

case "$pull_image" in
  true|false) ;;
  *)
    printf 'PULL_IMAGE must be true or false.\n' >&2
    exit 1
    ;;
esac

cd "$(dirname "${BASH_SOURCE[0]}")"

registry_config=""
response_file="$(mktemp)"

cleanup() {
  rm -f "$response_file"
  if [ -n "$registry_config" ]; then
    rm -rf "$registry_config"
  fi
}
trap cleanup EXIT

docker info >/dev/null
docker compose version
docker compose -f docker-compose.yaml config --quiet

if [ -n "$registry_user" ]; then
  registry_config="$(mktemp -d)"
  chmod 700 "$registry_config"
  export DOCKER_CONFIG="$registry_config"

  docker login \
    --username "$registry_user" \
    --password-stdin
fi

if [ "$pull_image" = "true" ]; then
  docker compose -f docker-compose.yaml pull java-maven-app
else
  # Local verification only: the image must already exist.
  docker image inspect "$IMAGE" >/dev/null
fi

docker compose -f docker-compose.yaml up -d --no-build

verify_method="${VERIFY_METHOD:-host}"

case "$verify_method" in
  host|container) ;;
  *)
    printf 'VERIFY_METHOD must be host or container.\n' >&2
    exit 1
    ;;
esac

probe_container="$(
  docker compose -f docker-compose.yaml ps -q java-maven-app
)"
test -n "$probe_container"

fetch_homepage() {
  if [ "$verify_method" = "container" ]; then
    docker exec "$probe_container" \
      /bin/busybox wget -q -T 5 -O - \
      http://127.0.0.1:8080/ > "$response_file"
  else
    curl --fail --silent \
      --connect-timeout 2 \
      --max-time 5 \
      "http://127.0.0.1:${APP_PORT}/" \
      -o "$response_file"
  fi
}

ready=false

for attempt in {1..30}; do
  if fetch_homepage; then

    if grep -Fq \
      '<h1>Welcome to Java Maven Application</h1>' \
      "$response_file"; then
      ready=true
      break
    fi
  fi

  sleep 2
done

if [ "$ready" != "true" ]; then
  printf 'FAILED: application readiness verification.\n' >&2
  docker compose -f docker-compose.yaml ps
  docker compose -f docker-compose.yaml logs --tail 100 --no-color
  exit 1
fi

container_id="$(
  docker compose -f docker-compose.yaml ps -q java-maven-app
)"
test -n "$container_id"

actual_image="$(
  docker inspect --format '{{.Config.Image}}' "$container_id"
)"
test "$actual_image" = "$IMAGE"

test "$(
  docker inspect --format '{{.State.Running}}' "$container_id"
)" = "true"

docker compose -f docker-compose.yaml ps

printf 'PASS: %s is running and serves the expected homepage.\n' "$IMAGE"
```

### A.22. src/main/java/com/example/Application.java

```java
package com.example;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import jakarta.annotation.PostConstruct;

@SpringBootApplication
public class Application {

    public static void main(String[] args)
    {
        SpringApplication.run(Application.class, args);
    }

    @PostConstruct
    public void init()
    {
        Logger log = LoggerFactory.getLogger(Application.class);
        log.info("Java app started");
    }

    public String getStatus() {
        return "OK";
    }
}
```

### A.23. src/main/resources/static/index.html

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>MyApp</title>
</head>
<body>
<h1>Welcome to Java Maven Application</h1>
<!-- add image here  <img src="" width="" /> -->
</body>
</html>
```

### A.24. terraform/.terraform.lock.hcl

```hcl
# This file is maintained automatically by "terraform init".
# Manual edits may be lost in future updates.

provider "registry.terraform.io/hashicorp/aws" {
  version     = "6.67.0"
  constraints = "~> 6.0"
  hashes = [
    "h1:EB9ixYOZrSlYD7wtJxf88qwoyyWrlKDKxhzaCLIb3t4=",
    "h1:OgdIUAQDtJBxlKjoPgChD1w57vl6hm6PyJHiBYgsgQA=",
    "zh:111d5686a1f4ccbc888bb5e2229308bcdd9149898c6af97969fcdfb0e7bd2aa0",
    "zh:21b3b7693bd9754c039fd546f03ed09e7510c6189aa5ee37176f144cf8dd5f95",
    "zh:25e03c7f025ff4851889537605aa560d2e39bd738b33a5204b8037eb164b475f",
    "zh:2817a046f1060e25bf04b0eb78f4e251130bb92dc82ec1264ce156dc9bf78e67",
    "zh:2d318d674c3ec9dbd97ddb10b12ad4827be4f508c43ba2ae1e0523baa9e367e3",
    "zh:2f07ab356718267299e10b6072472ded29d82753883027bf43bcd687ac72feb2",
    "zh:32307e67f83bc0dc94d38cfcd23d782166a09e0e975e2a5aa7d7a3e7ca5d3da8",
    "zh:4ce94853264097dd7f4542b3cfd18d2b98b06d23321db45d5e384ea275a57f63",
    "zh:869656c41cc7c7412f213e488f98167cff61deafcb8cf245d25d056e8dfdc263",
    "zh:8fd8c814e9d8edf152552047db23bf5b5d63f22e6b0b5d47b2af851376e99349",
    "zh:9b12af85486a96aedd8d7984b0ff811a4b42e3d88dad1a3fb4c0b580d04fa425",
    "zh:9cbc02ceef9bd469da497a1e7065ff984bdacfbe919ac3cce804a86c13b6e2c6",
    "zh:9ea55dda2767acfc1f6337fc7d29b1d4d79d6f8f04871f8ad99a6078d2865994",
    "zh:d7149df0819fb57a160489db45d33951765b8f0118daa3b4cd549a0135bc97a1",
    "zh:e5819937bb7043d08c9829b32d52d9fb55a5b9a4d8d55d550d47a3d7392db546",
    "zh:f93bc38dbc0ad53842303f30eec7a22c525c4d56209b54ec33a8d375cfc4e4fd",
  ]
}
```

### A.25. terraform/access-variables.tf

```hcl
variable "ssh_public_key" {
  description = "OpenSSH public key for Jenkins deployment access."
  type        = string

  validation {
    condition     = can(regex("^ssh-ed25519 ", trimspace(var.ssh_public_key)))
    error_message = "Provide the project's OpenSSH ED25519 public key."
  }
}

variable "ssh_allowed_cidrs" {
  description = "IPv4 CIDRs permitted to connect over SSH."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.ssh_allowed_cidrs :
      can(cidrnetmask(cidr)) && cidr != "0.0.0.0/0"
    ])
    error_message = "Provide valid IPv4 CIDRs; unrestricted SSH is not permitted."
  }
}

variable "app_allowed_cidrs" {
  description = "IPv4 CIDRs permitted to access the application on port 8080."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for cidr in var.app_allowed_cidrs :
      can(cidrnetmask(cidr)) && cidr != "0.0.0.0/0"
    ])
    error_message = "Provide valid, restricted IPv4 CIDRs for application access."
  }
}
```

### A.26. terraform/access.tf

```hcl
resource "aws_key_pair" "deployment" {
  key_name   = "${var.project_name}-deployment"
  public_key = trimspace(var.ssh_public_key)
}

resource "aws_security_group" "app" {
  name_prefix = "${var.project_name}-"
  description = "Restricted access to the capstone application server"
  vpc_id      = aws_vpc.app.id

  tags = {
    Name = "${var.project_name}-app"
  }
}

resource "aws_vpc_security_group_ingress_rule" "ssh" {
  for_each = var.ssh_allowed_cidrs

  security_group_id = aws_security_group.app.id
  description       = "SSH from an approved deployment or administration network"
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_ingress_rule" "application" {
  for_each = var.app_allowed_cidrs

  security_group_id = aws_security_group.app.id
  description       = "Application access from an approved network"
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 8080
  to_port           = 8080
}

resource "aws_vpc_security_group_egress_rule" "internet" {
  security_group_id = aws_security_group.app.id
  description       = "Outbound access for DNS, package installation and image pulls"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
```

### A.27. terraform/backend.example.hcl

```hcl
bucket       = "REPLACE_WITH_YOUR_PROJECT_STATE_BUCKET"
key          = "complete-cicd-with-terraform/application/terraform.tfstate"
region       = "ca-central-1"
encrypt      = true
use_lockfile = true
```

### A.28. terraform/compute-variables.tf

```hcl
variable "ami_id" {
  description = "Explicit Amazon Linux 2023 x86-64 AMI ID in the selected region."
  type        = string

  validation {
    condition     = can(regex("^ami-([0-9a-f]{8}|[0-9a-f]{17})$", var.ami_id))
    error_message = "Provide a valid EC2 AMI ID."
  }
}

variable "instance_type" {
  description = "EC2 instance type for the demonstration application."
  type        = string
  default     = "t3.micro"

  validation {
    condition     = contains(["t3.micro", "t3.small"], var.instance_type)
    error_message = "Choose t3.micro or t3.small for this capstone."
  }
}
```

### A.29. terraform/compute.tf

```hcl
resource "aws_instance" "app" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.app.id]
  key_name                    = aws_key_pair.deployment.key_name
  associate_public_ip_address = true

  user_data                   = file("${path.module}/scripts/bootstrap.sh")
  user_data_replace_on_change = true

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 10
    encrypted             = true
    delete_on_termination = true
  }

  depends_on = [
    aws_route.internet,
    aws_route_table_association.public,
    aws_vpc_security_group_egress_rule.internet
  ]

  tags = {
    Name = "${var.project_name}-app"
  }
}
```

### A.30. terraform/network.tf

```hcl
resource "aws_vpc" "app" {
  cidr_block           = "10.30.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.app.id
  cidr_block = "10.30.1.0/24"

  tags = {
    Name = "${var.project_name}-public"
  }
}

resource "aws_internet_gateway" "app" {
  vpc_id = aws_vpc.app.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.app.id

  tags = {
    Name = "${var.project_name}-public"
  }
}

resource "aws_route" "internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.app.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
```

### A.31. terraform/outputs.tf

```hcl
output "instance_id" {
  description = "Managed application EC2 instance ID."
  value       = aws_instance.app.id
}

output "instance_public_ip" {
  description = "Application server address for SSH deployment."
  value       = aws_instance.app.public_ip
}

output "ssh_user" {
  description = "SSH username for the Amazon Linux application server."
  value       = "ec2-user"
}

output "deployment_key_name" {
  description = "Registered EC2 deployment key name."
  value       = aws_key_pair.deployment.key_name
}

output "application_url" {
  description = "Application URL, accessible from approved networks after deployment."
  value       = "http://${aws_instance.app.public_ip}:8080"
}
```

### A.32. terraform/providers.tf

```hcl
provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.expected_account_id]

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "Terraform"
      Owner     = "Gafari"
    }
  }
}
```

### A.33. terraform/scripts/bootstrap.sh

```bash
#!/usr/bin/env bash
set -euo pipefail

exec > >(tee -a /var/log/capstone-bootstrap.log) 2>&1

printf 'Starting capstone server bootstrap\n'

mkdir -p /var/lib/capstone
rm -f /var/lib/capstone/bootstrap-ready

test "$(uname -m)" = "x86_64"

dnf install -y docker

mkdir -p /etc/docker

cat > /etc/docker/daemon.json <<'JSON'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
JSON

# Pin Compose rather than downloading an unspecified latest release.
compose_version="v2.39.4"
compose_asset="docker-compose-linux-x86_64"
compose_url="https://github.com/docker/compose/releases/download/${compose_version}"

bootstrap_tmp="$(mktemp -d)"
trap 'rm -rf "$bootstrap_tmp"' EXIT

curl --fail --location \
  --retry 5 --retry-delay 3 \
  --connect-timeout 15 --max-time 180 \
  "${compose_url}/${compose_asset}" \
  -o "${bootstrap_tmp}/${compose_asset}"

curl --fail --location \
  --retry 5 --retry-delay 3 \
  --connect-timeout 15 --max-time 60 \
  "${compose_url}/${compose_asset}.sha256" \
  -o "${bootstrap_tmp}/${compose_asset}.sha256"

expected_sha="$(
  awk 'NR == 1 {print $1}' \
    "${bootstrap_tmp}/${compose_asset}.sha256"
)"

[[ "$expected_sha" =~ ^[0-9a-fA-F]{64}$ ]]

printf '%s  %s\n' \
  "$expected_sha" \
  "${bootstrap_tmp}/${compose_asset}" |
  sha256sum --check -

install -d -m 0755 /usr/local/lib/docker/cli-plugins

install -m 0755 \
  "${bootstrap_tmp}/${compose_asset}" \
  /usr/local/lib/docker/cli-plugins/docker-compose

usermod -aG docker ec2-user

install -d \
  -o ec2-user \
  -g ec2-user \
  -m 0750 \
  /opt/complete-cicd-with-terraform

systemctl enable --now docker

docker info >/dev/null
docker compose version

touch /var/lib/capstone/bootstrap-ready

printf 'Capstone server bootstrap completed\n'
```

### A.34. terraform/terraform.example.tfvars

```hcl
aws_region          = "ca-central-1"
expected_account_id = "002184382122"
project_name        = "complete-cicd-with-terraform"

# Verify an Amazon Linux 2023 x86-64 AMI in the selected region.
ami_id        = "ami-0bf6dbeae330f5823"
instance_type = "t3.micro"

# Replace with your deployment public key.
ssh_public_key = "ssh-ed25519 REPLACE_WITH_PUBLIC_KEY"

# Add the Jenkins public IP and approved administration IP as /32 CIDRs.
ssh_allowed_cidrs = []

# Add approved application-testing IPs as /32 CIDRs.
app_allowed_cidrs = []
```

### A.35. terraform/variables.tf

```hcl
variable "aws_region" {
  description = "AWS region for the capstone infrastructure."
  type        = string
  default     = "ca-central-1"
}

variable "expected_account_id" {
  description = "AWS account in which provisioning is permitted."
  type        = string
  default     = "002184382122"

  validation {
    condition     = can(regex("^[0-9]{12}$", var.expected_account_id))
    error_message = "expected_account_id must contain exactly 12 digits."
  }
}

variable "project_name" {
  description = "Project prefix used for resource names and tags."
  type        = string
  default     = "complete-cicd-with-terraform"
}
```

### A.36. terraform/versions.tf

```hcl
terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {}
}
```
