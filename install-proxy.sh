#!/bin/bash
# Instalação limpa do Zabbix Proxy 7.0 com SQLite3 — Oracle Linux 9 / derivados (Alma/Rocky)
# Proxy hostname: Proxy-Randon
# Zabbix Server: 10.0.2.120
# Sem TLS (unencrypted)

set -e

PROXY_HOSTNAME="Proxy-Randon"
ZBX_SERVER="10.0.2.120"
DB_DIR="/var/lib/zabbix"
DB_FILE="${DB_DIR}/zabbix_proxy.db"
CONF_FILE="/etc/zabbix/zabbix_proxy.conf"

echo ">>> Parando proxy (se existente)"
systemctl stop zabbix-proxy 2>/dev/null || true

echo ">>> Removendo pacotes Zabbix proxy/agent anteriores"
dnf remove -y zabbix-proxy* zabbix-agent2 || true

echo ">>> Limpando diretórios antigos"
rm -rf /etc/zabbix
rm -rf /var/log/zabbix
rm -rf "${DB_DIR}"

echo ">>> Instalando repositório oficial Zabbix 7.0"
rpm -Uvh https://repo.zabbix.com/zabbix/7.0/rhel/9/x86_64/zabbix-release-7.0-1.el9.noarch.rpm
dnf clean all

echo ">>> Instalando proxy + scripts SQLite"
dnf install -y zabbix-proxy-sqlite3

echo ">>> Criando diretórios e permissões"
mkdir -p "${DB_DIR}"
mkdir -p /var/log/zabbix
chown -R zabbix:zabbix "${DB_DIR}" /var/log/zabbix

echo ">>> Criando banco SQLite para proxy"
sudo -u zabbix sqlite3 "${DB_FILE}" < /usr/share/zabbix-sql-scripts/sqlite3/proxy.sql

echo ">>> Criando arquivo de configuração do proxy"
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

echo ">>> Ajustando permissões da configuração"
chown zabbix:zabbix "${CONF_FILE}"
chmod 640 "${CONF_FILE}"

echo ">>> Habilitando e iniciando serviço"
systemctl enable --now zabbix-proxy

echo ">>> Instalação concluída!"
echo " Proxy hostname: ${PROXY_HOSTNAME}"
echo " Zabbix Server: ${ZBX_SERVER}"
echo " DB SQLite : ${DB_FILE}"
echo " Log       : /var/log/zabbix/zabbix_proxy.log"
echo ""
echo "Verifique o status: systemctl status zabbix-proxy"
echo "Logs: tail -f /var/log/zabbix/zabbix_proxy.log"
