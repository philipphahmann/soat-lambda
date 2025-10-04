#!/bin/bash
set -e

export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1

LAMBDA_DIR="$(cd "$(dirname "$0")/../lambda" && pwd)"
ZIP_DIR="$LAMBDA_DIR/zip"

# ==========================
# GERA OS ZIPS ANTES DE SUBIR
# ==========================
echo "📦 Gerando arquivos ZIP das Lambdas..."
mkdir -p "$ZIP_DIR"
for file in "$LAMBDA_DIR"/*.js; do
  name=$(basename "$file" .js)
  zip -j "$ZIP_DIR/$name.zip" "$file" >/dev/null
  echo "   -> $name.zip"
done
echo "✅ Zips prontos em $ZIP_DIR"
echo ""

# ==========================
# API GATEWAY
# ==========================
echo "🔧 Criando/pegando API Gateway..."
API_ID=$(awslocal apigateway create-rest-api \
  --name "fast-food-api" \
  --query 'id' --output text 2>/dev/null || true)

if [ -z "$API_ID" ]; then
  API_ID=$(awslocal apigateway get-rest-apis \
    --query 'items[?name==`fast-food-api`].id' --output text)
fi
echo "API_ID=$API_ID"

ROOT_ID=$(awslocal apigateway get-resources \
  --rest-api-id $API_ID \
  --query 'items[0].id' --output text)
echo "ROOT_ID=$ROOT_ID"

# ==========================
# AUTHORIZER
# ==========================
echo "🔒 Criando/pegando Authorizer..."
AUTHORIZER_ID=$(awslocal apigateway create-authorizer \
  --rest-api-id $API_ID \
  --name jwtAuthorizer \
  --type TOKEN \
  --authorizer-uri "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:000000000000:function:jwt-authorizer/invocations" \
  --identity-source "method.request.header.Authorization" \
  --query 'id' --output text 2>/dev/null || true)

if [ -z "$AUTHORIZER_ID" ]; then
  AUTHORIZER_ID=$(awslocal apigateway get-authorizers \
    --rest-api-id $API_ID \
    --query 'items[?name==`jwtAuthorizer`].id' --output text)
fi
echo "AUTHORIZER_ID=$AUTHORIZER_ID"

# ==========================
# FUNÇÃO AUXILIAR
# ==========================
create_endpoint() {
  local path=$1
  local method=$2
  local function_name=$3
  local file_name=$4
  local auth_type=$5
  local authorizer_id=$6

  echo "📦 Criando recurso $path..."
  RESOURCE_ID=$(awslocal apigateway create-resource \
    --rest-api-id $API_ID \
    --parent-id $ROOT_ID \
    --path-part ${path#/} \
    --query 'id' --output text 2>/dev/null || true)

  if [ -z "$RESOURCE_ID" ]; then
    RESOURCE_ID=$(awslocal apigateway get-resources \
      --rest-api-id $API_ID \
      --query "items[?path=='$path'].id" --output text)
  fi

  echo "🔗 Criando método $method $path ($auth_type)..."
  if [ "$auth_type" = "CUSTOM" ]; then
    awslocal apigateway put-method \
      --rest-api-id $API_ID \
      --resource-id $RESOURCE_ID \
      --http-method $method \
      --authorization-type CUSTOM \
      --authorizer-id $authorizer_id || true
  else
    awslocal apigateway put-method \
      --rest-api-id $API_ID \
      --resource-id $RESOURCE_ID \
      --http-method $method \
      --authorization-type NONE || true
  fi

  echo "📦 Verificando Lambda $function_name..."
  if [ ! -f "$ZIP_DIR/$file_name.zip" ]; then
    echo "❌ Arquivo $ZIP_DIR/$file_name.zip não encontrado!"
    exit 1
  fi

  awslocal lambda create-function \
    --function-name $function_name \
    --runtime nodejs18.x \
    --handler $file_name.handler \
    --role arn:aws:iam::000000000000:role/lambda-role \
    --zip-file fileb://$ZIP_DIR/$file_name.zip >/dev/null 2>&1 || true

  echo "⚡ Integrando rota $method $path com Lambda $function_name..."
  awslocal apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method $method \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:000000000000:function:$function_name/invocations || true
}

# ==========================
# ROTAS
# ==========================
# Públicas
create_endpoint "/customers" POST "customers-service" "customers" "NONE" ""
create_endpoint "/auth" POST "auth-service" "auth" "NONE" ""

# Protegidas
create_endpoint "/products" GET  "products-get-service"  "products-get"  "CUSTOM" $AUTHORIZER_ID
create_endpoint "/products" POST "products-post-service" "products-post" "CUSTOM" $AUTHORIZER_ID
create_endpoint "/orders"   GET  "orders-get-service"   "orders-get"   "CUSTOM" $AUTHORIZER_ID
create_endpoint "/orders"   POST "orders-post-service"  "orders-post"  "CUSTOM" $AUTHORIZER_ID
create_endpoint "/payments" POST "payments-post-service" "payments-post" "CUSTOM" $AUTHORIZER_ID

# ==========================
# DEPLOY
# ==========================
echo "🚀 Deploy da API..."
awslocal apigateway create-deployment \
  --rest-api-id $API_ID \
  --stage-name dev >/dev/null 2>&1 || true

echo ""
echo "✅ API Gateway pronto!"
echo "   API_ID=$API_ID"
echo ""
echo "Exemplo teste público:"
echo "curl http://localhost:4566/restapis/$API_ID/dev/_user_request_/customers"
echo ""
echo "Exemplo teste protegido:"
echo "curl -H 'Authorization: Bearer <TOKEN>' http://localhost:4566/restapis/$API_ID/dev/_user_request_/orders"
