locals {
  lambda_dir = "${path.module}/lambda"
}

resource "null_resource" "pip_install" {
  triggers = {
    shell_hash = "${sha256(file("${local.lambda_dir}/requirements.txt"))}"
  }

  provisioner "local-exec" {
    command = "pip install -r ${local.lambda_dir}/requirements.txt -t ${local.lambda_dir}/.layer/python"
  }
}

data "archive_file" "lambda_layer" {
  type        = "zip"
  source_dir  = "${local.lambda_dir}/.layer"
  output_path = "${local.lambda_dir}/.layer.zip"
  depends_on  = [null_resource.pip_install]
}

resource "aws_lambda_layer_version" "lambda_layer" {
  layer_name          = "${var.prefix}-app-dependencies"
  filename            = data.archive_file.lambda_layer.output_path
  source_code_hash    = data.archive_file.lambda_layer.output_base64sha256
  compatible_runtimes = ["python3.12"]
}


data "aws_iam_policy_document" "trust_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}


resource "aws_iam_role" "lambda_role" {
  name               = "${var.prefix}_lambda_role"
  assume_role_policy = data.aws_iam_policy_document.trust_policy.json
}

resource "aws_iam_role_policy" "lambda_role_policy" {
  name = "cwlogs"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup"]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${aws_lambda_function.lambda_function.function_name}:*"
      },
    ]
  })
}

data "archive_file" "lambda_function" {
  type        = "zip"
  source_dir  = local.lambda_dir
  output_path = "lambda_function.zip"
  excludes = [ ".layer*" ]
}

resource "aws_lambda_function" "lambda_function" {
  function_name = "${var.prefix}_web_lambda"
  runtime       = "python3.12"
  handler       = "main.handler"
  role          = aws_iam_role.lambda_role.arn

  filename         = data.archive_file.lambda_function.output_path
  source_code_hash = data.archive_file.lambda_function.output_base64sha256
  layers           = [aws_lambda_layer_version.lambda_layer.arn]
  timeout          = 30
  memory_size      = 512

  environment {
    variables = {
      ENV_KEY = "ENV_VALUE"
    }
  }
}
