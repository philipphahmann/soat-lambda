output "lambda_authorizer_arn" {
  description = "ARN da função Lambda do autorizador para ser usado no API Gateway."
  value       = aws_lambda_function.authorizer.arn
}