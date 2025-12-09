# Usa a sua imagem base
FROM zabbix/zabbix-proxy-sqlite3:7.0.9-ol

# Variáveis para a versão do Instant Client
ENV ORACLE_IC_VERSION 19.10
ENV ORACLE_HOME /usr/lib/oracle/${ORACLE_IC_VERSION}/client64

# --- 1. Instalar o Instant Client e ODBC ---
# Copia os pacotes RPM para um local temporário
COPY ./drivers/oracle-instantclient*.rpm /tmp/

# Instala os pacotes Basic e ODBC, e o unixODBC (caso não esteja pré-instalado)
RUN yum install -y /tmp/oracle-instantclient*.rpm && \
    rm -f /tmp/oracle-instantclient*.rpm && \
    yum install -y unixODBC

# --- 2. Configurar o ldconfig ---
# Adiciona o caminho da biblioteca ao cache do sistema
RUN echo "${ORACLE_HOME}/lib" > /etc/ld.so.conf.d/oracle.conf && \
    ldconfig

# --- 3. Configurar o Driver ODBC no odbcinst.ini ---
# Adiciona a entrada do driver Oracle (libsqora.so.19.1)
RUN echo "[Oracle 19c ODBC driver]" >> /etc/odbcinst.ini && \
    echo "Description = Oracle ODBC driver for Zabbix" >> /etc/odbcinst.ini && \
    echo "Driver      = ${ORACLE_HOME}/lib/libsqora.so.19.1" >> /etc/odbcinst.ini && \
    echo "FileUsage   = 1" >> /etc/odbcinst.ini

# O ponto de entrada padrão da imagem Zabbix é mantido (ENTRYPOINT)
