#!/bin/bash
# Install/Reset Zabbix Proxy 7.0 (SQLite3) – Oracle Linux 9 – SEM TLS

set -e

PROXY_HOSTNAME="Proxy-Randon"
ZBX_SERVER="10.0.2.120"
DB_PATH="/var/lib/zabbix/zabbix_proxy.db"

echo ">>> Removendo instalações anteriores..."
systemctl stop zabbix-proxy 2>/dev/null || true
dnf remove -y zabbix-proxy* zabbix-agent2 || true

rm -rf /etc/zabbix
rm -rf /var/log/zabbix
rm -rf /var/lib/zabbix

echo ">>> Instalando repositório Zabbix 7.0..."
rpm -Uvh https://repo.zabbix.com/zabbix/7.0/rhel/9/x86_64/zabbix-release-7.0-1.el9.noarch.rpm || true
dnf clean all

echo ">>> Instalando Zabbix Proxy (SQLite)..."
dnf install -y zabbix-proxy-sqlite3 zabbix-agent2

echo ">>> Criando diretórios..."
mkdir -p /var/lib/zabbix
mkdir -p /var/log/zabbix
chown -R zabbix:zabbix /var/lib/zabbix /var/log/zabbix

echo ">>> Criando database SQLite..."
sudo -u zabbix sqlite3 $DB_PATH < /usr/share/zabbix/sqlite3/schema.sql

echo ">>> Criando configuração do proxy..."
cat <<EOF >/etc/zabbix/zabbix_proxy.conf
############# ZABBIX PROXY 7.0 (SEM TLS) #############

Server=$ZBX_SERVER
Hostname=$PROXY_HOSTNAME

DBName=$DB_PATH

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

#######################################################
EOF

echo ">>> Ajustando permissões..."
chown zabbix:zabbix /etc/zabbix/zabbix_proxy.conf
chmod 640 /etc/zabbix/zabbix_proxy.conf

echo ">>> Iniciando e habilitando serviço..."
systemctl enable --now zabbix-proxy

echo ""
echo "=============================================================="
echo "   ZABBIX PROXY 7.0 INSTALADO (SEM CRIPTOGRAFIA)"
echo "--------------------------------------------------------------"
echo "   Hostname     : $PROXY_HOSTNAME"
echo "   Zabbix Server: $ZBX_SERVER"
echo "   Modo         : Active"
echo "   DB SQLite    : $DB_PATH"
echo "=============================================================="
echo ""
echo "Logs: tail -f /var/log/zabbix/zabbix_proxy.log"
echo ""
