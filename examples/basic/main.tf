terraform {
  cloud {
    organization = "Pitangaville"
    workspaces {
      name = "appsync-example"
    }
  }

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

# =============================================================================
# Prerequisites — created alongside the module (not part of the module itself)
# =============================================================================

resource "aws_cognito_user_pool" "main" {
  name = "example-user-pool"

  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }
}

resource "aws_dynamodb_table" "items" {
  name         = "example-items"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# =============================================================================
# Module under test
# =============================================================================

module "appsync" {
  source  = "pomo-studio/appsync/aws"
  version = "~> 1.0.1"

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
    items = {
      table_name = aws_dynamodb_table.items.name
      table_arn  = aws_dynamodb_table.items.arn
    }
  }

  tags = { Environment = "example" }
}

# =============================================================================
# Sample resolver — exercises data_source_names and none_data_source_name
# =============================================================================

resource "aws_appsync_resolver" "get_user" {
  api_id      = module.appsync.api_id
  type        = "Query"
  field       = "getUser"
  data_source = module.appsync.data_source_names["items"]

  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }

  code = <<-JS
    import { util } from '@aws-appsync/utils';
    export function request(ctx) {
      return { operation: 'GetItem', key: util.dynamodb.toMapValues({ id: ctx.args.userId }) };
    }
    export function response(ctx) { return ctx.result; }
  JS
}

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
    export function request(ctx) { return { payload: null }; }
    export function response(ctx) { return ctx.result; }
  JS
}

# =============================================================================
# Outputs — verify all key module outputs surface correctly
# =============================================================================

output "api_id"                { value = module.appsync.api_id }
output "api_url"               { value = module.appsync.api_url }
output "realtime_url"          { value = module.appsync.realtime_url }
output "none_data_source_name" { value = module.appsync.none_data_source_name }
output "data_source_names"     { value = module.appsync.data_source_names }
output "log_group_name"        { value = module.appsync.log_group_name }
output "api_key"               { value = module.appsync.api_key; sensitive = true }
