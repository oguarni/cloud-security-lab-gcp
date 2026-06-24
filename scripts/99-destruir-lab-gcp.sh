#!/usr/bin/env bash
###############################################################################
# Destruição do laboratório (libera recursos e evita custos).
# Execute SEMPRE ao finalizar as práticas — princípio ético e de boa gestão.
###############################################################################
set -euo pipefail
ZONE="${ZONE:-us-central1-a}"
REGION="${REGION:-us-central1}"
PROJECT_ID="${PROJECT_ID:-}"
NETWORK="lab-net"
SUBNET="lab-subnet"

echo "[!] Removendo instâncias..."
gcloud compute instances delete atacante alvo --zone="${ZONE}" --quiet || true

echo "[!] Removendo regras de firewall..."
gcloud compute firewall-rules delete lab-allow-internal lab-allow-ssh-admin lab-allow-web --quiet || true

echo "[!] Removendo sub-rede e rede..."
gcloud compute networks subnets delete "${SUBNET}" --region="${REGION}" --quiet || true
gcloud compute networks delete "${NETWORK}" --quiet || true

# Opcional: remover o projeto inteiro (teardown mais limpo, à prova de custos).
# Ative com:  DELETE_PROJECT=yes PROJECT_ID=seu-projeto ./99-destruir-lab-gcp.sh
if [ "${DELETE_PROJECT:-no}" = "yes" ] && [ -n "${PROJECT_ID}" ]; then
  echo "[!] Removendo o projeto ${PROJECT_ID}..."
  gcloud projects delete "${PROJECT_ID}" --quiet || true
fi

echo "[OK] Laboratório destruído. Verifique o console para confirmar."
