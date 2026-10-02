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

# Dicionário de senhas para o roteiro de força bruta.
# No 1º boot ainda não existe usuário interativo (ele é criado no primeiro
# login SSH), então derivar o destino de `ls /home` não é confiável. Gravar em
# /etc/skel faz o arquivo ser copiado para ~/senhas.txt quando a conta do
# operador é criada — o roteiro usa `hydra -P senhas.txt` a partir do home.
cat >/etc/skel/senhas.txt <<'EOF'
123456
admin
senha
teste123
password
root
qwerty
EOF
chmod 644 /etc/skel/senhas.txt

# Social Engineering Toolkit (SET) - roteiro de phishing.
# O clone sozinho não instala o executável: é preciso o passo de instalação
# do próprio SET para que `setoolkit` fique disponível no PATH.
if [ ! -d /opt/set ]; then
  git clone https://github.com/trustedsec/social-engineer-toolkit.git /opt/set || true
fi
if [ -d /opt/set ]; then
  pip3 install /opt/set || true
fi

echo "ATACANTE pronto: nmap, hydra, sqlmap, tshark/tcpdump, nikto, SET."
echo "Dicionário de força bruta: ~/senhas.txt (copiado de /etc/skel no 1º login)."
