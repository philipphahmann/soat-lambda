output "lambda_authorizer_arn" {
  description = "ARN da função Lambda do autorizador para ser usado no API Gateway."
  value       = aws_lambda_function.authorizer.arn
}

variable "public_key_secret_name" {
  description = "O nome do segredo no AWS Secrets Manager que contém a chave pública."
  type        = string
  default     = "soat/jwt-public-key" # Exemplo, troque pelo seu
}