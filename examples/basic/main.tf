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
  alias  = "primary"
  region = "us-east-2"
}

provider "aws" {
  alias  = "dr"
  region = "us-west-2"
}

# =============================================================================
# Prerequisites — created alongside the module (not part of the module itself)
# =============================================================================

resource "aws_cognito_user_pool" "main" {
  provider = aws.primary
  name     = "example-user-pool"

  email_configuration {
    email_sending_account = "COGNITO_DEFAULT"
  }
}

module "items_table" {
  source  = "pomo-studio/dynamodb-global-table/aws"
  version = "= 1.0.0"

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }

  name           = "example-items"
  hash_key       = "id"
  attributes     = [{ name = "id", type = "S" }]
  enable_dr      = false
  enable_pitr    = false
  enable_streams = false
}

# =============================================================================
# Module under test
# =============================================================================

module "appsync" {
  source = "../../"

  providers = {
    aws    = aws.primary
    aws.dr = aws.dr
  }

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
      table_name = module.items_table.table_name_primary
      table_arn  = module.items_table.table_arn_primary
    }
  }

  tags = { Environment = "example" }
}

# =============================================================================
# Sample resolver — exercises data_source_names and none_data_source_name
# =============================================================================

resource "aws_appsync_resolver" "get_user" {
  provider    = aws.primary
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
  provider    = aws.primary
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

output "api_id" { value = module.appsync.api_id }
output "api_url" { value = module.appsync.api_url }
output "realtime_url" { value = module.appsync.realtime_url }
output "none_data_source_name" { value = module.appsync.none_data_source_name }
output "data_source_names" { value = module.appsync.data_source_names }
output "log_group_name" { value = module.appsync.log_group_name }
output "api_key" {
  value     = module.appsync.api_key
  sensitive = true
}
