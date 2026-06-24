#!/usr/bin/env bash
###############################################################################
# Trabalho Prático 2 - Segurança e Auditoria em Sistemas
# Provisionamento do laboratório de ataques no Google Cloud Platform (gcloud)
#
# Pré-requisitos:
#   - Google Cloud SDK instalado (gcloud)        https://cloud.google.com/sdk
#   - Conta GCP com faturamento ativo (Free Tier / créditos servem)
#   - Ter executado:  gcloud auth login
#
# Uso:
#   chmod +x 00-provisionar-lab-gcp.sh
#   ./00-provisionar-lab-gcp.sh
#
# IMPORTANTE (ética/custo): execute 99-destruir-lab-gcp.sh ao terminar.
###############################################################################
set -euo pipefail

# ----------------------------- Parâmetros ------------------------------------
PROJECT_ID="${PROJECT_ID:-lab-seguranca-$(date +%s)}"   # ou exporte um existente
REGION="${REGION:-us-central1}"
ZONE="${ZONE:-us-central1-a}"
BILLING_ACCOUNT="${BILLING_ACCOUNT:-}"   # ID da conta (gcloud billing accounts list)
NETWORK="lab-net"
SUBNET="lab-subnet"
SUBNET_RANGE="10.10.0.0/24"

# Descobre o IP público da máquina do operador para restringir o acesso externo.
MEU_IP="$(curl -s https://api.ipify.org || echo "0.0.0.0")"
echo "[i] Seu IP público detectado: ${MEU_IP}  (acesso administrativo será restrito a ele)"

# --------------------------- Projeto / APIs ----------------------------------
# Cria o projeto se ainda não existir (idempotente) e vincula o faturamento,
# tornando o provisionamento totalmente reproduzível a partir do zero.
echo "[+] Criando/selecionando projeto: ${PROJECT_ID}"
gcloud projects create "${PROJECT_ID}" --name="Lab Seguranca TP2" 2>/dev/null \
  || echo "[i] Projeto já existe ou sem permissão de criação — seguindo."
if [ -n "${BILLING_ACCOUNT}" ]; then
  gcloud billing projects link "${PROJECT_ID}" --billing-account="${BILLING_ACCOUNT}"
else
  echo "[!] BILLING_ACCOUNT não definido — vincule o faturamento no Console ou"
  echo "    exporte BILLING_ACCOUNT=XXXXXX-XXXXXX-XXXXXX (gcloud billing accounts list)."
fi
gcloud config set project "${PROJECT_ID}"
echo "[+] Habilitando as APIs (Compute Engine + Cloud Logging)..."
gcloud services enable compute.googleapis.com logging.googleapis.com

# ------------------------------- Rede VPC ------------------------------------
echo "[+] Criando rede VPC e sub-rede..."
gcloud compute networks create "${NETWORK}" --subnet-mode=custom
gcloud compute networks subnets create "${SUBNET}" \
  --network="${NETWORK}" --region="${REGION}" --range="${SUBNET_RANGE}" \
  --enable-flow-logs                          # <-- VPC Flow Logs p/ auditoria

# ----------------------------- Regras de Firewall ----------------------------
# 1) Tráfego interno liberado (atacante <-> alvo), com LOGGING habilitado.
echo "[+] Criando regras de firewall (com logging)..."
gcloud compute firewall-rules create lab-allow-internal \
  --network="${NETWORK}" --direction=INGRESS --action=ALLOW \
  --rules=tcp,udp,icmp --source-ranges="${SUBNET_RANGE}" \
  --enable-logging

# 2) SSH administrativo (gcloud) apenas a partir do SEU IP.
gcloud compute firewall-rules create lab-allow-ssh-admin \
  --network="${NETWORK}" --direction=INGRESS --action=ALLOW \
  --rules=tcp:22 --source-ranges="${MEU_IP}/32" \
  --enable-logging

# 3) Web (porta 80) apenas a partir do SEU IP — exposição controlada da DVWA.
gcloud compute firewall-rules create lab-allow-web \
  --network="${NETWORK}" --direction=INGRESS --action=ALLOW \
  --rules=tcp:80 --target-tags=alvo --source-ranges="${MEU_IP}/32" \
  --enable-logging

# ------------------------------- Instâncias ----------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[+] Criando VM ALVO (Ubuntu: DVWA + SSH + FTP)..."
gcloud compute instances create alvo \
  --zone="${ZONE}" --machine-type=e2-small \
  --image-family=ubuntu-2204-lts --image-project=ubuntu-os-cloud \
  --network="${NETWORK}" --subnet="${SUBNET}" \
  --tags=alvo \
  --metadata-from-file=startup-script="${SCRIPT_DIR}/startup-alvo.sh"

echo "[+] Criando VM ATACANTE (Ubuntu + ferramentas ofensivas)..."
gcloud compute instances create atacante \
  --zone="${ZONE}" --machine-type=e2-medium \
  --image-family=ubuntu-2204-lts --image-project=ubuntu-os-cloud \
  --network="${NETWORK}" --subnet="${SUBNET}" \
  --tags=atacante \
  --metadata-from-file=startup-script="${SCRIPT_DIR}/startup-atacante.sh"

# ------------------------------- Sumário -------------------------------------
echo
echo "============================================================"
echo " Laboratório provisionado com sucesso."
echo "------------------------------------------------------------"
gcloud compute instances list --zones="${ZONE}" \
  --format="table(name,networkInterfaces[0].networkIP,status)"
echo
echo " Conectar:   gcloud compute ssh atacante --zone=${ZONE}"
echo "             gcloud compute ssh alvo     --zone=${ZONE}"
echo
echo " IP INTERNO do alvo é o que será usado nos ataques (10.10.0.x)."
echo " Ao finalizar:  ./99-destruir-lab-gcp.sh"
echo "============================================================"
