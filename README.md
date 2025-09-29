# Projeto Wordpress e Docker
    Projeto Wordpress em Alta-Disponibilidade utilizando ferramentas modernas e os serviços oferecidos pela AWS
    Esse projeto faz parte do programa de bolsas da Compass UOL na trilha de AWS e DevSecOps.

# Guia Detalhado: Implantação de WordPress em Alta Disponibilidade na AWS

## Introdução

Este guia tem como objetivo fornecer um passo a passo detalhado e completo para a implantação de uma plataforma WordPress em alta disponibilidade, escalável e tolerante a falhas na nuvem AWS. Utilizaremos os principais serviços gerenciados da AWS para garantir desempenho e disponibilidade, simulando um ambiente de produção real onde interrupções não podem causar indisponibilidade da aplicação.

## Arquitetura Proposta

A arquitetura proposta distribui a aplicação WordPress em múltiplas instâncias EC2, gerenciadas por um Auto Scaling Group (ASG) e balanceadas por um Application Load Balancer (ALB). O armazenamento de arquivos será centralizado e compartilhado através do Amazon Elastic File System (EFS), enquanto os dados da aplicação serão armazenados em um banco de dados relacional altamente disponível com o Amazon RDS. Recursos críticos serão isolados em subnets privadas para segurança, com acesso controlado por meio de um Bastion Host e conectividade externa via NAT Gateway.

## Pré-requisitos

Antes de iniciar a implantação, certifique-se de ter os seguintes pré-requisitos:

*   **Conta AWS Ativa**: Com permissões administrativas para criar e gerenciar recursos.
*   **AWS CLI Configurado**: A interface de linha de comando da AWS instalada e configurada com suas credenciais.
*   **Docker e Docker Compose**: Para testar o WordPress localmente (opcional, mas recomendado).
*   **Conhecimento Básico de AWS**: Familiaridade com os conceitos de VPC, EC2, RDS, EFS, ALB e ASG é útil.
*   **Editor de Texto/IDE**: Para editar arquivos de configuração e scripts.

---




## 1. Criação da VPC Personalizada

Uma Virtual Private Cloud (VPC) personalizada é o alicerce da nossa infraestrutura na AWS, proporcionando um ambiente de rede isolado e seguro para nossos recursos. Para garantir alta disponibilidade e resiliência, nossa VPC será configurada para abranger duas Availability Zones (AZs), com subnets públicas e privadas em cada uma.

### Componentes da VPC:

*   **2 Subnets Públicas**: Destinadas a recursos que precisam de acesso direto à internet, como o Application Load Balancer (ALB) e o NAT Gateway. Uma em cada AZ.
*   **4 Subnets Privadas**: Destinadas a recursos que não devem ser acessíveis diretamente pela internet, como as instâncias EC2 do WordPress e o Amazon RDS. Duas em cada AZ para maior isolamento e organização.
*   **Internet Gateway (IGW)**: Permite a comunicação entre a VPC e a internet.
*   **NAT Gateway**: Permite que instâncias em subnets privadas iniciem conexões de saída para a internet, mas impede que a internet inicie conexões com essas instâncias. Será implantado em uma subnet pública e associado a uma Elastic IP.
*   **Route Tables**: Tabelas de roteamento personalizadas para controlar o fluxo de tráfego entre as subnets e para a internet.

### Passo a Passo para Criação da VPC:

1.  **Acessar o Console AWS**: Faça login no console da AWS e navegue até o serviço VPC.
2.  **Criar VPC**: Clique em "Your VPCs" e depois em "Create VPC".
    *   **Name tag**: `wordpress-vpc`
    *   **IPv4 CIDR block**: `10.0.0.0/16` (ou outro de sua preferência)
    *   Deixe as outras opções como padrão e clique em "Create VPC".
3.  **Criar Subnets Públicas**: Crie duas subnets públicas, uma em cada AZ.
    *   Clique em "Subnets" e depois em "Create subnet".
    *   **VPC ID**: Selecione `wordpress-vpc`.
    *   **Subnet 1 (Pública - AZ1)**:
        *   **Name tag**: `wordpress-public-subnet-az1`
        *   **Availability Zone**: Escolha uma AZ (ex: `us-east-1a`)
        *   **IPv4 CIDR block**: `10.0.1.0/24`
    *   **Subnet 2 (Pública - AZ2)**:
        *   **Name tag**: `wordpress-public-subnet-az2`
        *   **Availability Zone**: Escolha outra AZ (ex: `us-east-1b`)
        *   **IPv4 CIDR block**: `10.0.2.0/24`
    *   Certifique-se de habilitar o "Auto-assign public IPv4 address" para ambas as subnets públicas. Para fazer isso, selecione a subnet, clique em "Actions" e depois em "Modify auto-assign IP settings".
4.  **Criar Subnets Privadas**: Crie quatro subnets privadas, duas em cada AZ.
    *   **Subnet 3 (Privada - AZ1 - App)**:
        *   **Name tag**: `wordpress-private-app-subnet-az1`
        *   **Availability Zone**: Mesma AZ da `wordpress-public-subnet-az1`
        *   **IPv4 CIDR block**: `10.0.3.0/24`
    *   **Subnet 4 (Privada - AZ1 - DB)**:
        *   **Name tag**: `wordpress-private-db-subnet-az1`
        *   **Availability Zone**: Mesma AZ da `wordpress-public-subnet-az1`
        *   **IPv4 CIDR block**: `10.0.4.0/24`
    *   **Subnet 5 (Privada - AZ2 - App)**:
        *   **Name tag**: `wordpress-private-app-subnet-az2`
        *   **Availability Zone**: Mesma AZ da `wordpress-public-subnet-az2`
        *   **IPv4 CIDR block**: `10.0.5.0/24`
    *   **Subnet 6 (Privada - AZ2 - DB)**:
        *   **Name tag**: `wordpress-private-db-subnet-az2`
        *   **Availability Zone**: Mesma AZ da `wordpress-public-subnet-az2`
        *   **IPv4 CIDR block**: `10.0.6.0/24`
5.  **Criar Internet Gateway (IGW)**:
    *   Clique em "Internet Gateways" e depois em "Create internet gateway".
    *   **Name tag**: `wordpress-igw`
    *   Após a criação, selecione o IGW, clique em "Actions" e depois em "Attach to VPC". Selecione `wordpress-vpc`.
6.  **Criar NAT Gateway**: Crie um NAT Gateway em uma das subnets públicas.
    *   Clique em "NAT Gateways" e depois em "Create NAT gateway".
    *   **Name tag**: `wordpress-nat-gateway-az1`
    *   **Subnet**: Selecione `wordpress-public-subnet-az1`.
    *   **Elastic IP allocation ID**: Clique em "Allocate Elastic IP" para criar um novo EIP e associe-o.
    *   Clique em "Create NAT gateway".
