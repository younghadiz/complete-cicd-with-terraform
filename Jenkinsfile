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
