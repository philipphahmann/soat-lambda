# AWS Lambda JWT Authorizer com Terraform

Este repositório contém o código-fonte e a infraestrutura como código (IaC) para uma função AWS Lambda que atua como um autorizador de token JWT para um API Gateway.

O projeto é gerenciado com Terraform, seguindo as melhores práticas de organização de código, gerenciamento de estado remoto e um ambiente de desenvolvimento local isolado com LocalStack e Docker.

## ✨ Features

-   **CI/CD Automatizado:** Pipeline completa que valida o build, planeja a infraestrutura em Pull Requests e faz o deploy automático na AWS após o merge para a branch `main`.
-   **Gerenciamento Seguro de Chaves:** A chave pública para validação dos tokens JWT é armazenada e gerenciada de forma segura no AWS Secrets Manager, evitando chaves expostas em código ou configurações.
-   **Branch Protegida:** A branch main é protegida, exigindo Pull Requests e a aprovação de todos os jobs da esteira antes do merge, garantindo estabilidade e segurança. 
-   **Infraestrutura como Código (IaC):** Todo o provisionamento da AWS Lambda é gerenciado declarativamente com `Terraform`.
-   **Código Organizado:** O código Terraform é modularizado em arquivos lógicos (`main.tf`, `variables.tf`, `outputs.tf`, etc.) dentro de um diretório dedicado `terraform/`.
-   **Gerenciamento de Estado Remoto:** O estado do Terraform é armazenado de forma segura e centralizada em um bucket AWS S3, permitindo o trabalho em equipe e a execução em esteiras de CI/CD.
-   **Desenvolvimento Local:** Um ambiente de desenvolvimento completo e isolado pode ser iniciado com um único comando usando Docker e LocalStack.
-   **Testes Locais:** Inclui scripts para implantar e testar a função Lambda no ambiente LocalStack, agilizando o ciclo de desenvolvimento.
-   **Dependency Locking:** Utiliza `package-lock.json` para as dependências Node.js e `.terraform.lock.hcl` para os providers Terraform, garantindo builds consistentes e reprodutíveis.

## 📂 Estrutura do Projeto

```
.
├── .github/
│   └── workflows/
│       └── ci-cd.yml
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

## 🚀 Esteira de CI/CD com GitHub Actions
Este projeto utiliza uma pipeline de CI/CD para automatizar a validação e o deploy da infraestrutura. O workflow está definido em `.github/workflows/ci-cd.yml`.

### Fluxo de Trabalho

### 1. Pull Request: 

Ao abrir um Pull Request para a branch main:

- O workflow é acionado automaticamente.
- Job `build`: Instala as dependências da Lambda para garantir a integridade do código.
- Job `terraform_plan`: Executa um terraform plan para mostrar as mudanças de infraestrutura propostas. O resultado fica visível diretamente no PR para revisão.

### 2. Merge para `main`:

- Após o PR ser aprovado e todos os jobs passarem com sucesso, o merge para a branch `main` é liberado.
- O merge aciona um novo evento de `push` na `main`.
- Job `terraform_apply`: É executado automaticamente, aplicando na AWS as mudanças que já foram validadas.

### 3. Execução Manual:

- É possível acionar a esteira manualmente pela aba "Actions" do GitHub, o que executará o fluxo completo, incluindo o deploy.

### Configuração Obrigatória

Para que a pipeline possa se autenticar na AWS, você deve configurar os seguintes secrets no seu repositório do GitHub:

1. Navegue até `Settings` > `Secrets and variables` > `Actions`.
2. Clique em New repository secret e adicione os seguintes secrets:
   - `AWS_ACCESS_KEY_ID`: O Access Key ID do seu usuário IAM.
   - `AWS_SECRET_ACCESS_KEY`: O Secret Access Key correspondente.
   - `AWS_SESSION_TOKEN` (Opcional): Necessário se você estiver usando credenciais temporárias.
   - `PUBLIC_KEY_SECRET_NAME`: O nome/ARN do segredo no AWS Secrets Manager que contém a chave pública (ex: `soat/jwt-public-key`).

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
-  `public_key_secret_name`: O nome do segredo no AWS Secrets Manager que contém a chave pública.

### Outputs

O projeto expõe um output principal em `terraform/outputs.tf`:

- `lambda_authorizer_arn`: O ARN completo da função Lambda criada. Este valor é essencial para ser consumido por outros projetos de infraestrutura (como a configuração de um API Gateway) através do `terraform_remote_state`.