7.  **Configurar Route Tables**: Crie e associe as tabelas de roteamento.
    *   **Route Table Pública**: Por padrão, uma Route Table é criada com a VPC. Renomeie-a para `wordpress-public-rt`.
        *   Selecione `wordpress-public-rt`, vá em "Routes" e clique em "Edit routes".
        *   Adicione uma rota: **Destination**: `0.0.0.0/0`, **Target**: Selecione o `wordpress-igw`.
        *   Vá em "Subnet associations" e associe `wordpress-public-subnet-az1` e `wordpress-public-subnet-az2`.
    *   **Route Table Privada (AZ1)**:
        *   Clique em "Route Tables" e depois em "Create route table".
        *   **Name tag**: `wordpress-private-rt-az1`
        *   **VPC**: Selecione `wordpress-vpc`.
        *   Selecione `wordpress-private-rt-az1`, vá em "Routes" e clique em "Edit routes".
        *   Adicione uma rota: **Destination**: `0.0.0.0/0`, **Target**: Selecione o `wordpress-nat-gateway-az1`.
        *   Vá em "Subnet associations" e associe `wordpress-private-app-subnet-az1` e `wordpress-private-db-subnet-az1`.
    *   **Route Table Privada (AZ2)**: Para alta disponibilidade, é recomendado criar um segundo NAT Gateway em `wordpress-public-subnet-az2` e uma segunda Route Table privada para as subnets privadas da AZ2, apontando para este novo NAT Gateway. Para este guia, vamos considerar a implantação de um único NAT Gateway para simplificar, mas em um ambiente de produção, a redundância é crucial.
        *   Clique em "Route Tables" e depois em "Create route table".
        *   **Name tag**: `wordpress-private-rt-az2`
        *   **VPC**: Selecione `wordpress-vpc`.
        *   Selecione `wordpress-private-rt-az2`, vá em "Routes" e clique em "Edit routes".
        *   Adicione uma rota: **Destination**: `0.0.0.0/0`, **Target**: Selecione o `wordpress-nat-gateway-az1` (ou um novo NAT Gateway em AZ2, se você optar por criá-lo).
        *   Vá em "Subnet associations" e associe `wordpress-private-app-subnet-az2` e `wordpress-private-db-subnet-az2`.

Com a VPC configurada, temos a base de rede para os próximos passos da implantação do WordPress em alta disponibilidade.

---




## 2. Criação do Amazon RDS

O Amazon Relational Database Service (RDS) fornecerá um banco de dados MySQL/MariaDB altamente disponível e gerenciado para o WordPress. Isso elimina a necessidade de gerenciar a infraestrutura do banco de dados, permitindo que nos concentremos na aplicação. Conforme o documento do projeto, utilizaremos uma instância Multi-AZ para resiliência e um grupo de segurança para controlar o acesso.

### Componentes do RDS:

*   **Instância Multi-AZ**: Para alta disponibilidade e failover automático em caso de falha na AZ primária.
*   **MySQL/MariaDB**: O motor de banco de dados escolhido para o WordPress.
*   **Grupo de Segurança**: Para permitir acesso apenas das instâncias EC2 do WordPress.
*   **Subnets Privadas**: O RDS será implantado nas subnets privadas para maior segurança, sem acesso direto da internet.

### Passo a Passo para Criação do RDS:

1.  **Criar Grupo de Segurança para as Instâncias EC2 (Melhor Prática)**: Antes de criar o Security Group para o RDS, é uma melhor prática criar primeiro o Security Group que será usado pelas instâncias EC2 do WordPress. Isso nos permite referenciar diretamente o Security Group das instâncias EC2 na regra de entrada do Security Group do RDS, garantindo uma configuração mais segura e precisa desde o início.
    *   No console da AWS, navegue até "EC2" -> "Security Groups" e clique em "Create security group".
    *   **Security group name**: `wordpress-ec2-sg`
    *   **Description**: `Security Group for WordPress EC2 instances`
    *   **VPC**: Selecione `wordpress-vpc`.
    *   **Inbound rules**: Deixe as regras de entrada em branco por enquanto. Adicionaremos as regras necessárias posteriormente.
    *   Clique em "Create security group".

2.  **Criar Grupo de Segurança para RDS**: Agora, com o `wordpress-ec2-sg` criado, podemos criar o Security Group para o RDS e referenciar o `wordpress-ec2-sg` em sua regra de entrada.
    *   No console da AWS, navegue até "EC2" -> "Security Groups" e clique em "Create security group".
    *   **Security group name**: `wordpress-rds-sg`
    *   **Description**: `Allow access to RDS from WordPress EC2 instances`
    *   **VPC**: Selecione `wordpress-vpc`.
    *   **Inbound rules**: Adicione uma regra:
        *   **Type**: `MySQL/Aurora` (ou `MariaDB`)
        *   **Protocol**: `TCP`
        *   **Port range**: `3306`
        *   **Source**: No campo de busca, digite `wordpress-ec2-sg` e selecione o Security Group que você acabou de criar. Isso garantirá que apenas as instâncias EC2 associadas ao `wordpress-ec2-sg` possam acessar o banco de dados na porta 3306.
    *   Clique em "Create security group".
2.  **Criar Subnet Group para RDS**: O RDS precisa de um grupo de subnets para ser implantado em múltiplas AZs.
    *   No console da AWS, navegue até "RDS" -> "Subnet groups" e clique em "Create DB subnet group".
    *   **Name**: `wordpress-db-subnet-group`
    *   **Description**: `Subnet group for WordPress RDS instances`
    *   **VPC**: Selecione `wordpress-vpc`.
    *   **Add subnets**: Selecione as subnets privadas destinadas ao banco de dados: `wordpress-private-db-subnet-az1` e `wordpress-private-db-subnet-az2`.
3.  **Criar Instância RDS**: Agora, crie a instância do banco de dados.
    *   No console da AWS, navegue até "RDS" -> "Databases" e clique em "Create database".
    *   **Choose a database creation method**: `Standard create`
    *   **Engine options**: `MySQL` (ou `MariaDB`)
    *   **Engine version**: Escolha a versão mais recente compatível com WordPress.
    *   **Templates**: `Free tier` (para fins de teste e custo, conforme o documento original menciona `db.t3g.micro` e sem Multi-AZ para restrições de conta, mas para alta disponibilidade, o ideal é Multi-AZ).
        *   **Nota Importante**: O documento original menciona `db.t3g.micro` e *sem a opção de Multi-AZ* devido a restrições de conta. Para um ambiente de produção em alta disponibilidade, **Multi-AZ é fortemente recomendado**. Se as restrições da sua conta permitirem, selecione `Multi-AZ deployment` -> `Create a standby instance`.
    *   **DB instance identifier**: `wordpress-db-instance`
    *   **Master username**: `admin` (ou outro de sua escolha)
    *   **Master password**: Defina uma senha forte e anote-a.
    *   **DB instance size**: `Burstable classes (includes t classes)` -> `db.t3g.micro` (conforme especificado no documento).
    *   **Storage**: `General Purpose SSD (gp2)` ou `gp3`.
    *   **Connectivity**:
        *   **Virtual private cloud (VPC)**: `wordpress-vpc`
        *   **Subnet group**: `wordpress-db-subnet-group`
        *   **Public access**: `No`
        *   **VPC security groups**: Escolha `Existing` e selecione `wordpress-rds-sg`.
    *   **Additional configuration**:
        *   **Database name**: `wordpress`
    *   Deixe as outras opções como padrão ou ajuste conforme necessário.
    *   Clique em "Create database".

