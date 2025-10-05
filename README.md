# AWS Lambda JWT Authorizer com Terraform

Este repositório contém o código-fonte e a infraestrutura como código (IaC) para uma função AWS Lambda que atua como um autorizador de token JWT para um API Gateway.

O projeto é gerenciado com Terraform, seguindo as melhores práticas de organização de código, gerenciamento de estado remoto e um ambiente de desenvolvimento local isolado com LocalStack e Docker.



## ✨ Features

-   **Infraestrutura como Código (IaC):** Todo o provisionamento da AWS Lambda é gerenciado declarativamente com `Terraform`.
-   **Código Organizado:** O código Terraform é modularizado em arquivos lógicos (`main.tf`, `variables.tf`, `outputs.tf`, etc.) dentro de um diretório dedicado `terraform/`.
-   **Gerenciamento de Estado Remoto:** O estado do Terraform é armazenado de forma segura e centralizada em um bucket AWS S3, permitindo o trabalho em equipe e a execução em esteiras de CI/CD.
-   **Desenvolvimento Local:** Um ambiente de desenvolvimento completo e isolado pode ser iniciado com um único comando usando Docker e LocalStack.
-   **Testes Locais:** Inclui scripts para implantar e testar a função Lambda no ambiente LocalStack, agilizando o ciclo de desenvolvimento.
-   **Dependency Locking:** Utiliza `package-lock.json` para as dependências Node.js e `.terraform.lock.hcl` para os providers Terraform, garantindo builds consistentes e reprodutíveis.



## 📂 Estrutura do Projeto

```
.
├── local-dev/
│   ├── docker-compose.yml
│   ├── setup.sh
│   └── test.sh
├── src/
│   └── authorizer.js
├── terraform/
│   ├── .terraform.lock.hcl
│   ├── main.tf
│   ├── outputs.tf
│   ├── provider.tf
│   ├── terraform.tf
│   └── variables.tf
├── .gitignore
├── package.json
└── package-lock.json
```



## 🚀 Pré-requisitos

Antes de começar, garanta que você tenha as seguintes ferramentas instaladas:

- Terraform (>= 1.0)
- AWS CLI
- Node.js (>= 18.x)
- Docker e Docker Compose
- awslocal (wrapper da AWS CLI para LocalStack)



## ☁️ Deployment na AWS

Para provisionar a função Lambda em um ambiente AWS real, siga os passos abaixo.

### 1. Configurar Credenciais AWS

Certifique-se de que suas credenciais da AWS estejam configuradas corretamente no seu ambiente (ex: via `aws configure` ou variáveis de ambiente).

### 2. Instalar Dependências Node.js

Na raiz do projeto, instale a dependência `jsonwebtoken`:

```
npm install
```

### 3. Inicializar o Terraform

Navegue até a pasta de infraestrutura e inicialize o Terraform. Isso irá baixar os providers necessários e configurar o backend S3.

```
cd terraform/
terraform init
```

### 4. Revisar e Aplicar

Revise o plano de execução para entender quais recursos serão criados.

```
terraform plan
```

Se o plano estiver correto, aplique as mudanças para criar a função Lambda na AWS.

```
terraform apply
```

Ao final da execução, o ARN da Lambda será exibido como um output.



## 💻 Desenvolvimento Local com LocalStack

Para desenvolver e testar a função Lambda localmente sem custos, utilize o ambiente LocalStack.

### 1. Iniciar o Ambiente

Navegue até a pasta `local-dev` e inicie os contêineres do LocalStack.

```
cd local-dev/
sh setup.sh
```

Este script irá:

    1. Iniciar o LocalStack via Docker Compose.
    2. Compactar o código da Lambda em um arquivo `.zip`.
    3. Criar a função Lambda no ambiente LocalStack usando `awslocal`.

### 2. Executar os Testes

Após o ambiente estar pronto, execute o script de teste para invocar a Lambda localmente com tokens JWT válidos e inválidos.

```
sh test.sh
```

O script usará `awslocal` para invocar a função e exibirá as respostas de política (`Allow`/`Deny`) no console.



## ⚙️ Configuração do Terraform

### Variáveis

As variáveis de configuração estão definidas em `terraform/variables.tf`. As principais são:

- `aws_region`: Região da AWS onde os recursos serão provisionados. Default: `us-east-1`.
- `project_name`: Prefixo usado para nomear os recursos. Default: `soat`.
- `lambda_role_arn`: ARN da IAM Role que a Lambda usará. Este valor é fixo para o ambiente de laboratório da AWS Academy, mas pode ser sobrescrito se necessário.

### Outputs

O projeto expõe um output principal em `terraform/outputs.tf`:

- `lambda_authorizer_arn`: O ARN completo da função Lambda criada. Este valor é essencial para ser consumido por outros projetos de infraestrutura (como a configuração de um API Gateway) através do `terraform_remote_state`.