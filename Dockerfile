# Usa a imagem oficial do Zabbix Proxy baseada em Ubuntu
FROM zabbix/zabbix-proxy-sqlite3:7.0.9-ubuntu

# --- Configurações Iniciais e Variáveis ---

# CORREÇÃO CRÍTICA: Garante que os comandos de instalação sejam executados como root
USER root 

# Variáveis para a versão do Instant Client
ENV ORACLE_IC_VERSION 19_10  
ENV ORACLE_HOME /opt/oracle/instantclient_${ORACLE_IC_VERSION}
ENV TNS_ADMIN /etc/oracle

# --- 1. INSTALAÇÃO DE PRÉ-REQUISITOS (APT + Fallback para libaio1) ---

# O operador '||' (OR) permite que, se o primeiro 'apt install' falhar (e.g., por causa do libaio1),
# ele tente a próxima instalação (sem o libaio1), e então instale o libaio1 manualmente.
RUN apt update && \
    apt install -y --no-install-recommends unixodbc libaio1 unzip wget dialog || \
    ( apt install -y --no-install-recommends unixodbc unzip wget dialog && \
      echo "libaio1 not found in repositories. Attempting manual download." && \
      # Tenta instalar libaio1 de um repositório conhecido (Ubuntu 22.04)
      wget http://archive.ubuntu.com/ubuntu/pool/main/liba/libaio/libaio1_0.3.112-13build1_amd64.deb -O /tmp/libaio1.deb && \
      dpkg -i /tmp/libaio1.deb && \
      rm /tmp/libaio1.deb \
    ) && \
    rm -rf /var/lib/apt/lists/*


# --- 2. INSTALAÇÃO DO ORACLE INSTANT CLIENT (A partir de ZIP) ---

WORKDIR /opt/oracle
RUN mkdir -p ${ORACLE_HOME}

COPY ./drivers/instantclient-basic-*.zip /tmp/
COPY ./drivers/instantclient-odbc-*.zip /tmp/

RUN unzip /tmp/instantclient-basic-*.zip -d /opt/oracle && \
    unzip /tmp/instantclient-odbc-*.zip -d /opt/oracle && \
    # Move os conteúdos para o diretório final
    mv /opt/oracle/instantclient*/ /opt/oracle/temp_ic && \
    mv /opt/oracle/temp_ic/* ${ORACLE_HOME}/ && \
    rmdir /opt/oracle/temp_ic && \
    rm -f /tmp/instantclient-*.zip

# --- 3. CONFIGURAÇÕES FINAIS ---

# Configurar o ldconfig (Caminho da biblioteca dinâmica)
RUN echo "${ORACLE_HOME}" > /etc/ld.so.conf.d/oracle.conf && \
    ldconfig

# Configurar o Driver ODBC no odbcinst.ini
RUN echo "[Oracle 19c ODBC driver]" >> /etc/odbcinst.ini && \
    echo "Description = Oracle ODBC driver for Zabbix" >> /etc/odbcinst.ini && \
    echo "Driver      = ${ORACLE_HOME}/libsqora.so.19.1" >> /etc/odbcinst.ini && \
    echo "FileUsage   = 1" >> /etc/odbcinst.ini

# Opcional: Voltar para o usuário não-root (boa prática de segurança)
# USER zabbix
