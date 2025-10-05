terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
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

variable "project_name" {
  description = "Nome do projeto, usado como prefixo para os recursos"
  type        = string
  default     = "soat-fast-food"
}

# =========================
# Dados Locais (Configuração Centralizada)
# =========================
locals {
  routes = {
    "POST /customers" = "customers",
    "POST /auth"      = "auth",
    "GET /products"   = "products-get",
    "POST /products"  = "products-post",
    "GET /orders"     = "orders-get",
    "POST /orders"    = "orders-post",
    "POST /payments"  = "payments-post"
  }

  public_routes = [
    "POST /customers",
    "POST /auth"
  ]

  lambda_function_names = toset(concat(values(local.routes), ["authorizer"]))
}

# =========================
# Arquivos ZIP das Lambdas
# =========================
data "archive_file" "lambda_zip" {
  for_each    = local.lambda_function_names
  type        = "zip"
  source_file = "${path.module}/lambda/${each.key}.js"
  output_path = "${path.module}/dist/${each.key}.zip"
}

# =========================
# BUSCANDO A IAM ROLE EXISTENTE
# =========================
# Em vez de criar uma role, usamos um "data source" para encontrar a "LabRole"
# que já existe no ambiente da AWS Academy.
data "aws_iam_role" "lab_role" {
  name = "LabRole"
}

# =========================
# Funções Lambda
# =========================
resource "aws_lambda_function" "functions" {
  for_each      = local.lambda_function_names
  function_name = "${var.project_name}-${each.key}"
  # Todas as funções agora usam o ARN da "LabRole" encontrada
  role             = data.aws_iam_role.lab_role.arn
  handler          = "${each.key}.handler"
  runtime          = "nodejs18.x"
  filename         = data.archive_file.lambda_zip[each.key].output_path
  source_code_hash = data.archive_file.lambda_zip[each.key].output_base64sha256
}

# =========================
# API GATEWAY (HTTP API v2)
# =========================
resource "aws_apigatewayv2_api" "fast_food_api" {
  name          = var.project_name
  protocol_type = "HTTP"
}

# =========================
# Autorizador Lambda
# =========================
resource "aws_apigatewayv2_authorizer" "lambda_authorizer" {
  api_id                            = aws_apigatewayv2_api.fast_food_api.id
  name                              = "lambda-authorizer"
  authorizer_type                   = "REQUEST"
  authorizer_uri                    = aws_lambda_function.functions["authorizer"].invoke_arn
  identity_sources                  = ["$request.header.Authorization"]
  authorizer_payload_format_version = "2.0"
}

# Permissão para o API Gateway invocar a função Lambda do autorizador
resource "aws_lambda_permission" "api_gw_authorizer" {
  statement_id  = "AllowAPIGatewayInvokeAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.functions["authorizer"].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.fast_food_api.execution_arn}/authorizers/${aws_apigatewayv2_authorizer.lambda_authorizer.id}"
}

# =========================
# Integrações e Rotas
# =========================
resource "aws_apigatewayv2_integration" "integrations" {
  for_each               = local.routes
  api_id                 = aws_apigatewayv2_api.fast_food_api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.functions[each.value].invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "routes" {
  for_each  = local.routes
  api_id    = aws_apigatewayv2_api.fast_food_api.id
  route_key = each.key
  target    = "integrations/${aws_apigatewayv2_integration.integrations[each.key].id}"

  authorization_type = contains(local.public_routes, each.key) ? "NONE" : "CUSTOM"
  authorizer_id      = contains(local.public_routes, each.key) ? null : aws_apigatewayv2_authorizer.lambda_authorizer.id
}

# Permissão para o API Gateway invocar as funções Lambda das rotas.
resource "aws_lambda_permission" "api_gw_routes" {
  for_each      = local.routes
  statement_id  = "AllowAPIGatewayInvoke_${each.value}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.functions[each.value].function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.fast_food_api.execution_arn}/*/${each.key}"
}

# =========================
# Deploy (Stage)
# =========================
resource "aws_apigatewayv2_stage" "prod" {
  api_id      = aws_apigatewayv2_api.fast_food_api.id
  name        = "prod"
  auto_deploy = true
}

# =========================
# OUTPUTS
# =========================
output "api_gateway_url" {
  description = "URL base do API Gateway"
  value       = aws_apigatewayv2_api.fast_food_api.api_endpoint
}