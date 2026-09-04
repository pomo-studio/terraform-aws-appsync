terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0, < 7.0"
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

resource "aws_dynamodb_table" "transactions_primary" {
  provider     = aws.primary
  name         = "dr-parity-transactions-primary"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_dynamodb_table" "transactions_dr" {
  provider     = aws.dr
  name         = "dr-parity-transactions-dr"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
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
      table_name = aws_dynamodb_table.transactions_primary.name
      table_arn  = aws_dynamodb_table.transactions_primary.arn
    }
  }

  dr_dynamodb_data_sources = {
    transactions = {
      table_name = aws_dynamodb_table.transactions_dr.name
      table_arn  = aws_dynamodb_table.transactions_dr.arn
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
