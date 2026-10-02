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

# Direciona todos os comandos ao projeto correto quando PROJECT_ID é informado,
# evitando agir sobre o projeto ativo errado da configuração do gcloud.
PROJECT_FLAG=()
if [ -n "${PROJECT_ID}" ]; then
  PROJECT_FLAG=(--project="${PROJECT_ID}")
fi

# Remoção idempotente: um recurso já ausente não é erro, mas uma falha real
# (permissão, API, etc.) é registrada para que o resumo final seja honesto.
FAILURES=0
delete() {
  local desc="$1"; shift
  local out
  if out="$("$@" 2>&1)"; then
    return 0
  fi
  if printf '%s' "${out}" | grep -qiE 'was not found|does not exist|notFound|404'; then
    echo "[i] ${desc}: já ausente."
    return 0
  fi
  echo "[ERRO] ${desc}:" >&2
  printf '%s\n' "${out}" >&2
  FAILURES=$((FAILURES + 1))
  return 0
}

echo "[!] Removendo instâncias..."
delete "instâncias atacante/alvo" \
  gcloud compute instances delete atacante alvo \
  --zone="${ZONE}" "${PROJECT_FLAG[@]}" --quiet

echo "[!] Removendo regras de firewall..."
delete "regras de firewall" \
  gcloud compute firewall-rules delete lab-allow-internal lab-allow-ssh-admin lab-allow-web \
  "${PROJECT_FLAG[@]}" --quiet

echo "[!] Removendo sub-rede e rede..."
delete "sub-rede ${SUBNET}" \
  gcloud compute networks subnets delete "${SUBNET}" \
  --region="${REGION}" "${PROJECT_FLAG[@]}" --quiet
delete "rede ${NETWORK}" \
  gcloud compute networks delete "${NETWORK}" "${PROJECT_FLAG[@]}" --quiet

# Opcional: remover o projeto inteiro (teardown mais limpo, à prova de custos).
# Ative com:  DELETE_PROJECT=yes PROJECT_ID=seu-projeto ./99-destruir-lab-gcp.sh
if [ "${DELETE_PROJECT:-no}" = "yes" ] && [ -n "${PROJECT_ID}" ]; then
  echo "[!] Removendo o projeto ${PROJECT_ID}..."
  delete "projeto ${PROJECT_ID}" gcloud projects delete "${PROJECT_ID}" --quiet
fi

if [ "${FAILURES}" -eq 0 ]; then
  echo "[OK] Laboratório destruído. Verifique o console para confirmar."
else
  echo "[AVISO] ${FAILURES} etapa(s) falharam — verifique o console; recursos podem persistir e gerar custo." >&2
  exit 1
fi
