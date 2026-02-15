# DynamoDB data sources — one IAM role per table (least privilege)

resource "aws_iam_role" "dynamodb" {
  for_each = var.dynamodb_data_sources
  name     = "${var.name}-appsync-dynamo-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "appsync.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "dynamodb" {
  for_each = var.dynamodb_data_sources
  name     = "${var.name}-appsync-dynamo-${each.key}"
  role     = aws_iam_role.dynamodb[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Scan",
        "dynamodb:Query",
        "dynamodb:BatchGetItem",
        "dynamodb:BatchWriteItem"
      ]
      Resource = [
        each.value.table_arn,
        "${each.value.table_arn}/index/*"
      ]
    }]
  })
}

resource "aws_appsync_datasource" "dynamodb" {
  for_each         = var.dynamodb_data_sources
  api_id           = aws_appsync_graphql_api.this.id
  name             = "${replace(title(replace(each.key, "_", " ")), " ", "")}DataSource"
  type             = "AMAZON_DYNAMODB"
  service_role_arn = aws_iam_role.dynamodb[each.key].arn

  dynamodb_config {
    table_name = each.value.table_name
    region     = data.aws_region.current.name
  }
}

# Lambda data sources

resource "aws_iam_role" "lambda" {
  for_each = var.lambda_data_sources
  name     = "${var.name}-appsync-lambda-${each.key}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "appsync.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "lambda" {
  for_each = var.lambda_data_sources
  name     = "${var.name}-appsync-lambda-${each.key}"
  role     = aws_iam_role.lambda[each.key].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = each.value.function_arn
    }]
  })
}

resource "aws_appsync_datasource" "lambda" {
  for_each         = var.lambda_data_sources
  api_id           = aws_appsync_graphql_api.this.id
  name             = "${replace(title(replace(each.key, "_", " ")), " ", "")}DataSource"
  type             = "AWS_LAMBDA"
  service_role_arn = aws_iam_role.lambda[each.key].arn

  lambda_config {
    function_arn = each.value.function_arn
  }
}

# HTTP data sources

resource "aws_appsync_datasource" "http" {
  for_each = var.http_data_sources
  api_id   = aws_appsync_graphql_api.this.id
  name     = "${replace(title(replace(each.key, "_", " ")), " ", "")}DataSource"
  type     = "HTTP"

  http_config {
    endpoint = each.value.endpoint
  }
}

# Data source for current region

data "aws_region" "current" {}