Aguarde a instância do RDS ser criada e ficar disponível. Anote o endpoint do RDS, pois ele será necessário para configurar o WordPress.

---




## 3. Criação do Amazon EFS

O Amazon Elastic File System (EFS) é um sistema de arquivos de rede escalável e totalmente gerenciado que permite que várias instâncias EC2 acessem os mesmos dados simultaneamente. Isso é crucial para uma implantação de WordPress em alta disponibilidade, pois garante que todos os arquivos do WordPress (temas, plugins, uploads de mídia) sejam consistentes em todas as instâncias do Auto Scaling Group.

### Componentes do EFS:

*   **Sistema de Arquivos NFS**: O EFS utiliza o protocolo NFS (Network File System) para montagem nas instâncias EC2.
*   **Montagem via User-Data**: As instâncias EC2 serão configuradas para montar o EFS automaticamente durante a inicialização, usando um script `user-data`.
*   **Grupo de Segurança**: Para controlar o acesso ao EFS, permitindo conexões apenas das instâncias EC2 do WordPress.

### Passo a Passo para Criação do EFS:

1.  **Criar Grupo de Segurança para EFS**: Este grupo de segurança permitirá que as instâncias EC2 do WordPress se conectem ao EFS. É crucial que o Security Group das instâncias EC2 (`wordpress-ec2-sg`) já tenha sido criado (conforme detalhado na seção de criação do RDS) para que possamos referenciá-lo aqui.
    *   No console da AWS, navegue até "EC2" -> "Security Groups" e clique em "Create security group".
    *   **Security group name**: `wordpress-efs-sg`
    *   **Description**: `Allow NFS access to EFS from WordPress EC2 instances`
    *   **VPC**: Selecione `wordpress-vpc`.
    *   **Inbound rules**: Adicione uma regra:
        *   **Type**: `NFS`
        *   **Protocol**: `TCP`
        *   **Port range**: `2049`
        *   **Source**: No campo de busca, digite `wordpress-ec2-sg` e selecione o Security Group que você criou anteriormente para as instâncias EC2 do WordPress. Isso garante que apenas as instâncias EC2 do WordPress (que estão no `wordpress-ec2-sg`) possam montar e acessar o sistema de arquivos EFS. Esta é a melhor prática para garantir que o acesso ao EFS seja restrito apenas aos recursos autorizados.
2.  **Criar Sistema de Arquivos EFS**: Agora, crie o sistema de arquivos EFS.
    *   No console da AWS, navegue até "EFS" -> "File systems" e clique em "Create file system".
    *   **Name**: `wordpress-efs`
    *   **VPC**: Selecione `wordpress-vpc`.
    *   **Availability and durability**: `Regional` (recomendado para alta disponibilidade).
    *   **Performance settings**: `General Purpose` (modo de desempenho padrão, adequado para a maioria das cargas de trabalho do WordPress).
    *   **Throughput mode**: `Bursting` (modo de throughput padrão, escala com o tamanho do sistema de arquivos).
    *   Clique em "Next Step".
    *   **Network access**: Para cada Availability Zone, selecione as subnets privadas de aplicação (`wordpress-private-app-subnet-az1`, `wordpress-private-app-subnet-az2`) e associe o `wordpress-efs-sg` que você acabou de criar.
    *   Clique em "Next Step" para revisar e depois em "Create file system".

Aguarde a criação do EFS. Após a criação, você precisará do ID do sistema de arquivos EFS e do DNS de montagem para configurar as instâncias EC2. Anote essas informações.

---




## 4. Criação da AMI Base (Opcional)

A criação de uma Amazon Machine Image (AMI) personalizada é um passo opcional, mas altamente recomendado para otimizar o tempo de inicialização das instâncias EC2 e garantir a consistência do ambiente. Em vez de instalar o Apache, PHP e WordPress em cada nova instância, podemos pré-configurar uma imagem com esses componentes. Isso é especialmente útil em cenários de Auto Scaling, onde novas instâncias precisam estar prontas para servir tráfego rapidamente.

### Passo a Passo para Criação da AMI Base:

1.  **Criar Grupo de Segurança Temporário para a Instância AMI Builder**: Antes de lançar a instância temporária, crie um Security Group específico para ela. Este SG permitirá o acesso SSH para configuração e, temporariamente, HTTP/HTTPS para testes.
    *   No console da AWS, navegue até "EC2" -> "Security Groups" e clique em "Create security group".
    *   **Security group name**: `wordpress-ami-builder-sg`
    *   **Description**: `Temporary Security Group for AMI builder instance`
    *   **VPC**: Selecione `wordpress-vpc`.
    *   **Inbound rules**: Adicione as seguintes regras:
        *   **Rule 1 (SSH)**:
            *   **Type**: `SSH`
            *   **Protocol**: `TCP`
            *   **Port range**: `22`
            *   **Source**: `My IP` (para permitir acesso apenas do seu endereço IP atual, ou `0.0.0.0/0` se você não tiver um IP estático e entender os riscos de segurança).
        *   **Rule 2 (HTTP - Temporário)**:
            *   **Type**: `HTTP`
            *   **Protocol**: `TCP`
            *   **Port range**: `80`
            *   **Source**: `0.0.0.0/0` (para testes iniciais, será removido após a criação da AMI).
        *   **Rule 3 (HTTPS - Temporário)**:
            *   **Type**: `HTTPS`
            *   **Protocol**: `TCP`
            *   **Port range**: `443`
            *   **Source**: `0.0.0.0/0` (para testes iniciais, será removido após a criação da AMI).
    *   Clique em "Create security group".

