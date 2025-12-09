# Usa a imagem oficial do Zabbix Proxy baseada em Ubuntu que você especificou
FROM zabbix/zabbix-proxy-sqlite3:7.0.9-ubuntu

# Variáveis para a versão do Instant Client
ENV ORACLE_IC_VERSION 19_10  # Use sublinhado para o nome do diretório
ENV ORACLE_HOME /opt/oracle/instantclient_${ORACLE_IC_VERSION}
ENV TNS_ADMIN /etc/oracle

# --- 1. Instalar Pré-requisitos (apt) ---
# Instala unixODBC (odbc-mdbtools é uma dependência comum) e pacotes necessários para o Oracle IC
RUN apt update && \
    apt install -y --no-install-recommends unixodbc libaio1 unzip && \
    rm -rf /var/lib/apt/lists/*

# --- 2. Instalar o Instant Client a partir de ZIP ---
WORKDIR /opt/oracle
# Cria o diretório de instalação
RUN mkdir -p ${ORACLE_HOME}

# Copia os pacotes ZIP
COPY ./drivers/instantclient-basic-*.zip /tmp/
COPY ./drivers/instantclient-odbc-*.zip /tmp/

# Descompacta os arquivos para o ORACLE_HOME
# Nota: Os arquivos ZIP geralmente se descompactam para um diretório "instantclient_XX_X"
RUN unzip /tmp/instantclient-basic-*.zip -d /opt/oracle && \
    unzip /tmp/instantclient-odbc-*.zip -d /opt/oracle && \
    # Move os conteúdos para o diretório final
    mv /opt/oracle/instantclient*/ /opt/oracle/temp_ic && \
    mv /opt/oracle/temp_ic/* ${ORACLE_HOME}/ && \
    rmdir /opt/oracle/temp_ic && \
    rm -f /tmp/instantclient-*.zip

# --- 3. Configurar o ldconfig ---
# Adiciona o caminho da biblioteca ao cache do sistema (necessário para o libsqora.so)
RUN echo "${ORACLE_HOME}" > /etc/ld.so.conf.d/oracle.conf && \
    ldconfig

# --- 4. Configurar o Driver ODBC no odbcinst.ini ---
# Adiciona a entrada do driver Oracle. O driver está diretamente no ORACLE_HOME.
RUN echo "[Oracle 19c ODBC driver]" >> /etc/odbcinst.ini && \
    echo "Description = Oracle ODBC driver for Zabbix" >> /etc/odbcinst.ini && \
    echo "Driver      = ${ORACLE_HOME}/libsqora.so.19.1" >> /etc/odbcinst.ini && \
    echo "FileUsage   = 1" >> /etc/odbcinst.ini
