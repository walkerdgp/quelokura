# Usa a imagem oficial do Zabbix Proxy baseada em Ubuntu
FROM zabbix/zabbix-proxy-sqlite3:7.0.9-ubuntu

# --- Adicione esta linha para garantir que o apt e a instalação sejam executados como root ---
USER root 

# Variáveis para a versão do Instant Client
ENV ORACLE_IC_VERSION 19_10  
ENV ORACLE_HOME /opt/oracle/instantclient_${ORACLE_IC_VERSION}
ENV TNS_ADMIN /etc/oracle

# --- 1. Instalar Pré-requisitos (apt) ---
RUN apt update && \
    apt install -y --no-install-recommends unixodbc libaio1 unzip && \
    rm -rf /var/lib/apt/lists/*

# --- 2. Instalar o Instant Client a partir de ZIP ---
WORKDIR /opt/oracle
RUN mkdir -p ${ORACLE_HOME}

COPY ./drivers/instantclient-basic-*.zip /tmp/
COPY ./drivers/instantclient-odbc-*.zip /tmp/

RUN unzip /tmp/instantclient-basic-*.zip -d /opt/oracle && \
    unzip /tmp/instantclient-odbc-*.zip -d /opt/oracle && \
    mv /opt/oracle/instantclient*/ /opt/oracle/temp_ic && \
    mv /opt/oracle/temp_ic/* ${ORACLE_HOME}/ && \
    rmdir /opt/oracle/temp_ic && \
    rm -f /tmp/instantclient-*.zip

# --- 3. Configurar o ldconfig ---
RUN echo "${ORACLE_HOME}" > /etc/ld.so.conf.d/oracle.conf && \
    ldconfig

# --- 4. Configurar o Driver ODBC no odbcinst.ini ---
RUN echo "[Oracle 19c ODBC driver]" >> /etc/odbcinst.ini && \
    echo "Description = Oracle ODBC driver for Zabbix" >> /etc/odbcinst.ini && \
    echo "Driver      = ${ORACLE_HOME}/libsqora.so.19.1" >> /etc/odbcinst.ini && \
    echo "FileUsage   = 1" >> /etc/odbcinst.ini

# Opcional: Voltar para o usuário padrão da imagem (geralmente 'zabbix')
# USER zabbix