2.  **Lançar uma Instância EC2 Temporária**: Esta instância será a base para a nossa AMI. Ela será configurada com o software necessário e depois transformada em uma imagem.
    *   No console da AWS, navegue até "EC2" -> "Instances" e clique em "Launch instances".
    *   **Name**: `wordpress-ami-builder`
    *   **Application and OS Images (Amazon Machine Image)**: Selecione uma AMI base. Recomenda-se `Amazon Linux 2023 AMI` para compatibilidade e otimização com a AWS, ou `Ubuntu Server 22.04 LTS` se você tiver preferência por Debian-based systems.
    *   **Instance type**: `t3.micro` (ou `t2.micro` se `t3.micro` não estiver disponível no Free Tier da sua região).
    *   **Key pair (login)**: Crie um novo par de chaves (ex: `wordpress-ami-keypair`) ou selecione um existente. **É fundamental que você baixe e salve o arquivo `.pem` da chave privada em um local seguro, pois ele será necessário para acessar a instância via SSH.**
    *   **Network settings**:
        *   **VPC**: Selecione `wordpress-vpc`.
        *   **Subnet**: Selecione `wordpress-public-subnet-az1`. Escolhemos uma subnet pública para facilitar o acesso SSH inicial e a instalação de pacotes da internet. Esta instância será terminada após a criação da AMI.
        *   **Auto-assign public IP**: Certifique-se de que esteja `Enable` para que a instância receba um IP público e possa ser acessada via SSH e internet.
        *   **Security group**: Escolha `Select existing security group` e selecione o `wordpress-ami-builder-sg` que você criou no passo anterior.
    *   **Configure storage**: Mantenha o padrão (geralmente 8 GiB para Amazon Linux) ou aumente se necessário (ex: 20 GiB) para acomodar o WordPress e outros softwares. Certifique-se de que o tipo de volume seja `gp2` ou `gp3`.
    *   Clique em "Launch instance".

3.  **Conectar à Instância e Instalar Software**: Após a instância `wordpress-ami-builder` ser lançada e seu status mudar para `Running` (em execução), você precisará se conectar a ela via SSH para instalar e configurar o software necessário. Siga os passos abaixo:

    *   **3.1. Obter o Endereço IP Público da Instância**: No console da AWS:
        1.  Navegue até "EC2" -> "Instances" no painel de navegação esquerdo.
        2.  Localize e selecione a instância `wordpress-ami-builder` na lista.
        3.  Na aba "Details" (Detalhes) na parte inferior, procure por "Public IPv4 address" (Endereço IPv4 Público) e copie o valor. Este será o endereço que você usará para se conectar via SSH.

    *   **3.2. Conectar-se à Instância via SSH**: Abra um terminal ou prompt de comando em sua máquina local e siga estas instruções:
        1.  **Verifique as Permissões da Chave Privada**: O arquivo `.pem` da sua chave privada (que você baixou ao criar o par de chaves) deve ter permissões restritivas para que o SSH funcione corretamente. Execute o seguinte comando, substituindo `caminho/para/sua-chave.pem` pelo caminho completo do arquivo em seu sistema:
            ```bash
            chmod 400 /caminho/para/sua-chave.pem
            ```
        2.  **Estabeleça a Conexão SSH**: Use o comando `ssh` para se conectar à instância. O usuário padrão varia de acordo com a AMI que você escolheu:
            *   **Para Amazon Linux (ex: Amazon Linux 2023 AMI)**, o usuário padrão é `ec2-user`:
                ```bash
                ssh -i /caminho/para/sua-chave.pem ec2-user@<SEU_IP_PUBLICO>
                ```
            *   **Para Ubuntu (ex: Ubuntu Server 22.04 LTS)**, o usuário padrão é `ubuntu`:
                ```bash
                ssh -i /caminho/para/sua-chave.pem ubuntu@<SEU_IP_PUBLICO>
                ```
            Substitua `<SEU_IP_PUBLICO>` pelo endereço IP público que você copiou no passo anterior.

    *   **3.3. Instalar e Configurar o Servidor Web e PHP**: Uma vez conectado à instância via SSH, execute os comandos apropriados para o sistema operacional da sua AMI para instalar o servidor web (Apache) e o PHP com as extensões necessárias para o WordPress.

        *   **Para Amazon Linux 2023 (recomendado)**:
            1.  **Atualizar o Sistema e Instalar Pacotes**: Execute os comandos para atualizar os pacotes do sistema e instalar o Apache (`httpd`), PHP e as extensões PHP essenciais para o WordPress (como `php-mysqlnd` para conexão com MySQL/MariaDB e `php-gd` para manipulação de imagens).
                ```bash
                sudo yum update -y
                sudo yum install -y httpd php php-mysqlnd php-gd
                ```
            2.  **Iniciar e Habilitar o Apache**: Inicie o serviço Apache e configure-o para iniciar automaticamente a cada boot da instância.
                ```bash
                sudo systemctl start httpd
                sudo systemctl enable httpd
                ```
            *   **Observação Importante**: Diferente de algumas versões mais antigas, o pacote `wordpress` não é instalado diretamente via `yum` ou `apt` para esta arquitetura. Faremos o download manual do WordPress em um passo posterior para garantir a versão mais recente e maior flexibilidade na configuração.

        *   **Para Ubuntu Server 22.04 LTS**:
            1.  **Atualizar o Sistema e Instalar Pacotes**: Execute os comandos para atualizar os pacotes do sistema e instalar o Apache (`apache2`), PHP e as extensões PHP essenciais para o WordPress.
                ```bash
                sudo apt update -y
                sudo apt install -y apache2 php libapache2-mod-php php-mysql php-gd
                ```
            2.  **Iniciar e Habilitar o Apache**: Inicie o serviço Apache e configure-o para iniciar automaticamente a cada boot da instância.
                ```bash
                sudo systemctl start apache2
                sudo systemctl enable apache2
                ```
            *   **Observação Importante**: Assim como no Amazon Linux, o pacote `wordpress` não é instalado diretamente. O download e a configuração do WordPress serão feitos manualmente em um passo subsequente.

