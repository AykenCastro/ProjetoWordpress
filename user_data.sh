#!/bin/bash
# Script de User-Data para instâncias WordPress
# ATENÇÃO: Substitua os valores entre <> abaixo

# --- Variáveis (SUBSTITUIR AQUI) ---
EFS_ID="<SEU_EFS_FILE_SYSTEM_ID>"            # Ex: fs-0123456789abcdef0
DB_NAME="<NOME_DO_SEU_BANCO_DE_DADOS_RDS>"   # Ex: wordpressdb
DB_USER="<USUARIO_DO_SEU_BANCO_DE_DADOS_RDS>" # Ex: admin
DB_PASSWORD="<SENHA_DO_SEU_BANCO_DE_DADOS_RDS>"
DB_HOST="<ENDPOINT_DO_SEU_BANCO_DE_DADOS_RDS>" # Ex: wordpress-db.c12345.us-east-1.rds.amazonaws.com

# --- Início do Script ---
yum update -y
yum install -y httpd php php-mysqlnd amazon-efs-utils

# Montar o EFS na pasta de conteúdo do WordPress
EFS_MOUNT_POINT="/var/www/html/wp-content"
mkdir -p ${EFS_MOUNT_POINT}
mount -t efs -o tls ${EFS_ID}:/ ${EFS_MOUNT_POINT}

# Adicionar a montagem do EFS ao fstab para remontar após reinicializações
echo "${EFS_ID}:/ ${EFS_MOUNT_POINT} efs _netdev,tls 0 0" >> /etc/fstab

# Configurar o wp-config.php
# Atenção: Isso assume que o EFS já contém os arquivos do WordPress, exceto o wp-config.php
WP_CONFIG_FILE="/var/www/html/wp-config.php"

# Apenas cria o wp-config se ele não existir
if [ ! -f "$WP_CONFIG_FILE" ]; then
  # Use o arquivo de exemplo para criar o config
  cp /var/www/html/wp-config-sample.php ${WP_CONFIG_FILE}
  
  # Substituir os valores do banco de dados
  sed -i "s/database_name_here/${DB_NAME}/" ${WP_CONFIG_FILE}
  sed -i "s/username_here/${DB_USER}/" ${WP_CONFIG_FILE}
  sed -i "s/password_here/${DB_PASSWORD}/" ${WP_CONFIG_FILE}
  sed -i "s/localhost/${DB_HOST}/" ${WP_CONFIG_FILE}

  # Adicionar chaves de segurança únicas do WordPress
  # Baixa as chaves da API oficial e as insere no arquivo
  SALT=$(curl -L https://api.wordpress.org/secret-key/1.1/salt/)
  STRING='put your unique phrase here'
  printf '%s\n' "g/$STRING/d" a "$SALT" . w | ed -s ${WP_CONFIG_FILE}
fi

# Ajustar permissões e iniciar o Apache
chown -R apache:apache /var/www/html
systemctl enable httpd
systemctl start httpd
