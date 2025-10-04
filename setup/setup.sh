#!/bin/bash
set -e

export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

LAMBDA_DIR="$(cd "$(dirname "$0")/../lambda" && pwd)"
ZIP_DIR="$LAMBDA_DIR/zip"

echo "📦 Criando Lambda Authorizer..."
awslocal lambda create-function \
  --function-name jwt-authorizer \
  --runtime nodejs18.x \
  --handler authorizer.handler \
  --role arn:aws:iam::000000000000:role/lambda-role \
  --zip-file fileb://$ZIP_DIR/authorizer.zip || true

echo "✅ Lambda Authorizer criada com sucesso no LocalStack!"