4.  **Download e Preparação do WordPress**: Nesta etapa, você fará o download dos arquivos do WordPress, os moverá para o diretório do servidor web e ajustará as permissões. Além disso, preparará o diretório que será usado para a montagem do EFS e instalará as utilidades necessárias para o EFS.

    *   **4.1. Navegar para um Diretório Temporário e Baixar o WordPress**:
        1.  Mude para o diretório `/tmp`, que é um local comum para arquivos temporários:
            ```bash
            cd /tmp
            ```
        2.  Baixe a versão mais recente do WordPress. O comando `wget` fará o download do arquivo compactado:
            ```bash
            wget https://wordpress.org/latest.tar.gz
            ```
        3.  Descompacte o arquivo baixado. Isso criará um diretório chamado `wordpress` contendo todos os arquivos da aplicação:
            ```bash
            tar -xzf latest.tar.gz
            ```

    *   **4.2. Mover os Arquivos do WordPress para o Diretório Web Padrão**:
        1.  Copie recursivamente todo o conteúdo do diretório `wordpress` (que você acabou de descompactar) para o diretório raiz do seu servidor web. Para Apache, este é geralmente `/var/www/html/`:
            ```bash
            sudo cp -r wordpress/* /var/www/html/
            ```

    *   **4.3. Ajustar as Permissões dos Arquivos e Diretórios do WordPress**: É crucial definir as permissões corretas para que o servidor web possa ler e escrever nos arquivos do WordPress, garantindo segurança e funcionalidade.
        1.  **Alterar o Proprietário**: Mude o proprietário dos arquivos e diretórios do WordPress para o usuário e grupo do servidor web. Isso permite que o Apache (ou Nginx) gerencie os arquivos.
            *   **Para Amazon Linux (usuário/grupo `apache`)**:
                ```bash
                sudo chown -R apache:apache /var/www/html
                ```
            *   **Para Ubuntu (usuário/grupo `www-data`)**:
                ```bash
                sudo chown -R www-data:www-data /var/www/html
                ```
        2.  **Definir Permissões de Diretórios**: Defina as permissões para diretórios como `755` (leitura, escrita e execução para o proprietário; leitura e execução para o grupo e outros).
            ```bash
            sudo find /var/www/html -type d -exec chmod 755 {} \;
            ```
        3.  **Definir Permissões de Arquivos**: Defina as permissões para arquivos como `644` (leitura e escrita para o proprietário; leitura para o grupo e outros).
            ```bash
            sudo find /var/www/html -type f -exec chmod 644 {} \;
            ```

    *   **4.4. Criar o Diretório para Uploads e Instalar Utilitários do EFS**:
        1.  **Criar Diretório de Uploads**: Crie o diretório `wp-content/uploads` dentro da instalação do WordPress. Este será o ponto de montagem para o EFS, onde o WordPress armazenará mídias e outros arquivos gerados.
            ```bash
            sudo mkdir -p /var/www/html/wp-content/uploads
            ```
        2.  **Ajustar Permissões do Diretório de Uploads**: Garanta que o servidor web tenha permissão para escrever neste diretório.
            *   **Para Amazon Linux**:
                ```bash
                sudo chown -R apache:apache /var/www/html/wp-content/uploads
                ```
            *   **Para Ubuntu**:
                ```bash
                sudo chown -R www-data:www-data /var/www/html/wp-content/uploads
                ```
        3.  **Instalar Utilitários do EFS e NFS**: Instale os pacotes necessários para que a instância possa montar sistemas de arquivos NFS, incluindo o EFS.
            *   **Para Amazon Linux**:
                ```bash
                sudo yum install -y amazon-efs-utils nfs-utils
                ```
            *   **Para Ubuntu**:
                ```bash
                sudo apt install -y nfs-common
                ```

    *   **4.5. Configurar o Arquivo `wp-config.php` (Configurações Básicas para a AMI)**: O arquivo `wp-config.php` é o coração da configuração do WordPress. Para a AMI base, faremos uma configuração inicial, mas as informações sensíveis (como credenciais do banco de dados) serão injetadas dinamicamente via `user-data` no Launch Template.
        1.  **Copiar o Arquivo de Exemplo**: Copie o arquivo de configuração de exemplo para `wp-config.php`:
            ```bash
            sudo cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php
            ```
        2.  **Gerar e Inserir Chaves de Segurança Únicas (Salts)**: O WordPress usa chaves de segurança (salts) para aumentar a segurança de cookies e senhas. É uma boa prática gerar novas chaves para cada instalação. Você pode obter chaves aleatórias do serviço API do WordPress e inseri-las no `wp-config.php`:
            ```bash
            SALT=$(curl -L https://api.wordpress.org/secret-key/1.1/salt/)
            printf '%s\n' "g/put your unique phrase here/d" "a\n${SALT}" "" | sudo ed -s /var/www/html/wp-config.php
            ```
        *   **Observação Importante**: Lembre-se que o EFS *não será montado permanentemente* nesta instância AMI builder. A montagem real do EFS e a configuração final do `wp-config.php` com os detalhes do RDS e EFS serão realizadas pelo script `user-data` nas instâncias lançadas pelo Auto Scaling Group. O objetivo desta etapa é apenas preparar a imagem com os arquivos e dependências básicas.

5.  **Montagem e Desmontagem Temporária do EFS (para copiar arquivos)**: Embora o EFS não seja montado permanentemente na AMI, podemos montá-lo temporariamente para copiar arquivos essenciais para a estrutura do WordPress, se necessário, ou para validar a conectividade. No entanto, a melhor prática é que o `user-data` do Launch Template cuide da montagem do EFS nas instâncias do ASG.
    *   **Para fins de teste ou cópia inicial de arquivos (se você tiver conteúdo pré-existente no EFS que precise ser incluído na AMI)**:
        *   **Instale o cliente NFS (se ainda não o fez)**:
            *   **Amazon Linux**: `sudo yum install -y amazon-efs-utils nfs-utils`
            *   **Ubuntu**: `sudo apt install -y nfs-common`
        *   **Crie um ponto de montagem temporário para o EFS**:
            ```bash
            sudo mkdir -p /mnt/efs-temp
            ```
        *   **Monte o EFS (substitua `EFS_ID` pelo ID do seu EFS e `us-east-1` pela sua região)**:
            ```bash
            sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport EFS_ID.efs.us-east-1.amazonaws.com:/ /mnt/efs-temp
            ```
        *   **Copie os arquivos necessários (exemplo)**:
            ```bash
            sudo cp -r /mnt/efs-temp/* /var/www/html/wp-content/uploads/
            ```
        *   **Desmonte o EFS após copiar os arquivos**: É crucial desmontar o EFS antes de criar a AMI para evitar problemas de dependência.
            ```bash
            sudo umount /mnt/efs-temp
            sudo rm -rf /mnt/efs-temp
            ```

6.  **Criar a AMI**: Após a configuração e instalação de todo o software e a preparação dos diretórios, crie a imagem da sua instância temporária.
    *   No console da AWS, selecione a instância `wordpress-ami-builder`.
    *   Clique em "Actions" -> "Image and templates" -> "Create image".
    *   **Image name**: `wordpress-base-ami`
    *   **Image description**: `Base AMI for WordPress with Apache, PHP, EFS utilities, and WordPress core files pre-installed`
    *   **No reboot**: Marque esta opção se você quiser criar a AMI sem reiniciar a instância. Isso pode ser útil para evitar tempo de inatividade, mas pode resultar em uma imagem com dados inconsistentes se houver processos em execução que escrevem no disco. Para uma AMI base, geralmente é seguro deixar desmarcado.
    *   Deixe as outras opções como padrão e clique em "Create image".

7.  **Terminar a Instância Temporária**: Após a criação bem-sucedida da AMI, você pode terminar a instância `wordpress-ami-builder` para evitar custos desnecessários.
    *   No console da AWS, selecione a instância `wordpress-ami-builder`.
    *   Clique em "Instance state" -> "Terminate instance".
    *   Confirme a terminação.

