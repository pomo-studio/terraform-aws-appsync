terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  alias  = "primary"
  region = "us-east-1"
}

provider "aws" {
  alias  = "dr"
  region = "us-west-2"
}

resource "aws_cognito_user_pool" "main" {
  provider = aws.primary
  name     = "dr-parity-user-pool"
}

module "transactions_primary_table" {
  source  = "pomo-studio/dynamodb-global-table/aws"
  version = "= 1.0.0"

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }

  name           = "dr-parity-transactions-primary"
  hash_key       = "id"
  attributes     = [{ name = "id", type = "S" }]
  enable_dr      = false
  enable_pitr    = false
  enable_streams = false
}

module "transactions_dr_table" {
  source  = "pomo-studio/dynamodb-global-table/aws"
  version = "= 1.0.0"

  providers = {
    aws.primary = aws.dr
    aws.dr      = aws.dr
  }

  name           = "dr-parity-transactions-dr"
  hash_key       = "id"
  attributes     = [{ name = "id", type = "S" }]
  enable_dr      = false
  enable_pitr    = false
  enable_streams = false
}

module "appsync" {
  source = "../../"

  providers = {
    aws    = aws.primary
    aws.dr = aws.dr
  }

  name      = "dr-parity-api"
  schema    = file("${path.module}/schema.graphql")
  enable_dr = true

  cognito_user_pool_arn = aws_cognito_user_pool.main.arn

  additional_auth_modes = [
    { auth_type = "AWS_IAM" }
  ]

  dynamodb_data_sources = {
    transactions = {
      table_name = module.transactions_primary_table.table_name_primary
      table_arn  = module.transactions_primary_table.table_arn_primary
    }
  }

  dr_dynamodb_data_sources = {
    transactions = {
      table_name = module.transactions_dr_table.table_name_primary
      table_arn  = module.transactions_dr_table.table_arn_primary
    }
  }

  lambda_data_sources = {
    enricher = {
      function_arn = "arn:aws:lambda:us-east-1:123456789012:function:dr-parity-enricher-primary"
    }
  }

  dr_lambda_data_sources = {
    enricher = {
      function_arn = "arn:aws:lambda:us-west-2:123456789012:function:dr-parity-enricher-dr"
    }
  }

  http_data_sources = {
    upstream = {
      endpoint = "https://api.example.com"
    }
  }

  dr_http_data_sources = {
    upstream = {
      endpoint = "https://dr-api.example.com"
    }
  }

  tags = {
    Environment = "example"
  }
}

output "primary_api_url" {
  value = module.appsync.api_url
}

output "dr_api_url" {
  value = module.appsync.dr_api_url
}

output "primary_data_sources" {
  value = module.appsync.data_source_names
}

output "dr_data_sources" {
  value = module.appsync.dr_data_source_names
}
