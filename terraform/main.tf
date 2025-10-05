# Gera o arquivo .zip a partir do código-fonte da Lambda
data "archive_file" "authorizer_zip" {
  type = "zip"
  # O path agora precisa "voltar" um nível para achar a pasta lambda
  source_file = "${path.module}/../lambda/authorizer.js"
  output_path = "${path.module}/../dist/authorizer.zip"
}

# Cria o recurso da função Lambda na AWS
resource "aws_lambda_function" "authorizer" {
  function_name    = "${var.project_name}-authorizer"
  role             = var.lambda_role_arn
  handler          = "authorizer.handler"
  runtime          = "nodejs18.x"
  filename         = data.archive_file.authorizer_zip.output_path
  source_code_hash = data.archive_file.authorizer_zip.output_base64sha256

  tags = {
    Project = var.project_name
  }
}