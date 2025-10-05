variable "aws_region" {
  description = "Região AWS para provisionar a Lambda."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Nome do projeto, usado como prefixo para os recursos."
  type        = string
  default     = "soat"
}

variable "lambda_role_arn" {
  description = "O ARN completo da IAM Role pré-existente para a Lambda."
  type        = string
  default     = "arn:aws:iam::058264083210:role/LabRole"
}