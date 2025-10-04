terraform {
    required_providers {
        aws = {
            source  = "hashicorp/aws"
            version = "~> 5.0"
        }
    }
}

provider "aws" {
    region = var.aws_region
}

# =========================
# Variáveis
# =========================
variable "aws_region" {
    description = "Região AWS"
    type        = string
    default     = "us-east-1"
}

variable "issuer" {
    description = "Issuer do JWT (deve bater com o 'iss' dos seus tokens). Ex.: https://minha-api.com"
    type        = string
    default     = "https://minha-api.com"
}

variable "audience" {
    description = "Audience do JWT (deve bater com o 'aud' dos seus tokens)"
    type        = string
    default     = "fast-food-api"
}

variable "lambda_zip_path" {
    description = "Caminho do zip da Lambda de backend (orders-service)"
    type        = string
    default     = "lambda/orders.zip"
}

variable "lambda_function_name" {
    description = "Nome da Lambda handler (orders-service)"
    type        = string
    default     = "orders-service"
}

# Quais rotas NÃO exigem JWT (públicas)
variable "public_route_keys" {
    description = "Rotas públicas (sem autenticação)"
    type        = list(string)
    default     = [
        "POST /customers",
        "POST /auth/login"
    ]
}

# Helper: função para checar se rota é pública
locals {
    is_public = function(route_key) => contains(var.public_route_keys, route_key)
}

# =========================
# API GATEWAY (HTTP API v2)
# =========================
resource "aws_apigatewayv2_api" "fast_food_api" {
name          = "fast-food-api"
protocol_type = "HTTP"
}

resource "aws_apigatewayv2_authorizer" "jwt_auth" {
api_id           = aws_apigatewayv2_api.fast_food_api.id
name             = "fast-food-jwt-authorizer"
authorizer_type  = "JWT"
identity_sources = ["$request.header.Authorization"]

jwt_configuration {
issuer   = var.issuer
audience = [var.audience]
}
}

resource "aws_apigatewayv2_stage" "prod" {
api_id      = aws_apigatewayv2_api.fast_food_api.id
name        = "prod"
auto_deploy = true
}

# =========================
# LAMBDA (orders-service)
# =========================
resource "aws_iam_role" "lambda_exec" {
name = "orders-service-role"

assume_role_policy = jsonencode({
Version = "2012-10-17",
Statement = [{
Action    = "sts:AssumeRole",
Effect    = "Allow",
Principal = { Service = "lambda.amazonaws.com" }
}]
})
}

resource "aws_lambda_function" "orders_service" {
function_name = var.lambda_function_name
role          = aws_iam_role.lambda_exec.arn
handler       = "orders.handler"
runtime       = "nodejs18.x"

filename         = var.lambda_zip_path
source_code_hash = filebase64sha256(var.lambda_zip_path)
}

# Permite o API Gateway invocar a Lambda
resource "aws_lambda_permission" "apigw_invoke_orders" {
statement_id  = "AllowAPIGatewayInvokeOrders"
action        = "lambda:InvokeFunction"
function_name = aws_lambda_function.orders_service.function_name
principal     = "apigateway.amazonaws.com"
source_arn    = "${aws_apigatewayv2_api.fast_food_api.execution_arn}/*/*"
}

# =========================
# INTEGRAÇÃO ÚNICA
# =========================
resource "aws_apigatewayv2_integration" "lambda_integration" {
api_id                 = aws_apigatewayv2_api.fast_food_api.id
integration_type       = "AWS_PROXY"
integration_uri        = aws_lambda_function.orders_service.invoke_arn
payload_format_version = "2.0"
}

# =========================
# ROTAS (geradas do seu OpenAPI)
# Todas protegidas por padrão; exceções via var.public_route_keys
# =========================

# Helper para criar rotas
# (Terraform não tem "funções" declarativas, então repetimos declarando cada rota)

# /customers
resource "aws_apigatewayv2_route" "customers_get" {
api_id    = aws_apigatewayv2_api.fast_food_api.id
route_key = "GET /customers"
target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"

authorization_type = local.is_public("GET /customers") ? "NONE" : "JWT"
authorizer_id      = local.is_public("GET /customers") ? null : aws_apigatewayv2_authorizer.jwt_auth.id
}