Com a AMI base criada, as novas instâncias do Auto Scaling Group poderão ser lançadas mais rapidamente, já com o ambiente do WordPress pré-configurado e as dependências para o EFS instaladas. Isso otimiza o tempo de inicialização e garante a consistência entre as instâncias.
    *   Instale o cliente NFS:
        *   **Amazon Linux**: `sudo yum install -y amazon-efs-utils nfs-utils`
        *   **Ubuntu**: `sudo apt install -y nfs-common`
    *   Crie um ponto de montagem para o EFS:
        ```bash
        sudo mkdir /var/www/html/wp-content/uploads
        sudo chown -R apache:apache /var/www/html/wp-content/uploads # Para Amazon Linux
        sudo chown -R www-data:www-data /var/www/html/wp-content/uploads # Para Ubuntu
        ```
    *   Monte o EFS (substitua `EFS_DNS_NAME` pelo DNS do seu EFS):
        ```bash
        sudo mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport EFS_DNS_NAME:/ /var/www/html/wp-content/uploads
        ```
    *   Copie os arquivos do WordPress para o diretório web (se ainda não estiverem lá, dependendo da AMI base).
    *   Desmonte o EFS após copiar os arquivos necessários para a estrutura de diretórios, pois a montagem final será feita via `user-data` no Launch Template.
        ```bash
        sudo umount /var/www/html/wp-content/uploads
        ```

4.  **Criar a AMI**: Após a configuração, crie a imagem.
    *   No console da AWS, selecione a instância `wordpress-ami-builder`.
    *   Clique em "Actions" -> "Image and templates" -> "Create image".
    *   **Image name**: `wordpress-base-ami`
    *   **Image description**: `Base AMI for WordPress with Apache and PHP pre-installed`
    *   Deixe as outras opções como padrão e clique em "Create image".

5.  **Terminar a Instância Temporária**: Após a criação da AMI, você pode terminar a instância `wordpress-ami-builder` para evitar custos.

Com a AMI base criada, as novas instâncias do Auto Scaling Group poderão ser lançadas mais rapidamente, já com o ambiente do WordPress pré-configurado.

---




## 5. Criação do Launch Template

O Launch Template é um recurso essencial do EC2 que funciona como um "molde" para a criação de novas instâncias. Ele captura todos os parâmetros de configuração – como a AMI, tipo de instância, redes, armazenamento e scripts de inicialização – em um único recurso versionado. Usar um Launch Template com um Auto Scaling Group (ASG) garante que todas as instâncias lançadas sejam consistentes e configuradas corretamente, o que é fundamental para a estabilidade e escalabilidade da nossa aplicação WordPress.

Neste passo, vamos criar um Launch Template que utiliza a `wordpress-base-ami` que preparamos, associa as instâncias ao Security Group correto e executa um script `user-data` poderoso para automatizar a configuração final de cada instância no momento do boot. Isso inclui a montagem do sistema de arquivos EFS e a configuração dinâmica do arquivo `wp-config.php` com as informações do banco de dados RDS.

### Passo a Passo para Criação do Launch Template:

1.  **Criar um IAM Role para as Instâncias EC2**: Para seguir as melhores práticas de segurança, as instâncias EC2 não devem ter credenciais da AWS armazenadas diretamente. Em vez disso, criaremos um IAM Role que concede às instâncias as permissões necessárias para interagir com outros serviços da AWS, como o EFS e o Systems Manager (para gerenciamento).
    *   No console da AWS, navegue até "IAM" -> "Roles" e clique em "Create role".
    *   **Select trusted entity**: Escolha `AWS service`.
    *   **Use case**: Selecione `EC2` e clique em "Next".
    *   **Add permissions**: Na barra de pesquisa, procure e adicione as seguintes políticas gerenciadas pela AWS:
        *   `AmazonSSMManagedInstanceCore`: Permite que o AWS Systems Manager gerencie a instância (útil para patches, automação e acesso seguro sem SSH).
        *   `AmazonEFSClientReadWrite`: Concede permissões para montar e interagir com sistemas de arquivos EFS. (Embora a montagem NFS não exija diretamente permissões IAM, ter essa política é uma boa prática para futuras integrações e uso de ferramentas como o EFS Mount Helper).
    *   Clique em "Next".
    *   **Role name**: `wordpress-ec2-role`
    *   **Description**: `IAM role for WordPress EC2 instances to allow access to SSM and EFS.`
    *   Revise as configurações e clique em "Create role".

2.  **Criar o Launch Template**: Agora, vamos criar o Launch Template que definirá a configuração de nossas instâncias WordPress.
    *   No console da AWS, navegue até "EC2" -> "Launch Templates" e clique em "Create launch template".
    *   **Launch template name**: `wordpress-launch-template`
    *   **Template version description**: `Initial version for WordPress ASG`
    *   **Auto Scaling guidance**: Marque a caixa de seleção "Provide guidance to help me set up a template for use with EC2 Auto Scaling".

3.  **Configurar os Detalhes do Launch Template**:

    *   **Application and OS Images (Amazon Machine Image)**:
        *   Vá para a aba "My AMIs" e selecione a `wordpress-base-ami` que você criou anteriormente.

    *   **Instance type**:
        *   Selecione o tipo de instância que você deseja usar, por exemplo, `t3.micro` ou `t2.micro`.

    *   **Key pair (login)**:
        *   **NÃO** selecione um par de chaves. Em um ambiente de produção automatizado, o acesso direto via SSH às instâncias deve ser evitado. Usaremos o AWS Systems Manager Session Manager (habilitado pela IAM Role que criamos) para acesso seguro quando necessário.

    *   **Network settings**:
        *   **Subnet**: **NÃO** selecione uma subnet. O Auto Scaling Group se encarregará de lançar as instâncias nas subnets corretas que definiremos para ele.
        *   **Security groups**: Escolha `Select existing security group` e selecione o `wordpress-ec2-sg`.

    *   **Advanced details**: Expanda esta seção para configurar o IAM Role e o script `user-data`.
        *   **IAM instance profile**: No campo de busca, selecione o `wordpress-ec2-role` que você criou.
        *   **User data**: Este é o passo mais crítico da automação. Cole o script abaixo no campo de texto. Este script será executado toda vez que uma nova instância for lançada. **Substitua os placeholders `EFS_ID`, `DB_HOST`, `DB_USER`, `DB_PASSWORD` e `DB_NAME` pelos valores reais da sua infraestrutura.**

            ```bash
            #!/bin/bash -xe
            # Log all output to /var/log/user-data.log
            exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

            # --- Variáveis (Substitua pelos seus valores) ---
            EFS_ID="fs-xxxxxxxxxxxxxxxxx" # ID do seu File System EFS
            DB_HOST="wordpress-db-instance.xxxxxxxxxxxx.us-east-1.rds.amazonaws.com" # Endpoint do seu RDS
            DB_USER="admin" # Usuário do banco de dados
            DB_PASSWORD="sua-senha-super-secreta" # Senha do banco de dados
            DB_NAME="wordpress" # Nome do banco de dados

            # --- Montagem do EFS ---
            echo "Montando o EFS..."
            EFS_MOUNT_POINT="/var/www/html/wp-content/uploads"
            # Monta o EFS no diretório de uploads do WordPress
            mount -t nfs4 -o nfsvers=4.1,rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2,noresvport ${EFS_ID}.efs.us-east-1.amazonaws.com:/ ${EFS_MOUNT_POINT}

            # --- Configuração do wp-config.php ---
            echo "Configurando o wp-config.php..."
            WP_CONFIG_FILE="/var/www/html/wp-config.php"

            # Substitui os placeholders no wp-config.php com os valores reais
            sed -i "s/database_name_here/${DB_NAME}/g" ${WP_CONFIG_FILE}
            sed -i "s/username_here/${DB_USER}/g" ${WP_CONFIG_FILE}
            sed -i "s/password_here/${DB_PASSWORD}/g" ${WP_CONFIG_FILE}
            sed -i "s/localhost/${DB_HOST}/g" ${WP_CONFIG_FILE}

            # --- Reiniciar o Servidor Web ---
            echo "Reiniciando o Apache..."
            # Para Amazon Linux
            if [ -f /usr/sbin/httpd ]; then
                systemctl restart httpd
            # Para Ubuntu
            elif [ -f /usr/sbin/apache2 ]; then
                systemctl restart apache2
            fi

            echo "Configuração da instância concluída com sucesso!"
            ```

