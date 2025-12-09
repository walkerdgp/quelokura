# Usa uma imagem Ubuntu base. Você pode substituir por "ubuntu:22.04" ou similar.
# Para este exemplo, usaremos uma imagem Zabbix Agent (que é frequentemente baseada em Ubuntu/Debian) 
# ou você precisará instalar o binário do proxy manualmente.
# Como alternativa, se precisar do proxy, usaremos uma base Debian/Ubuntu onde o apt está disponível.
FROM zabbix/zabbix-agent:7.0.0-ubuntu

# Variáveis para a versão do Instant Client
ENV ORACLE_IC_VERSION 19_10  # Use sublinhado para o nome do diretório
ENV ORACLE_HOME /opt/oracle/instantclient_${ORACLE_IC_VERSION}
ENV TNS_ADMIN /etc/oracle

# --- 1. Instalar Pré-requisitos (apt) ---
RUN apt update && \
    # Instala unixODBC (odbc-mdbtools é uma dependência comum) e unzip
    apt install -y --no-install-recommends unixodbc unzip libaio1 && \
    rm -rf /var/lib/apt/lists/*

# --- 2. Instalar o Instant Client a partir de ZIP ---
WORKDIR /opt/oracle
# Cria o diretório de instalação
RUN mkdir -p ${ORACLE_HOME}

# Copia os pacotes ZIP e descompacta (Os arquivos ZIP descompactam para um diretório "instantclient_XX_X")
COPY ./drivers/instantclient-basic-*.zip /tmp/
COPY ./drivers/instantclient-odbc-*.zip /tmp/

RUN unzip /tmp/instantclient-basic-*.zip -d /opt/oracle && \
    unzip /tmp/instantclient-odbc-*.zip -d /opt/oracle && \
    rm -f /tmp/instantclient-*.zip && \
    # Move os conteúdos do diretório extraído para o ORACLE_HOME (ajuste o nome do diretório)
    mv /opt/oracle/instantclient*/* ${ORACLE_HOME}/ && \
    rmdir /opt/oracle/instantclient*

# --- 3. Configurar o ldconfig ---
# Adiciona o caminho da biblioteca ao cache do sistema
RUN echo "${ORACLE_HOME}" > /etc/ld.so.conf.d/oracle.conf && \
    ldconfig

# --- 4. Configurar o Driver ODBC no odbcinst.ini ---
# Adiciona o driver Oracle (libsqora.so.19.1)
RUN echo "[Oracle 19c ODBC driver]" >> /etc/odbcinst.ini && \
    echo "Description = Oracle ODBC driver for Zabbix" >> /etc/odbcinst.ini && \
    echo "Driver      = ${ORACLE_HOME}/libsqora.so.19.1" >> /etc/odbcinst.ini && \
    echo "FileUsage   = 1" >> /etc/odbcinst.ini

# O ponto de entrada padrão da imagem Zabbix é mantido
