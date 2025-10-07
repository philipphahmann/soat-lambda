#!/bin/bash
set -e

echo "🚀 Iniciando ambiente local com Docker Compose..."
docker-compose up -d

# Navega para a raiz do projeto para instalar dependências e criar o .zip
PROJECT_ROOT_DIR="$(cd "$(dirname "$0")/../" && pwd)"
cd "$PROJECT_ROOT_DIR"

echo "📦 Instalando dependências Node.js..."
npm install

echo "📦 Compactando o código da Lambda e suas dependências..."
ZIP_FILE_PATH="/tmp/authorizer.zip"
# Cria o zip incluindo o código, as dependências e o package.json
zip -r "$ZIP_FILE_PATH" src/authorizer.js node_modules package.json

echo "⏳ Aguardando o LocalStack ficar disponível..."
sleep 5

echo "🔧 Criando função Lambda 'authorizer' no LocalStack..."
awslocal lambda create-function \
  --function-name soat-fast-food-authorizer \
  --runtime nodejs18.x \
  --handler src/authorizer.handler \
  --role arn:aws:iam::000000000000:role/lambda-role \
  --zip-file fileb://$ZIP_FILE_PATH \
  --region us-east-1 || echo "⚠️  Função já existe. Ignorando criação."

echo "✅ Ambiente local pronto!"
echo "Para testar, use o script: ./local-dev/test.sh"