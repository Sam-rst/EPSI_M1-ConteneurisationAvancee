#!/usr/bin/env bash
# =============================================================================
# Deploiement de la stack Docker prod sur l'EC2 AWS.
# =============================================================================
# Steps :
#   1. Recupere l'IP publique et la cle SSH depuis les outputs Terraform.
#   2. Copie le code app/ et docker/ sur l'EC2 (rsync via ssh).
#   3. Sur l'EC2 :
#      - Genere .env aleatoire si absent (mots de passe MySQL)
#      - Genere certificat TLS auto-signe si absent
#      - Initialise le dump SQL si absent (copie depuis app/database)
#      - docker compose up -d --build
#   4. Verifie que la stack repond en HTTPS.
#
# Usage :
#   ./scripts/deploy.sh
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TF_DIR="${REPO_ROOT}/terraform/envs/docker"
REMOTE_USER="ubuntu"
REMOTE_DIR="/home/ubuntu/tp-cont"

cd "${TF_DIR}"

EIP="$(terraform output -raw public_ip)"
KEY_PATH="${REPO_ROOT}/terraform/.ssh/tp-cont-docker.pem"

if [[ ! -f "${KEY_PATH}" ]]; then
  echo "[deploy] ERREUR : cle SSH introuvable : ${KEY_PATH}"
  echo "         Lance d'abord 'terraform apply' dans terraform/envs/docker/"
  exit 1
fi

echo "[deploy] Cible : ${REMOTE_USER}@${EIP}"
echo "[deploy] Cle   : ${KEY_PATH}"

SSH_OPTS="-i ${KEY_PATH} -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR"

# 1. Synchronise les sources sur l'EC2 ----------------------------------------
# Utilise tar + ssh (rsync pas dispo nativement sur Windows Git Bash).
# On preserve cote distant : docker/.env, docker/traefik/certs/, docker/init/mysql/
echo "[deploy] Synchronisation des sources (tar via ssh)..."
ssh ${SSH_OPTS} "${REMOTE_USER}@${EIP}" "
  mkdir -p ${REMOTE_DIR}/docker/init/mysql ${REMOTE_DIR}/docker/traefik/certs
  rm -rf ${REMOTE_DIR}/app
"

# Envoi du dossier app/ (recreer a chaque fois)
tar -cf - -C "${REPO_ROOT}" app | \
  ssh ${SSH_OPTS} "${REMOTE_USER}@${EIP}" "tar -xf - -C ${REMOTE_DIR}"

# Envoi du dossier docker/ en EXCLUANT les fichiers gardes cote distant
tar -cf - -C "${REPO_ROOT}" \
  --exclude='docker/.env' \
  --exclude='docker/traefik/certs' \
  --exclude='docker/init/mysql' \
  docker | \
  ssh ${SSH_OPTS} "${REMOTE_USER}@${EIP}" "tar -xf - -C ${REMOTE_DIR}"

# Copie du dump SQL au bon emplacement pour l'init MySQL
scp -i "${KEY_PATH}" -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR \
  "${REPO_ROOT}/app/database/gestion_produits.sql" \
  "${REMOTE_USER}@${EIP}:${REMOTE_DIR}/docker/init/mysql/gestion_produits.sql"

# 2. Bootstrap sur l'EC2 ------------------------------------------------------
echo "[deploy] Bootstrap distant (env, certs, dump)..."
# shellcheck disable=SC2087
ssh ${SSH_OPTS} "${REMOTE_USER}@${EIP}" "bash -s" <<'REMOTE_SCRIPT'
set -euo pipefail
cd /home/ubuntu/tp-cont/docker

# Genere un .env aleatoire la premiere fois
if [[ ! -f .env ]]; then
  echo "[remote] Generation de .env aleatoire..."
  MYSQL_ROOT_PASSWORD="$(openssl rand -base64 24 | tr -d '=+/' | head -c 32)"
  MYSQL_APP_PASSWORD="$(openssl rand -base64 24 | tr -d '=+/' | head -c 32)"
  cat > .env <<EOF
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
MYSQL_APP_PASSWORD=${MYSQL_APP_PASSWORD}
EOF
  chmod 600 .env
  echo "[remote] .env genere."
else
  echo "[remote] .env existant, conserve."
fi

# Genere le certif TLS auto-signe la premiere fois
if [[ ! -f traefik/certs/gestion-produits.local.crt ]]; then
  echo "[remote] Generation du certif TLS auto-signe..."
  chmod +x scripts/gen-certs.sh
  ./scripts/gen-certs.sh
fi

# Fix permissions
chmod +x scripts/*.sh

# Demarre la stack
echo "[remote] docker compose up -d --build..."
docker compose pull traefik db-mysql || true
docker compose up -d --build

echo "[remote] Etat de la stack :"
docker compose ps
REMOTE_SCRIPT

# 3. Verification HTTPS via curl ----------------------------------------------
echo "[deploy] Verification HTTPS (peut prendre 1 min pour MySQL init)..."
sleep 15
for i in 1 2 3 4 5 6 7 8 9 10; do
  code="$(curl -sS -o /dev/null -k -w "%{http_code}" --resolve "gestion-produits.local:443:${EIP}" "https://gestion-produits.local/" || true)"
  if [[ "${code}" == "200" ]]; then
    echo "[deploy] OK : https://gestion-produits.local -> HTTP 200"
    break
  fi
  echo "[deploy]   tentative ${i}/10 : HTTP ${code}, retry dans 10s..."
  sleep 10
done

echo ""
echo "[deploy] Termine."
echo "[deploy] Ajoute cette ligne a ton /etc/hosts pour acceder en navigateur :"
echo ""
echo "   ${EIP}  gestion-produits.local  dev.gestion-produits.local"
echo ""
echo "[deploy] Ensuite ouvre https://gestion-produits.local (login : admin / password)"
