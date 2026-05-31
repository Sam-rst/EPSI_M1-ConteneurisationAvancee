#!/usr/bin/env bash
# =============================================================================
# Bootstrap du cluster kubeadm apres terraform apply.
# =============================================================================
# Steps :
#   1. Attend que cloud-init soit fini sur les 3 nodes (containerd + kubeadm).
#   2. Sur le control plane : kubeadm init + config kubectl + Calico CNI.
#   3. Recupere le join command et le passe aux 2 workers.
#   4. Installe le EFS CSI driver et la StorageClass efs-sc.
#   5. Recupere le kubeconfig en local (terraform/.ssh/kubeconfig).
#
# Apres ce script, on a un cluster K8s 3 nodes pret a recevoir des manifests.
# Le deploiement de l'application est fait par k8s/scripts/deploy-app.sh (J5).
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

CP_PUBLIC="$(terraform output -raw control_plane_public_ip)"
CP_PRIVATE="$(terraform output -raw control_plane_private_ip)"
WORKER_PUBLIC_IPS=( $(terraform output -json worker_public_ips | jq -r '.[]') )
WORKER_PRIVATE_IPS=( $(terraform output -json worker_private_ips | jq -r '.[]') )
EFS_ID="$(terraform output -raw efs_file_system_id)"

SSH_OPTS="-i ${KEY_PATH} -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR"

echo "[bootstrap] Control plane : ${CP_PUBLIC} (private ${CP_PRIVATE})"
for i in "${!WORKER_PUBLIC_IPS[@]}"; do
  echo "[bootstrap] Worker $((i+1))    : ${WORKER_PUBLIC_IPS[$i]} (private ${WORKER_PRIVATE_IPS[$i]})"
done
echo "[bootstrap] EFS          : ${EFS_ID}"

# Helper : attend que /var/lib/cloud/instance/k8s-bootstrap-complete existe
wait_cloud_init() {
  local host="$1"
  echo "[bootstrap] Attente cloud-init sur ${host}..."
  for _ in $(seq 1 60); do
    if ssh ${SSH_OPTS} "ubuntu@${host}" 'test -f /var/lib/cloud/instance/k8s-bootstrap-complete' 2>/dev/null; then
      echo "[bootstrap]   OK"
      return 0
    fi
    sleep 10
  done
  echo "[bootstrap] ERREUR : cloud-init pas fini sur ${host} apres 10 minutes."
  return 1
}

# 1. Attend cloud-init sur les 3 nodes ----------------------------------------
wait_cloud_init "${CP_PUBLIC}"
for host in "${WORKER_PUBLIC_IPS[@]}"; do
  wait_cloud_init "${host}"
done

# 2. kubeadm init sur le control plane ----------------------------------------
echo "[bootstrap] Initialisation du control plane (kubeadm init)..."
ssh ${SSH_OPTS} "ubuntu@${CP_PUBLIC}" bash <<EOF
set -euo pipefail
if [[ -f /etc/kubernetes/admin.conf ]]; then
  echo "[cp] Cluster deja initialise, skip kubeadm init."
  exit 0
fi

sudo kubeadm init \
  --apiserver-advertise-address=${CP_PRIVATE} \
  --apiserver-cert-extra-sans=${CP_PUBLIC} \
  --pod-network-cidr=192.168.0.0/16 \
  --upload-certs

# Config kubectl pour ubuntu
mkdir -p /home/ubuntu/.kube
sudo cp -f /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config
EOF

# 3. Recupere le join command -------------------------------------------------
echo "[bootstrap] Generation d'un nouveau join command..."
JOIN_CMD="$(ssh ${SSH_OPTS} "ubuntu@${CP_PUBLIC}" 'sudo kubeadm token create --print-join-command' | tr -d '\r')"
echo "[bootstrap]   ${JOIN_CMD:0:80}..."

# 4. Joint les workers --------------------------------------------------------
for i in "${!WORKER_PUBLIC_IPS[@]}"; do
  worker="${WORKER_PUBLIC_IPS[$i]}"
  echo "[bootstrap] Join worker $((i+1)) (${worker})..."
  ssh ${SSH_OPTS} "ubuntu@${worker}" "
    if [[ -f /etc/kubernetes/kubelet.conf ]]; then
      echo '[w] Deja joint, skip.'
      exit 0
    fi
    sudo ${JOIN_CMD}
  "
done

# 5. Installe Calico CNI ------------------------------------------------------
echo "[bootstrap] Installation Calico CNI..."
ssh ${SSH_OPTS} "ubuntu@${CP_PUBLIC}" bash <<'EOF'
set -euo pipefail
if kubectl get ns calico-system >/dev/null 2>&1; then
  echo "[cp] Calico deja installe, skip."
else
  kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.28.2/manifests/tigera-operator.yaml
  cat <<MANIFEST | kubectl apply -f -
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
      - blockSize: 26
        cidr: 192.168.0.0/16
        encapsulation: VXLAN
        natOutgoing: Enabled
        nodeSelector: all()
MANIFEST
fi

echo "[cp] Attente des nodes Ready (max 5 min)..."
for _ in $(seq 1 60); do
  ready=$(kubectl get nodes --no-headers 2>/dev/null | awk '{print $2}' | grep -c "^Ready" || true)
  total=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)
  echo "  Ready ${ready}/${total}"
  if [[ "$ready" -ge 3 ]]; then
    echo "[cp] Cluster operationnel."
    break
  fi
  sleep 10
done
kubectl get nodes -o wide
EOF

# 6. Installe le EFS CSI driver + StorageClass --------------------------------
echo "[bootstrap] Installation EFS CSI driver..."
ssh ${SSH_OPTS} "ubuntu@${CP_PUBLIC}" bash <<EOF
set -euo pipefail
if kubectl get ns kube-system | grep -q kube-system; then
  : # ok
fi

if kubectl get crd | grep -q csidrivers.storage.k8s.io && \
   kubectl -n kube-system get ds efs-csi-node >/dev/null 2>&1; then
  echo "[cp] EFS CSI driver deja installe, skip."
else
  kubectl apply -k "github.com/kubernetes-sigs/aws-efs-csi-driver/deploy/kubernetes/overlays/stable/?ref=release-2.1"
fi

# StorageClass dynamique pointant sur notre EFS
cat <<MANIFEST | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: efs-sc
provisioner: efs.csi.aws.com
parameters:
  provisioningMode: efs-ap
  fileSystemId: ${EFS_ID}
  directoryPerms: "700"
MANIFEST

echo "[cp] StorageClass efs-sc :"
kubectl get sc efs-sc
EOF

# 7. Recupere le kubeconfig en local ------------------------------------------
echo "[bootstrap] Recuperation du kubeconfig local..."
ssh ${SSH_OPTS} "ubuntu@${CP_PUBLIC}" 'sudo cat /etc/kubernetes/admin.conf' \
  | sed "s|${CP_PRIVATE}|${CP_PUBLIC}|g" \
  > "${LOCAL_KUBECONFIG}"
chmod 600 "${LOCAL_KUBECONFIG}"
echo "[bootstrap] Kubeconfig sauvegarde dans ${LOCAL_KUBECONFIG}"

echo ""
echo "[bootstrap] ============================================================"
echo "[bootstrap] Cluster pret. Pour utiliser kubectl en local :"
echo "[bootstrap]   export KUBECONFIG=${LOCAL_KUBECONFIG}"
echo "[bootstrap]   kubectl get nodes"
echo "[bootstrap] ============================================================"
