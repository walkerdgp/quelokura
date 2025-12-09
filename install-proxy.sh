#!/bin/bash
# Instalador robusto Zabbix Proxy 7.0 com SQLite3 (Oracle Linux 9)
# Validação completa de cada etapa
# Proxy Hostname: Proxy-Randon
# Zabbix Server: 10.0.2.120
set -e

PROXY_HOSTNAME="Proxy-Randon"
ZBX_SERVER="10.0.2.120"
DB_DIR="/var/lib/zabbix"
DB_FILE="${DB_DIR}/zabbix_proxy.db"
CONF_FILE="/etc/zabbix/zabbix_proxy.conf"
SCHEMA_FILE="/usr/share/zabbix-sql-scripts/sqlite3/proxy.sql"

log() {
    echo -e "\n>>> $1"
}

fail() {
    echo -e "\n[ERRO] $1"
    exit 1
}

#---------------------------#
# 1. PARAR E REMOVER ANTIGO
#---------------------------#
log "Parando proxy anterior (se existir)"
systemctl stop zabbix-proxy 2>/dev/null || true

log "Removendo pacotes anteriores"
dnf remove -y zabbix-proxy* zabbix-agent2 || true

log "Removendo diretórios antigos"
rm -rf /etc/zabbix
rm -rf /var/log/zabbix
rm -rf "${DB_DIR}"

#---------------------------#
# 2. REPOSITÓRIO ZABBIX 7.0
#---------------------------#
log "Instalando repositório oficial Zabbix 7.0"

rpm -Uvh https://repo.zabbix.com/zabbix/7.0/rhel/9/x86_64/zabbix-release-7.0-1.el9.noarch.rpm || fail "Falha ao instalar repositório"

dnf clean all || fail "Falha ao limpar DNF"

#---------------------------#
# 3. INSTALAÇÃO DO PROXY
#---------------------------#
log "Instalando zabbix-proxy-sqlite3"
dnf install -y zabbix-proxy-sqlite3 || fail "Pacote zabbix-proxy-sqlite3 não foi instalado"

log "Verificando instalação..."
rpm -qa | grep -q zabbix-proxy-sqlite3 || fail "Pacote NÃO encontrado após instalação"

#---------------------------#
# 4. VALIDAR ARQUIVO DE SCHEMA
#---------------------------#
log "Validando schema SQLite..."

if [[ ! -f "$SCHEMA_FILE" ]]; then
    fail "Schema SQLite NÃO encontrado em: $SCHEMA_FILE"
fi

log "Schema localizado: $SCHEMA_FILE"

#---------------------------#
# 5. CRIAR DB E DIRETÓRIOS
#---------------------------#
log "Criando diretórios de banco e logs"

mkdir -p "${DB_DIR}"
mkdir -p /var/log/zabbix
chown -R zabbix:zabbix "${DB_DIR}" /var/log/zabbix

log "Criando banco SQLite"

sudo -u zabbix sqlite3 "${DB_FILE}" < "${SCHEMA_FILE}" || fail "Erro ao criar banco SQLite"

[[ -f "${DB_FILE}" ]] || fail "Banco SQLite NÃO foi criado"

log "Banco criado com sucesso: ${DB_FILE}"

#---------------------------#
# 6. CONFIGURAÇÃO DO PROXY
#---------------------------#
log "Criando arquivo de configuração do Zabbix Proxy"

cat <<EOF > "${CONF_FILE}"
Server=${ZBX_SERVER}
Hostname=${PROXY_HOSTNAME}

DBName=${DB_FILE}

ConfigFrequency=3600
DataSenderFrequency=1

StartPollers=10
StartPollersUnreachable=5
StartTrappers=5
StartDiscoverers=5

LogType=file
LogFile=/var/log/zabbix/zabbix_proxy.log

TLSConnect=unencrypted
TLSAccept=unencrypted
EOF

[[ -f "${CONF_FILE}" ]] || fail "Arquivo de configuração NÃO foi criado"

chown zabbix:zabbix "${CONF_FILE}"
chmod 640 "${CONF_FILE}"

log "Configuração criada com sucesso"

#---------------------------#
# 7. INICIAR PROXY
#---------------------------#
log "Habilitando e iniciando serviço do Proxy"

systemctl enable --now zabbix-proxy || fail "Falha ao iniciar o serviço do proxy"

sleep 3

systemctl is-active --quiet zabbix-proxy || fail "Serviço não está ativo após iniciar"

log "Serviço iniciado corretamente"

#---------------------------#
# 8. VALIDAR LOGS
#---------------------------#
log "Validando inicialização nos logs"

if ! grep -q "starting Zabbix Proxy" /var/log/zabbix/zabbix_proxy.log; then
    echo "Aviso: Log ainda não contém confirmação completa. Isso pode ser normal nos primeiros segundos."
fi

#---------------------------#
# 9. SUCESSO FINAL
#---------------------------#
log "INSTALAÇÃO FINALIZADA COM SUCESSO!"

cat <<EOF

==============================================================
 ZABBIX PROXY 7.0 INSTALADO E VALIDADO ✔
--------------------------------------------------------------
 Hostname:     ${PROXY_HOSTNAME}
 Zabbix Server: ${ZBX_SERVER}
 DB SQLite:     ${DB_FILE}
 Config:        ${CONF_FILE}
 Log:           /var/log/zabbix/zabbix_proxy.log
 Serviço:       systemctl status zabbix-proxy
==============================================================

EOF

exit 0
