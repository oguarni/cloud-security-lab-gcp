#!/usr/bin/env bash
###############################################################################
# startup-script da VM ALVO (executado automaticamente pelo GCP no 1º boot)
# Configura: DVWA (LAMP) + SSH com usuário fraco + vsftpd + Ops Agent (logs)
###############################################################################
set -euxo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y apache2 mariadb-server php php-mysqli php-gd libapache2-mod-php \
                   openssh-server vsftpd git curl

# ----------------------- Banco de dados da DVWA ------------------------------
systemctl enable --now mariadb
mysql -e "CREATE DATABASE IF NOT EXISTS dvwa;"
mysql -e "CREATE USER IF NOT EXISTS 'dvwauser'@'localhost' IDENTIFIED BY 'dvwapassword';"
mysql -e "GRANT ALL ON dvwa.* TO 'dvwauser'@'localhost'; FLUSH PRIVILEGES;"

# ------------------------------- DVWA ----------------------------------------
if [ ! -d /var/www/html/DVWA ]; then
  git clone https://github.com/digininja/DVWA.git /var/www/html/DVWA
fi
cp /var/www/html/DVWA/config/config.inc.php.dist /var/www/html/DVWA/config/config.inc.php
sed -i "s/p@ssw0rd/dvwapassword/; s/'db_user'.*/'db_user' ] = 'dvwauser';/; \
        s/'db_database'.*/'db_database' ] = 'dvwa';/" /var/www/html/DVWA/config/config.inc.php
chown -R www-data:www-data /var/www/html/DVWA
chmod -R 755 /var/www/html/DVWA

# Página de login HTTP simples (usada no roteiro de sniffing - Wireshark)
cat >/var/www/html/login.html <<'EOF'
<!doctype html><html><body><h3>Login Corporativo (HTTP)</h3>
<form method="POST" action="/login.html">
  Usuário: <input name="user"><br>
  Senha:   <input name="pass" type="password"><br>
  <input type="submit" value="Entrar">
</form></body></html>
EOF

systemctl enable --now apache2 ssh vsftpd

# --------------------- Usuário de teste com senha fraca ----------------------
# (apenas para o roteiro de força bruta - ambiente isolado)
id teste &>/dev/null || useradd -m -s /bin/bash teste
echo 'teste:123456' | chpasswd
# Garante autenticação por senha no SSH (necessária para o ataque do Hydra).
# Atenção: a imagem Ubuntu do GCP desabilita senha em
# /etc/ssh/sshd_config.d/60-cloudimg-settings.conf (vence por precedência),
# então é preciso ajustar esse arquivo, não só o sshd_config principal.
sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
if [ -f /etc/ssh/sshd_config.d/60-cloudimg-settings.conf ]; then
  sed -i 's/^PasswordAuthentication.*/PasswordAuthentication yes/I' /etc/ssh/sshd_config.d/60-cloudimg-settings.conf
fi
systemctl restart ssh

# ------------------ Ops Agent: encaminha auth.log p/ Cloud Logging -----------
# Por padrao o Ops Agent coleta apenas 'syslog'. Aqui adicionamos um receiver de
# arquivo para /var/log/auth.log, de modo que as tentativas de login SSH
# (Failed/Accepted password) sejam encaminhadas ao Cloud Logging e fiquem
# disponiveis para auditoria forense centralizada (consultaveis via gcloud logging read).
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
bash add-google-cloud-ops-agent-repo.sh --also-install || true

mkdir -p /etc/google-cloud-ops-agent
cat >/etc/google-cloud-ops-agent/config.yaml <<'EOF'
logging:
  receivers:
    auth_log:
      type: files
      include_paths:
        - /var/log/auth.log
  service:
    pipelines:
      authlog_pipeline:
        receivers: [auth_log]
EOF
systemctl restart google-cloud-ops-agent || true

echo "ALVO pronto: DVWA em /DVWA, login.html, SSH (teste:123456), FTP, auth.log->Cloud Logging."