resource "aws_apigatewayv2_route" "customers_post" {
api_id    = aws_apigatewayv2_api.fast_food_api.id
route_key = "POST /customers"
target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"

authorization_type = local.is_public("POST /customers") ? "NONE" : "JWT"
authorizer_id      = local.is_public("POST /customers") ? null : aws_apigatewayv2_authorizer.jwt_auth.id
}

# /products
resource "aws_apigatewayv2_route" "products_get" {
api_id    = aws_apigatewayv2_api.fast_food_api.id
route_key = "GET /products"
target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"

authorization_type = local.is_public("GET /products") ? "NONE" : "JWT"
authorizer_id      = local.is_public("GET /products") ? null : aws_apigatewayv2_authorizer.jwt_auth.id
}

resource "aws_apigatewayv2_route" "products_post" {
api_id    = aws_apigatewayv2_api.fast_food_api.id
route_key = "POST /products"
target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"

authorization_type = local.is_public("POST /products") ? "NONE" : "JWT"
authorizer_id      = local.is_public("POST /products") ? null : aws_apigatewayv2_authorizer.jwt_auth.id
}

# /products/{productId}
resource "aws_apigatewayv2_route" "products_put" {
api_id    = aws_apigatewayv2_api.fast_food_api.id
route_key = "PUT /products/{productId}"
target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"

authorization_type = local.is_public("PUT /products/{productId}") ? "NONE" : "JWT"
authorizer_id      = local.is_public("PUT /products/{productId}") ? null : aws_apigatewayv2_authorizer.jwt_auth.id
}

resource "aws_apigatewayv2_route" "products_delete" {
api_id    = aws_apigatewayv2_api.fast_food_api.id
route_key = "DELETE /products/{productId}"
target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"

authorization_type = local.is_public("DELETE /products/{productId}") ? "NONE" : "JWT"
authorizer_id      = local.is_public("DELETE /products/{productId}") ? null : aws_apigatewayv2_authorizer.jwt_auth.id
}

# /orders
resource "aws_apigatewayv2_route" "orders_get" {
api_id    = aws_apigatewayv2_api.fast_food_api.id
route_key = "GET /orders"
target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"

authorization_type = local.is_public("GET /orders") ? "NONE" : "JWT"
authorizer_id      = local.is_public("GET /orders") ? null : aws_apigatewayv2_authorizer.jwt_auth.id
}

resource "aws_apigatewayv2_route" "orders_post" {
api_id    = aws_apigatewayv2_api.fast_food_api.id
route_key = "POST /orders"
target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"

authorization_type = local.is_public("POST /orders") ? "NONE" : "JWT"
authorizer_id      = local.is_public("POST /orders") ? null : aws_apigatewayv2_authorizer.jwt_auth.id
}

# /payments
resource "aws_apigatewayv2_route" "payments_post" {
api_id    = aws_apigatewayv2_api.fast_food_api.id
route_key = "POST /payments"
target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"

authorization_type = local.is_public("POST /payments") ? "NONE" : "JWT"
authorizer_id      = local.is_public("POST /payments") ? null : aws_apigatewayv2_authorizer.jwt_auth.id
}

# /payments/{paymentId}
resource "aws_apigatewayv2_route" "payments_get" {
api_id    = aws_apigatewayv2_api.fast_food_api.id
route_key = "GET /payments/{paymentId}"
target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"

authorization_type = local.is_public("GET /payments/{paymentId}") ? "NONE" : "JWT"
authorizer_id      = local.is_public("GET /payments/{paymentId}") ? null : aws_apigatewayv2_authorizer.jwt_auth.id
}

# /payments/{paymentId}/status
resource "aws_apigatewayv2_route" "payments_status_get" {
api_id    = aws_apigatewayv2_api.fast_food_api.id
route_key = "GET /payments/{paymentId}/status"
target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"

authorization_type = local.is_public("GET /payments/{paymentId}/status") ? "NONE" : "JWT"
authorizer_id      = local.is_public("GET /payments/{paymentId}/status") ? null : aws_apigatewayv2_authorizer.jwt_auth.id
}

# =========================
# OUTPUTS
# =========================
output "api_gateway_url" {
description = "URL base do API Gateway (stage prod)"
value       = "${aws_apigatewayv2_api.fast_food_api.api_endpoint}/${aws_apigatewayv2_stage.prod.name}"
}
