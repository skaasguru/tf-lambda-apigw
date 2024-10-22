resource "aws_api_gateway_rest_api" "rest_api" {
  name        = "${var.prefix}-web-api"
  description = "This is my API for demonstration"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_method.root_path_get.id,
      aws_api_gateway_integration.root_path_get.id,
      aws_api_gateway_integration_response.root_path_get.id,
      aws_api_gateway_method_response.root_path_get.id,

      aws_api_gateway_resource.users_path.id,
      aws_api_gateway_method.users_path_get.id,
      aws_api_gateway_integration.users_path_get.id,

      aws_api_gateway_resource.instances_path.id,
      aws_api_gateway_method.instances_path_get.id,
      aws_api_gateway_integration.instances_path_get.id,
      aws_api_gateway_integration_response.instances_path_get.id,
      aws_api_gateway_method_response.instances_path_get.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}


resource "aws_api_gateway_stage" "dev_stage" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  stage_name    = "dev"
}


# GET /
resource "aws_api_gateway_method" "root_path_get" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "root_path_get" {
  rest_api_id          = aws_api_gateway_rest_api.rest_api.id
  resource_id          = aws_api_gateway_rest_api.rest_api.root_resource_id
  http_method          = aws_api_gateway_method.root_path_get.http_method
  type                 = "MOCK"
  timeout_milliseconds = 15000

  request_templates = {
    "application/json" = <<EOF
        {
            "statusCode": 200
        }
        EOF
  }
}

resource "aws_api_gateway_integration_response" "root_path_get" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_rest_api.rest_api.root_resource_id
  http_method = aws_api_gateway_method.root_path_get.http_method
  status_code = "200"

  response_templates = {
    "application/json" = <<EOF
        {"action": "do GET /users"}
    EOF
  }
}

resource "aws_api_gateway_method_response" "root_path_get" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_rest_api.rest_api.root_resource_id
  http_method = aws_api_gateway_method.root_path_get.http_method
  status_code = aws_api_gateway_integration_response.root_path_get.status_code
}


# GET /users
resource "aws_api_gateway_resource" "users_path" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
  path_part   = "users"
}


resource "aws_api_gateway_method" "users_path_get" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.users_path.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "users_path_get" {
  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  resource_id             = aws_api_gateway_resource.users_path.id
  http_method             = aws_api_gateway_method.users_path_get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_function.invoke_arn
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "arn:aws:execute-api:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${aws_api_gateway_rest_api.rest_api.id}/*/${aws_api_gateway_method.users_path_get.http_method}${aws_api_gateway_resource.users_path.path}"
}

# GET /instances
resource "aws_api_gateway_resource" "instances_path" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  parent_id   = aws_api_gateway_rest_api.rest_api.root_resource_id
  path_part   = "instances"
}

resource "aws_api_gateway_method" "instances_path_get" {
  rest_api_id   = aws_api_gateway_rest_api.rest_api.id
  resource_id   = aws_api_gateway_resource.instances_path.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "instances_path_get" {
  rest_api_id             = aws_api_gateway_rest_api.rest_api.id
  resource_id             = aws_api_gateway_resource.instances_path.id
  http_method             = aws_api_gateway_method.instances_path_get.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  credentials             = aws_iam_role.apigw_role.arn
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:ec2:action/DescribeInstances"
}


resource "aws_api_gateway_integration_response" "instances_path_get" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.instances_path.id
  http_method = aws_api_gateway_method.instances_path_get.http_method
  status_code = "200"
}

resource "aws_api_gateway_method_response" "instances_path_get" {
  rest_api_id = aws_api_gateway_rest_api.rest_api.id
  resource_id = aws_api_gateway_resource.instances_path.id
  http_method = aws_api_gateway_method.instances_path_get.http_method
  status_code = aws_api_gateway_integration_response.instances_path_get.status_code
}

data "aws_iam_policy_document" "apigw_trust_policy" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["apigateway.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "apigw_role" {
  name               = "${var.prefix}_apigw_role"
  assume_role_policy = data.aws_iam_policy_document.apigw_trust_policy.json
}

resource "aws_iam_role_policy" "apigw_role_policy" {
  name = "listinstances"
  role = aws_iam_role.apigw_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ec2:DescribeInstances"]
        Resource = "*"
      }
    ]
  })
}
