#!/usr/bin/env bash
# =============================================================================
# Deploiement de l'application sur le cluster k3s.
# =============================================================================
# Steps :
#   1. Genere les Secret/ConfigMap necessaires :
#      - db-credentials (passwords MySQL aleatoires si Secret absent)
#      - db-init        (ConfigMap avec le dump SQL d'Avalone)
#      - app-tls        (certif TLS auto-signe partage avec la stack Docker)
#   2. Push l'image samrst/gestion-produits:prod sur les nodes via ctr.
#      (en attendant la CI/CD qui pushera sur Docker Hub - J7)
#   3. kubectl apply -k k8s/overlays/prod
#   4. Attente que le rollout converge.
#   5. Test HTTPS via curl --resolve.
#
# Usage :
#   ./k8s/scripts/deploy.sh
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TF_DIR="${REPO_ROOT}/terraform/envs/kubernetes"
KEY_PATH="${REPO_ROOT}/terraform/.ssh/tp-cont-k8s.pem"
KUBECONFIG_PATH="${REPO_ROOT}/terraform/.ssh/kubeconfig"
NS="gestion-produits-prod"

export KUBECONFIG="${KUBECONFIG_PATH}"

cd "${TF_DIR}"
CP_PUBLIC="$(terraform output -raw control_plane_public_ip | tr -d '\r')"
WORKER_PUBLIC_IPS=( $(terraform output -json worker_public_ips | tr -d '\r' | jq -r '.[]') )

SSH_OPTS="-i ${KEY_PATH} -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR"
ALL_NODES=( "${CP_PUBLIC}" "${WORKER_PUBLIC_IPS[@]}" )

echo "[deploy] Cluster : ${CP_PUBLIC} + ${#WORKER_PUBLIC_IPS[@]} workers"

# 0. Cree le namespace --------------------------------------------------------
kubectl create namespace "${NS}" --dry-run=client -o yaml | kubectl apply -f -

# 1. Build l'image localement et l'exporte ------------------------------------
IMAGE="samrst/gestion-produits:prod"
TAR_FILE="/tmp/gestion-produits-prod.tar"

if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
  echo "[deploy] Build de l'image ${IMAGE}..."
  docker build -t "${IMAGE}" "${REPO_ROOT}/app"
fi

echo "[deploy] Export de l'image vers ${TAR_FILE}..."
docker image save -o "${TAR_FILE}" "${IMAGE}"

# 2. Push l'image sur chaque node K8s via ctr (containerd runtime de k3s) -----
for node in "${ALL_NODES[@]}"; do
  echo "[deploy] Import de l'image sur ${node}..."
  scp -i "${KEY_PATH}" -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR \
    "${TAR_FILE}" "ubuntu@${node}:/tmp/gp-prod.tar"
  ssh ${SSH_OPTS} "ubuntu@${node}" \
    'sudo k3s ctr images import /tmp/gp-prod.tar && rm -f /tmp/gp-prod.tar'
done
rm -f "${TAR_FILE}"

# 3. Secret db-credentials (aleatoire la premiere fois, conservee ensuite) ----
if ! kubectl -n "${NS}" get secret db-credentials >/dev/null 2>&1; then
  echo "[deploy] Generation des credentials MySQL..."
  ROOT_PW="$(openssl rand -base64 24 | tr -d '=+/' | head -c 32)"
  APP_PW="$(openssl rand -base64 24 | tr -d '=+/' | head -c 32)"
  kubectl -n "${NS}" create secret generic db-credentials \
    --from-literal=user=app \
    --from-literal=password="${APP_PW}" \
    --from-literal=root_password="${ROOT_PW}"
else
  echo "[deploy] Secret db-credentials existant, conserve."
fi

# 4. ConfigMap db-init avec le dump SQL ---------------------------------------
echo "[deploy] ConfigMap db-init avec le dump SQL..."
kubectl -n "${NS}" create configmap db-init \
  --from-file=01-schema.sql="${REPO_ROOT}/app/database/gestion_produits.sql" \
  --dry-run=client -o yaml | kubectl apply -f -

# 5. Secret TLS app-tls (re-utilise le certif Docker s'il existe, sinon en genere un)
CERT_DIR="${REPO_ROOT}/docker/traefik/certs"
mkdir -p "${CERT_DIR}"
if [[ ! -f "${CERT_DIR}/gestion-produits.local.crt" ]]; then
  echo "[deploy] Generation du certificat TLS auto-signe..."
  bash "${REPO_ROOT}/docker/scripts/gen-certs.sh"
fi

echo "[deploy] Secret TLS app-tls..."
kubectl -n "${NS}" create secret tls app-tls \
  --cert="${CERT_DIR}/gestion-produits.local.crt" \
  --key="${CERT_DIR}/gestion-produits.local.key" \
  --dry-run=client -o yaml | kubectl apply -f -

# 6. Apply des manifests ------------------------------------------------------
echo "[deploy] Apply des manifests..."
kubectl apply -k "${REPO_ROOT}/k8s/overlays/prod"

# 7. Attente rollout ----------------------------------------------------------
echo "[deploy] Attente rollout MySQL..."
kubectl -n "${NS}" rollout status statefulset/db --timeout=180s

echo "[deploy] Attente rollout app..."
kubectl -n "${NS}" rollout status deployment/app --timeout=120s

echo "[deploy] Etat final :"
kubectl -n "${NS}" get pods,svc,ingress

# 8. Verification HTTPS -------------------------------------------------------
echo "[deploy] Verification HTTPS..."
sleep 5
for i in 1 2 3 4 5 6 7 8; do
  code="$(curl -sS -o /dev/null -k -w "%{http_code}" \
    --resolve "k8s.gestion-produits.local:443:${CP_PUBLIC}" \
    "https://k8s.gestion-produits.local/" || true)"
  if [[ "${code}" == "200" ]]; then
    echo "[deploy] OK : https://k8s.gestion-produits.local -> HTTP 200"
    break
  fi
  echo "[deploy]   tentative ${i}/8 : HTTP ${code}, retry dans 10s..."
  sleep 10
done

echo ""
echo "[deploy] Termine."
echo "[deploy] Ajoute cette ligne a ton /etc/hosts :"
echo ""
echo "   ${CP_PUBLIC}  k8s.gestion-produits.local"
echo ""
