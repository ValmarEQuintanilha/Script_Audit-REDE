#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Setup seguro para criar o usuário de auditoria
# NÃO transforma o usuário em root pleno.
# Apenas permite executar um script de leitura de logs como root.
#
# Uso:
#   sudo bash setup_auditi_rede.sh
# ou:
#   sudo AUDIT_USER=auditi-rede bash setup_auditi_rede.sh
# ============================================================

AUDIT_USER="${AUDIT_USER:-auditi-rede}"
HELPER_PATH="/usr/local/bin/audita-root-logins.sh"
SUDOERS_FILE="/etc/sudoers.d/${AUDIT_USER}-logs"

echo "[1/5] Criando usuário ${AUDIT_USER} (se não existir)..."
if ! id "${AUDIT_USER}" >/dev/null 2>&1; then
  useradd -m -s /bin/bash "${AUDIT_USER}"
  echo "Usuário criado: ${AUDIT_USER}"
else
  echo "Usuário já existe: ${AUDIT_USER}"
fi

echo "[2/5] Defina a senha do usuário manualmente:"
echo "      passwd ${AUDIT_USER}"

echo "[3/5] Instalando helper seguro em ${HELPER_PATH} ..."
cat > "${HELPER_PATH}" <<'EOF'
#!/usr/bin/env bash
set -o pipefail

SINCE="${1:-30 days ago}"

echo '===== JOURNALCTL ====='
journalctl --no-pager -o short-iso --since "${SINCE}" 2>/dev/null | egrep -i 'sshd|sudo|su|root' || true

echo '===== AUTHLOG ====='
zgrep -hEi 'sshd|sudo|su|root' /var/log/auth.log /var/log/auth.log.* /var/log/auth.log.*.gz 2>/dev/null || true

echo '===== SECURE ====='
zgrep -hEi 'sshd|sudo|su|root' /var/log/secure /var/log/secure.* /var/log/secure.*.gz 2>/dev/null || true
EOF

chown root:root "${HELPER_PATH}"
chmod 750 "${HELPER_PATH}"

echo "[4/5] Criando regra sudo restrita ..."
cat > "${SUDOERS_FILE}" <<EOF
Defaults:${AUDIT_USER} !requiretty
${AUDIT_USER} ALL=(root) NOPASSWD: ${HELPER_PATH}
EOF

chmod 440 "${SUDOERS_FILE}"
visudo -cf "${SUDOERS_FILE}"

echo "[5/5] Finalizado."
echo
echo "IMPORTANTE:"
echo "- Isso NÃO habilita SSH para root."
echo "- Isso NÃO transforma ${AUDIT_USER} em root pleno."
echo "- O usuário só poderá executar como root:"
echo "    sudo -n ${HELPER_PATH}"
echo
echo "Próximos passos:"
echo "  passwd ${AUDIT_USER}"
echo "  ssh ${AUDIT_USER}@IP_DO_SERVIDOR -p PORTA"
echo "  sudo -n ${HELPER_PATH}"
