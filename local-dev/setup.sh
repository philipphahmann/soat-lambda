#!/bin/bash
set -e

echo "🚀 Iniciando ambiente local com Docker Compose..."
docker-compose up -d

echo "📦 Compactando o código da Lambda..."
# O script agora está em 'local-dev', então o caminho para a lambda muda
LAMBDA_CODE_DIR="$(cd "$(dirname "$0")/../lambda" && pwd)"
ZIP_FILE_PATH="/tmp/authorizer.zip"
zip -j "$ZIP_FILE_PATH" "$LAMBDA_CODE_DIR/authorizer.js"

# Espera o LocalStack ficar pronto
echo "⏳ Aguardando o LocalStack ficar disponível..."
sleep 5

echo "🔧 Criando função Lambda 'authorizer' no LocalStack..."
awslocal lambda create-function \
  --function-name soat-fast-food-authorizer \
  --runtime nodejs18.x \
  --handler authorizer.handler \
  --role arn:aws:iam::000000000000:role/lambda-role \
  --zip-file fileb://$ZIP_FILE_PATH \
  --region us-east-1 || echo "⚠️  Função já existe. Ignorando criação."

echo "✅ Ambiente local pronto!"
echo "Para testar, use o script: ./local-dev/test.sh"