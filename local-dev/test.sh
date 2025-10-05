#!/bin/bash
set -e

# Token JWT de exemplo (gerado em jwt.io, por exemplo)
VALID_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
INVALID_TOKEN="token.invalido.123"

echo "✅ Testando com token VÁLIDO..."
awslocal lambda invoke \
  --function-name soat-fast-food-authorizer \
  --payload "{\"headers\": {\"Authorization\": \"Bearer $VALID_TOKEN\"}, \"methodArn\": \"arn:aws:execute-api:us-east-1:123456789012:/prod/GET/my/path\"}" \
  output.json

cat output.json | jq # Usa 'jq' para formatar o JSON
echo ""

echo "❌ Testando com token INVÁLIDO..."
awslocal lambda invoke \
  --function-name soat-fast-food-authorizer \
  --payload "{\"headers\": {\"Authorization\": \"Bearer $INVALID_TOKEN\"}, \"methodArn\": \"arn:aws:execute-api:us-east-1:123456789012:/prod/GET/my/path\"}" \
  output.json

cat output.json | jq
rm output.json