4.  **Criar o Launch Template**: Revise todas as configurações e clique em "Create launch template".

Com o Launch Template criado, agora temos um modelo robusto e automatizado para lançar instâncias WordPress perfeitamente configuradas. O próximo passo é usar este template para criar um Auto Scaling Group, que gerenciará o ciclo de vida e a escalabilidade das nossas instâncias.



---




## 6. Criação do Auto Scaling Group (ASG)

O Auto Scaling Group (ASG) é um serviço fundamental para garantir a alta disponibilidade e escalabilidade do nosso ambiente WordPress. Ele monitora a saúde das instâncias EC2 e ajusta automaticamente o número de instâncias com base na demanda, substituindo instâncias não saudáveis e garantindo que a aplicação esteja sempre disponível.

### Componentes do ASG:

*   **Launch Template**: Utiliza o `wordpress-launch-template` criado anteriormente para provisionar novas instâncias.
*   **Subnets Privadas**: As instâncias EC2 do WordPress serão lançadas nas subnets privadas de aplicação para maior segurança.
*   **Políticas de Escalamento**: Definiremos políticas para escalar o número de instâncias com base na utilização da CPU.
*   **Health Checks**: O ASG monitorará a saúde das instâncias e as substituirá automaticamente se falharem.

### Passo a Passo para Criação do Auto Scaling Group:

1.  **Criar o Auto Scaling Group**: 
    *   No console da AWS, navegue até "EC2" -> "Auto Scaling Groups" e clique em "Create Auto Scaling group".
    *   **Auto Scaling group name**: `wordpress-asg`
    *   **Launch template**: Selecione `wordpress-launch-template`.
    *   Clique em "Next".

2.  **Configurar as Subnets e Balanceamento de Carga**:
    *   **VPC**: Selecione `wordpress-vpc`.
    *   **Availability Zones and subnets**: Selecione as subnets privadas de aplicação: `wordpress-private-app-subnet-az1` e `wordpress-private-app-subnet-az2`.
    *   **Load balancing**: Selecione "Attach to an existing load balancer".
        *   **Choose from your load balancer target groups**: Selecione o Target Group que será criado posteriormente para o ALB (por exemplo, `wordpress-alb-tg`). Por enquanto, você pode deixar esta opção em branco e associar o ASG ao Target Group após a criação do ALB.
    *   **Health checks**: 
        *   **Health check type**: `EC2` (padrão) e `ELB` (se você já tiver um Target Group).
        *   **Health check grace period**: `300` segundos (tempo para a instância inicializar antes de ser verificada).
    *   Clique em "Next".

3.  **Configurar o Tamanho do Grupo e Políticas de Escalamento**:
    *   **Desired capacity**: `2` (número ideal de instâncias).
    *   **Minimum capacity**: `2` (número mínimo de instâncias).
    *   **Maximum capacity**: `4` (número máximo de instâncias).
    *   **Scaling policies**: Selecione "Target tracking scaling policy".
        *   **Name**: `cpu-utilization-scaling-policy`
        *   **Metric type**: `Average CPU utilization`
        *   **Target value**: `60` (porcentagem de CPU, por exemplo, escalar quando a CPU atingir 60%).
        *   **Instances need**: `300` segundos (tempo para uma instância recém-lançada se estabilizar).
    *   Clique em "Next".

4.  **Configurar Notificações e Tags (Opcional)**:
    *   Adicione notificações do CloudWatch se desejar ser alertado sobre eventos do ASG.
    *   Adicione tags relevantes para organização e controle de custos (ex: `Name: wordpress-instance`, `CostCenter: DevSecOps`, `Project: Wordpress`).
    *   Clique em "Next".

5.  **Revisar e Criar**: Revise todas as configurações e clique em "Create Auto Scaling group".

O Auto Scaling Group agora gerenciará as instâncias EC2 do WordPress, garantindo que a aplicação seja escalável e resiliente a falhas.

---




## 7. Criação do Application Load Balancer (ALB)

O Application Load Balancer (ALB) atua como o ponto de entrada para o tráfego da nossa aplicação WordPress, distribuindo as requisições entre as instâncias EC2 saudáveis no Auto Scaling Group. Ele opera na camada 7 (aplicação) do modelo OSI, permitindo roteamento baseado em conteúdo e outras funcionalidades avançadas.

### Componentes do ALB:

*   **Subnets Públicas**: O ALB será implantado nas subnets públicas para receber tráfego da internet.
*   **Target Group**: Um grupo de destino que registra as instâncias EC2 do WordPress e as monitora através de Health Checks.
*   **Listener**: Configura as portas e protocolos (HTTP/HTTPS) para o tráfego de entrada e as regras de encaminhamento para o Target Group.
*   **Health Checks**: Monitora a saúde das instâncias registradas no Target Group para garantir que o tráfego seja enviado apenas para instâncias operacionais.

### Passo a Passo para Criação do Application Load Balancer:

