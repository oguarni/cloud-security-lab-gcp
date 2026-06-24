#!/usr/bin/env bash
###############################################################################
# startup-script da VM ATACANTE (executado automaticamente pelo GCP no 1º boot)
# Provisiona um Ubuntu 22.04 com o arsenal ofensivo (nmap, hydra, sqlmap,
# tshark/tcpdump, nikto, SET) usado nos cinco roteiros.
###############################################################################
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update
# Reconhecimento, força bruta, exploração web e sniffing
apt-get install -y nmap hydra sqlmap tshark tcpdump nikto curl git python3-pip \
                   netcat-openbsd

# Dicionário de senhas para o roteiro de força bruta
cat >/home/$(ls /home | head -n1)/senhas.txt <<'EOF'
123456
admin
senha
teste123
password
root
qwerty
EOF

# Social Engineering Toolkit (SET) - roteiro de phishing
if [ ! -d /opt/set ]; then
  git clone https://github.com/trustedsec/social-engineer-toolkit.git /opt/set || true
  pip3 install -r /opt/set/requirements.txt || true
fi

echo "ATACANTE pronto: nmap, hydra, sqlmap, tshark/tcpdump, nikto, SET."
