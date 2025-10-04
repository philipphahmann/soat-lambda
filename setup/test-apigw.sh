#!/bin/bash
set -e

API_ID=$(awslocal apigateway get-rest-apis \
  --query 'items[?name==`fast-food-api`].id' --output text)

if [ -z "$API_ID" ]; then
  echo "❌ Nenhum API Gateway encontrado! Rode ./setup-apigw.sh primeiro."
  exit 1
fi

BASE_URL="http://localhost:4566/restapis/$API_ID/dev/_user_request_"

echo "🔎 Testando API Gateway (API_ID=$API_ID)"
echo "Base URL: $BASE_URL"
echo ""

# ==========================
# LOGIN (gera token)
# ==========================
echo "🔑 Testando login (POST /auth)..."
TOKEN=$(curl -s -X POST "$BASE_URL/auth" \
  -H "Content-Type: application/json" \
  -d '{"cpf":"12345678901"}' | jq -r '.token // empty')

if [ -z "$TOKEN" ]; then
  echo "⚠️ Nenhum token retornado do /auth! Usando token mock."
  TOKEN="MOCK_TOKEN"
fi
echo "Token: $TOKEN"
echo ""

# ==========================
# TESTES PROTEGIDOS
# ==========================

echo "🔒 [Protegido] GET /products"
curl -s -X GET "$BASE_URL/products" \
  -H "Authorization: Bearer $TOKEN"
echo -e "\n"

echo "🔒 [Protegido] POST /products"
curl -s -X POST "$BASE_URL/products" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"name":"Coke","price":5.0}'
echo -e "\n"

echo "🔒 [Protegido] GET /orders"
curl -s -X GET "$BASE_URL/orders" \
  -H "Authorization: Bearer $TOKEN"
echo -e "\n"

echo "🔒 [Protegido] POST /orders"
curl -s -X POST "$BASE_URL/orders" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"customerId":"123","items":[{"productId":"abc","quantity":2}]}'
echo -e "\n"

echo "🔒 [Protegido] POST /payments"
curl -s -X POST "$BASE_URL/payments" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"orderId":"order123","amount":100.0}'
echo -e "\n"

echo "✅ Todos os testes de endpoints protegidos concluídos!"
