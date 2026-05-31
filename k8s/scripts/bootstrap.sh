#!/usr/bin/env bash
# =============================================================================
# Bootstrap du cluster K8s avec k3s sur les 3 EC2 provisionnees par Terraform.
# =============================================================================
# k3s est une distribution Kubernetes legere et certifiee CNCF (donc "K8s"
# au sens du sujet). Avantages pour ce TP :
#   - install en une commande curl
#   - Traefik en Ingress controller deja inclus
#   - flannel comme CNI inclus
#   - kubectl + kubeconfig generes automatiquement
#
# Steps :
#   1. Sur le CP : install k3s server, recupere le node-token et l'EIP-SAN.
#   2. Sur les 2 workers : install k3s agent pointant sur le CP.
#   3. Recupere le kubeconfig en local (terraform/.ssh/kubeconfig).
#
# Usage :
#   ./k8s/scripts/bootstrap.sh
# =============================================================================
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TF_DIR="${REPO_ROOT}/terraform/envs/kubernetes"
KEY_PATH="${REPO_ROOT}/terraform/.ssh/tp-cont-k8s.pem"
LOCAL_KUBECONFIG="${REPO_ROOT}/terraform/.ssh/kubeconfig"

cd "${TF_DIR}"

CP_PUBLIC="$(terraform output -raw control_plane_public_ip | tr -d '\r')"
CP_PRIVATE="$(terraform output -raw control_plane_private_ip | tr -d '\r')"
WORKER_PUBLIC_IPS=( $(terraform output -json worker_public_ips | tr -d '\r' | jq -r '.[]') )

SSH_OPTS="-i ${KEY_PATH} -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR"

echo "[bootstrap] Control plane : ${CP_PUBLIC} (private ${CP_PRIVATE})"
for i in "${!WORKER_PUBLIC_IPS[@]}"; do
  echo "[bootstrap] Worker $((i+1))    : ${WORKER_PUBLIC_IPS[$i]}"
done

# 1. Install k3s server sur le control plane ----------------------------------
echo "[bootstrap] Install k3s server sur le control plane..."
ssh ${SSH_OPTS} "ubuntu@${CP_PUBLIC}" bash <<EOF
set -euo pipefail
if systemctl is-active --quiet k3s; then
  echo "[cp] k3s deja installe et actif, skip."
else
  # --tls-san           : ajoute l'EIP au certif kube-api (pour kubectl distant)
  # --node-external-ip  : exposee aux Services type LoadBalancer (klipper-lb)
  # --node-ip           : IP privee, evite que les pods passent par l'EIP pour
  #                       atteindre l'API server (hairpin NAT casse sur AWS)
  # --advertise-address : meme raison, force l'API a se publier en IP privee
  curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server \
    --tls-san=${CP_PUBLIC} \
    --node-external-ip=${CP_PUBLIC} \
    --node-ip=${CP_PRIVATE} \
    --advertise-address=${CP_PRIVATE}" sh -
fi
echo "[cp] Etat k3s :"
sudo systemctl is-active k3s
EOF

# 2. Recupere le node-token pour les workers ----------------------------------
echo "[bootstrap] Recuperation du node-token..."
NODE_TOKEN="$(ssh ${SSH_OPTS} "ubuntu@${CP_PUBLIC}" 'sudo cat /var/lib/rancher/k3s/server/node-token' | tr -d '\r')"
echo "[bootstrap]   token recupere (${#NODE_TOKEN} chars)"

# 3. Install k3s agent sur les workers ----------------------------------------
for i in "${!WORKER_PUBLIC_IPS[@]}"; do
  worker="${WORKER_PUBLIC_IPS[$i]}"
  echo "[bootstrap] Install k3s agent sur worker $((i+1)) (${worker})..."
  ssh ${SSH_OPTS} "ubuntu@${worker}" "
    set -euo pipefail
    if systemctl is-active --quiet k3s-agent; then
      echo '[w] k3s-agent deja installe, skip.'
    else
      curl -sfL https://get.k3s.io | K3S_URL=https://${CP_PRIVATE}:6443 K3S_TOKEN='${NODE_TOKEN}' sh -
    fi
    sudo systemctl is-active k3s-agent
  "
done

# 4. Verifie que les 3 nodes sont Ready ---------------------------------------
echo "[bootstrap] Attente des 3 nodes Ready..."
for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18; do
  count="$(ssh ${SSH_OPTS} "ubuntu@${CP_PUBLIC}" 'sudo k3s kubectl get nodes --no-headers 2>/dev/null | awk "{print \$2}" | grep -c Ready || true' | tr -d '\r')"
  echo "[bootstrap]   tentative ${i}/18 : ${count} nodes Ready"
  if [[ "${count}" -ge 3 ]]; then
    echo "[bootstrap] Cluster operationnel !"
    break
  fi
  sleep 10
done

ssh ${SSH_OPTS} "ubuntu@${CP_PUBLIC}" 'sudo k3s kubectl get nodes -o wide'

# 5. Recupere le kubeconfig en local ------------------------------------------
echo "[bootstrap] Recuperation du kubeconfig local..."
ssh ${SSH_OPTS} "ubuntu@${CP_PUBLIC}" 'sudo cat /etc/rancher/k3s/k3s.yaml' \
  | sed "s|127.0.0.1|${CP_PUBLIC}|g" \
  > "${LOCAL_KUBECONFIG}"
chmod 600 "${LOCAL_KUBECONFIG}"
echo "[bootstrap] Kubeconfig sauvegarde dans ${LOCAL_KUBECONFIG}"

echo ""
echo "[bootstrap] ============================================================"
echo "[bootstrap] Cluster k3s pret. Pour utiliser kubectl en local :"
echo "[bootstrap]   export KUBECONFIG=${LOCAL_KUBECONFIG}"
echo "[bootstrap]   kubectl get nodes"
echo "[bootstrap] ============================================================"