1.  **Criar Target Group**: O Target Group é onde as instâncias EC2 do WordPress serão registradas.
    *   No console da AWS, navegue até "EC2" -> "Target Groups" e clique em "Create target group".
    *   **Choose a target type**: `Instances`.
    *   **Target group name**: `wordpress-alb-tg`
    *   **Protocol**: `HTTP`
    *   **Port**: `80`
    *   **VPC**: Selecione `wordpress-vpc`.
    *   **Health checks**:
        *   **Protocol**: `HTTP`
        *   **Path**: `/wp-admin/install.php` (ou `/index.php` se o WordPress já estiver configurado).
        *   **Advanced health check settings**: Ajuste os thresholds conforme necessário (ex: `Healthy threshold: 3`, `Unhealthy threshold: 3`, `Timeout: 5`, `Interval: 30`).
    *   Clique em "Next".
    *   Não registre nenhuma instância neste momento, pois o ASG fará isso automaticamente. Clique em "Create target group".

2.  **Criar Application Load Balancer**: Agora, crie o ALB e associe-o ao Target Group.
    *   No console da AWS, navegue até "EC2" -> "Load Balancers" e clique em "Create Load Balancer".
    *   **Choose a load balancer type**: `Application Load Balancer`.
    *   **Load balancer name**: `wordpress-alb`
    *   **Scheme**: `Internet-facing`
    *   **IP address type**: `IPv4`
    *   **VPC**: Selecione `wordpress-vpc`.
    *   **Mappings**: Selecione as subnets públicas: `wordpress-public-subnet-az1` e `wordpress-public-subnet-az2`.
    *   **Security groups**: Crie um novo Security Group para o ALB (`wordpress-alb-sg`) que permita tráfego HTTP (porta 80) e HTTPS (porta 443) de `0.0.0.0/0`.
    *   **Listeners and routing**:
        *   **Protocol**: `HTTP`
        *   **Port**: `80`
        *   **Default action**: `Forward to` -> Selecione `wordpress-alb-tg`.
        *   (Opcional) Para HTTPS, você precisará de um certificado SSL/TLS. Você pode provisionar um via AWS Certificate Manager (ACM) e adicionar um segundo listener para HTTPS (porta 443) com o certificado e encaminhando para o mesmo Target Group.
    *   Clique em "Create load balancer".

3.  **Atualizar Auto Scaling Group (se necessário)**: Se você não associou o Target Group ao ASG no passo anterior, faça-o agora.
    *   No console da AWS, navegue até "EC2" -> "Auto Scaling Groups".
    *   Selecione `wordpress-asg`.
    *   Clique em "Edit" e, na seção "Load balancing", adicione o `wordpress-alb-tg`.

Após a criação do ALB e a associação com o ASG, o tráfego da internet será direcionado para as instâncias EC2 do WordPress de forma balanceada e resiliente. Você pode acessar o WordPress usando o DNS Name do ALB.

---




## 8. Conhecer o WordPress Localmente (Opcional)

Antes de implantar o WordPress na AWS, é altamente recomendável familiarizar-se com a plataforma localmente. Isso permite testar funcionalidades, entender a estrutura de arquivos e diretórios, e experimentar a instalação sem incorrer em custos na nuvem. A maneira mais fácil de fazer isso é usando Docker e Docker Compose.

### Passo a Passo para Rodar o WordPress Localmente com Docker:

1.  **Instalar Docker e Docker Compose**: Se você ainda não os tem, instale o Docker e o Docker Compose em sua máquina local. As instruções variam de acordo com o sistema operacional (Windows, macOS, Linux).

2.  **Criar um Arquivo `docker-compose.yml`**: Crie um diretório para o seu projeto WordPress local e, dentro dele, crie um arquivo chamado `docker-compose.yml` com o seguinte conteúdo:

    ```yaml
    version: '3.8'

    services:
      db:
        image: mysql:8.0
        container_name: wordpress-db-local
        restart: always
        environment:
          MYSQL_ROOT_PASSWORD: your_mysql_root_password # Altere para uma senha forte
          MYSQL_DATABASE: wordpress
          MYSQL_USER: wordpressuser
          MYSQL_PASSWORD: your_wordpress_db_password # Altere para uma senha forte
        volumes:
          - db_data:/var/lib/mysql

      wordpress:
        depends_on:
          - db
        image: wordpress:latest
        container_name: wordpress-app-local
        restart: always
        ports:
          - "80:80"
        environment:
          WORDPRESS_DB_HOST: db:3306
          WORDPRESS_DB_USER: wordpressuser
          WORDPRESS_DB_PASSWORD: your_wordpress_db_password # Use a mesma senha do banco de dados
          WORDPRESS_DB_NAME: wordpress
        volumes:
          - wordpress_data:/var/www/html

    volumes:
      db_data:
      wordpress_data:
    ```

    **Lembre-se de substituir `your_mysql_root_password` e `your_wordpress_db_password` por senhas seguras.**

3.  **Iniciar o WordPress**: Abra um terminal no diretório onde você salvou o `docker-compose.yml` e execute o seguinte comando:

    ```bash
    docker-compose up -d
    ```

    Este comando fará o download das imagens do Docker (MySQL e WordPress), criará os contêineres e os iniciará em segundo plano.

4.  **Acessar o WordPress Localmente**: Abra seu navegador e acesse `http://localhost`. Você será redirecionado para a página de configuração inicial do WordPress. Siga as instruções para finalizar a instalação.

5.  **Parar e Remover (Opcional)**: Quando terminar de usar o WordPress localmente, você pode parar e remover os contêineres e volumes com:

    ```bash
    docker-compose down -v
    ```

Familiarizar-se com o WordPress localmente ajudará a entender melhor como a aplicação funciona e como ela interage com o banco de dados e o sistema de arquivos, o que será útil durante a implantação na AWS.

---




## 9. Pontos Importantes para o Projeto

Ao longo da execução deste projeto, é crucial estar atento a alguns pontos específicos para garantir a conformidade com os requisitos e otimizar o uso dos recursos da AWS.

### Monitoramento de Custos

*   **Monitorem os custos diariamente no Cost Explorer da conta AWS**: É fundamental acompanhar os gastos para evitar surpresas e gerenciar o orçamento de forma eficaz. O Cost Explorer permite visualizar, entender e gerenciar seus custos e uso da AWS ao longo do tempo.

### Restrições e Configurações Específicas

*   **EC2**: As instâncias EC2 precisam conter as tags `Name`, `CostCenter` e `Project` associadas à instância e ao volume. Certifique-se de aplicar essas tags durante a criação do Launch Template ou diretamente nas instâncias, se forem criadas manualmente.
*   **RDS MySQL**: As instâncias do RDS MySQL precisam ser do tipo `db.t3g.micro` e **sem a opção de Multi-AZ**. Esta é uma restrição importante mencionada no documento, para controle de custos e limitações da conta. Em um ambiente de produção real, para alta disponibilidade, a opção Multi-AZ seria a recomendada, mas para este projeto, siga a especificação de não usar Multi-AZ.

### Exemplo de Tags para EC2:

| Chave       | Valor Exemplo      |
| :---------- | :----------------- |
| `Name`      | `wordpress-instance` |
| `CostCenter`| `DevSecOps`        |
| `Project`   | `Wordpress`        |

---
