#!/usr/bin/env bash
# =============================================================================
# Génère un certificat TLS auto-signé pour la stack Docker prod.
# =============================================================================
# Génère un cert valable pour :
#   - gestion-produits.local
#   - dev.gestion-produits.local
# Le certificat est valide 825 jours, durée largement supérieure à la durée
# de vie du TP.
#
# Le sujet précise explicitement que des certificats auto-signés sont
# acceptables (donc le navigateur affichera un warning, c'est normal).
#
# Usage :
#   ./scripts/gen-certs.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_DIR="${SCRIPT_DIR}/../traefik/certs"
COMMON_NAME="gestion-produits.local"

mkdir -p "${CERT_DIR}"

if [[ -f "${CERT_DIR}/${COMMON_NAME}.crt" ]]; then
  echo "[gen-certs] Le certificat existe déjà dans ${CERT_DIR}, suppression et regénération."
  rm -f "${CERT_DIR}/${COMMON_NAME}.crt" "${CERT_DIR}/${COMMON_NAME}.key"
fi

# Fichier de config OpenSSL avec SAN (Subject Alternative Names)
CONFIG_FILE="$(mktemp)"
cat > "${CONFIG_FILE}" <<EOF
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[req_distinguished_name]
C  = FR
ST = Ile-de-France
L  = Paris
O  = EPSI M1 DEV
CN = ${COMMON_NAME}

[v3_req]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = gestion-produits.local
DNS.2 = dev.gestion-produits.local
DNS.3 = k8s.gestion-produits.local
DNS.4 = dev.k8s.gestion-produits.local
EOF

openssl req \
  -x509 \
  -newkey rsa:4096 \
  -sha256 \
  -nodes \
  -days 825 \
  -keyout "${CERT_DIR}/${COMMON_NAME}.key" \
  -out    "${CERT_DIR}/${COMMON_NAME}.crt" \
  -config "${CONFIG_FILE}"

chmod 644 "${CERT_DIR}/${COMMON_NAME}.crt"
chmod 600 "${CERT_DIR}/${COMMON_NAME}.key"

rm -f "${CONFIG_FILE}"

echo "[gen-certs] Certificat généré :"
echo "   - ${CERT_DIR}/${COMMON_NAME}.crt"
echo "   - ${CERT_DIR}/${COMMON_NAME}.key"
openssl x509 -in "${CERT_DIR}/${COMMON_NAME}.crt" -noout -subject -dates -ext subjectAltName
