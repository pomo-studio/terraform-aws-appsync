terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}

# ---- Prerequisite resources (created outside the module) ----

resource "aws_cognito_user_pool" "main" {
  name = "example-user-pool"
}

resource "aws_dynamodb_table" "users" {
  name         = "example-users"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "userId"

  attribute {
    name = "userId"
    type = "S"
  }
}

resource "aws_dynamodb_table" "ticker_prices" {
  name         = "example-ticker-prices"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "ticker"

  attribute {
    name = "ticker"
    type = "S"
  }
}

resource "aws_lambda_function" "simulator" {
  function_name = "example-price-simulator"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "index.handler"
  runtime       = "python3.12"
  filename      = "lambda.zip"
}

resource "aws_iam_role" "lambda_exec" {
  name = "example-lambda-exec"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

# ---- Module call ----

module "appsync" {
  source  = "pomo-studio/appsync/aws"
  version = "~> 1.0"

  name   = "example-api"
  schema = file("${path.module}/schema.graphql")

  cognito_user_pool_arn = aws_cognito_user_pool.main.arn

  additional_auth_modes = [
    { auth_type = "AWS_IAM" },
    { auth_type = "API_KEY" }
  ]

  enable_api_key       = true
  api_key_expires_days = 365

  dynamodb_data_sources = {
    users = {
      table_name = aws_dynamodb_table.users.name
      table_arn  = aws_dynamodb_table.users.arn
    }
    ticker_prices = {
      table_name = aws_dynamodb_table.ticker_prices.name
      table_arn  = aws_dynamodb_table.ticker_prices.arn
    }
  }

  lambda_data_sources = {
    simulator = { function_arn = aws_lambda_function.simulator.arn }
  }

  tags = {
    Environment = "example"
    Project     = "vue-appsync"
  }
}

# ---- Example resolver using APPSYNC_JS runtime ----

resource "aws_appsync_resolver" "get_user" {
  api_id      = module.appsync.api_id
  type        = "Query"
  field       = "getUser"
  data_source = module.appsync.data_source_names["users"]

  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }

  code = <<-JS
    import { util } from '@aws-appsync/utils';

    export function request(ctx) {
      return {
        operation: 'GetItem',
        key: util.dynamodb.toMapValues({ userId: ctx.args.userId }),
      };
    }

    export function response(ctx) {
      return ctx.result;
    }
  JS
}

# Subscription resolver — uses NoneDataSource
resource "aws_appsync_resolver" "on_ticker_update" {
  api_id      = module.appsync.api_id
  type        = "Subscription"
  field       = "onTickerUpdate"
  data_source = module.appsync.none_data_source_name

  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }

  code = <<-JS
    export function request(ctx) { return {}; }
    export function response(ctx) { return ctx.result; }
  JS
}

# ---- Outputs ----

output "api_url" { value = module.appsync.api_url }
output "realtime_url" { value = module.appsync.realtime_url }
output "log_group" { value = module.appsync.log_group_name }
