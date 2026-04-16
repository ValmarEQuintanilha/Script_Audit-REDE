#!/bin/bash

set -euo pipefail

# =========================
# VARIÁVEIS DE CONFIGURAÇÃO
# =========================

# Quantidade de dias para buscar no journalctl
DIAS=5

# Dados do servidor FTP
FTP_SERVIDOR="ftp.easysolution.com.br"
FTP_PORTA="21"
FTP_USUARIO="easy_repo@easysolution.com.br"
FTP_SENHA="96PO08as@!!(&(4132"

# Diretório remoto no FTP
FTP_DIRETORIO_REMOTO="/logs/ssh"

# Diretório local temporário
DIRETORIO_LOCAL="/tmp/coleta_ssh"

# Nome do host local
HOSTNAME_LOCAL="$(hostname -s)"

# Data/hora para nomear o arquivo
DATA_ARQUIVO="$(date '+%Y-%m-%d_%H-%M-%S')"

# Arquivo final
ARQUIVO_LOG="${HOSTNAME_LOCAL}_ssh_audit_${DATA_ARQUIVO}.log"
CAMINHO_LOCAL="${DIRETORIO_LOCAL}/${ARQUIVO_LOG}"

# =========================
# PREPARAÇÃO
# =========================

mkdir -p "${DIRETORIO_LOCAL}"

echo "Coletando logs dos últimos ${DIAS} dias..."

journalctl -u ssh -u sshd --since "${DIAS} days ago" --no-pager 2>/dev/null | \
grep -E "Failed password|Accepted password|Invalid user" > "${CAMINHO_LOCAL}" || true

if [ ! -s "${CAMINHO_LOCAL}" ]; then
    echo "Nenhum evento encontrado para o período de ${DIAS} dias em $(date)." > "${CAMINHO_LOCAL}"
fi

echo "Arquivo gerado em: ${CAMINHO_LOCAL}"

# =========================
# ENVIO VIA FTP
# =========================

echo "Enviando arquivo para o FTP..."

curl --ftp-create-dirs -T "${CAMINHO_LOCAL}" \
  "ftp://${FTP_USUARIO}:${FTP_SENHA}@${FTP_SERVIDOR}:${FTP_PORTA}${FTP_DIRETORIO_REMOTO}/${ARQUIVO_LOG}"

echo "Upload concluído com sucesso."