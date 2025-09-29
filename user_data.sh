#!/bin/bash
# Atualizar os pacotes do sistema
sudo yum update -y

# Instalar, iniciar e configurar a inicialização automática do docker
sudo yum install docker -y
sudo systemctl start docker.service
sudo systemctl enable docker.service

# Adicionar o usuário ec2-user ao grupo docker
sudo usermod -aG docker ec2-user

#Intalação do Docker Compose
sudo yum install glibc
sudo yum install python-pip
sudo curl -L "https://github.com/docker/compose/releases/download/1.25.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo mv /usr/local/bin/docker-compose /usr/bin/docker-compose
sudo chmod +x /usr/bin/docker-compose
pip install docker-compose

# Montagem do EFS
sudo yum -y install amazon-efs-utils
sudo mkdir /mnt/efs
sudo mount -t efs -o tls < ID DO EFS >:/ /mnt/efs

# Criar um arquivo docker-compose.yml para configurar o WordPress
sudo cat <<EOL > /mnt/efs/docker-compose.yml
version: '3.8'
services:
    wordpress:
        image: wordpress:latest
        container_name: wordpress
        ports:
          - "80:80"
        environment:
          WORDPRESS_DB_HOST: <Endpoint do RDS>
          WORDPRESS_DB_NAME: <nome do database>
          WORDPRESS_DB_USER: <usuario>
          WORDPRESS_DB_PASSWORD: <senha>
        volumes:
          - /mnt/efs:/var/www/html
EOL

# Inicializar o WordPress com docker-compose e cria o banco de dados
sudo chown -R ec2-user:ec2-user /docker
sudo docker-compose -f /docker/docker-compose.yml up -d
sudo yum install mariadb-server -y
