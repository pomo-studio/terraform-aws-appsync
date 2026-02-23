# Enable DR Quickly (Module Consumers)

This guide shows the minimum setup to enable secondary-region AppSync support in `pomo-studio/appsync/aws`.

Use this when you want:

- primary + DR AppSync APIs from one module call,
- data source parity across regions,
- caller-owned resolver parity.

## 1) Prerequisites

- Two AWS provider aliases in your root module (`primary`, `dr`).
- A schema file already in use by your primary API.
- DR-side backing resources for any data sources you want in failover (DynamoDB/Lambda/HTTP endpoints).

## 2) Minimum module configuration

```hcl
provider "aws" {
  alias  = "primary"
  region = "us-east-1"
}

provider "aws" {
  alias  = "dr"
  region = "us-west-2"
}

module "appsync" {
  source  = "pomo-studio/appsync/aws"
  version = "~> 1.2"

  providers = {
    aws    = aws.primary
    aws.dr = aws.dr
  }

  name      = "my-api"
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
}
```

## 3) Resolver parity pattern

The module does not create resolvers. Create both primary and DR resolvers explicitly.

```hcl
resource "aws_appsync_resolver" "list_transactions" {
  api_id      = module.appsync.api_id
  type        = "Query"
  field       = "listTransactions"
  data_source = module.appsync.data_source_names["transactions"]

  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }
  code = file("${path.module}/resolvers/listTransactions.js")
}

resource "aws_appsync_resolver" "list_transactions_dr" {
  provider    = aws.dr
  api_id      = module.appsync.dr_api_id
  type        = "Query"
  field       = "listTransactions"
  data_source = module.appsync.dr_data_source_names["transactions"]

  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }
  code = file("${path.module}/resolvers/listTransactions.js")
}
```

## 4) Outputs you should publish to app config

- `api_url`
- `realtime_url`
- `dr_api_url`
- `dr_realtime_url`
- `api_key_id` and `dr_api_key_id` (if `enable_api_key = true`)

## 5) Verify before shipping

1. `terraform validate` passes.
2. Primary + DR API IDs are non-null (`api_id`, `dr_api_id`).
3. Primary + DR data source maps contain the same logical keys.
4. Smoke both endpoints:
   - query works on primary,
   - same query works on DR,
   - mutation + subscription paths are tested if you use them.

For failover operations and runbook guidance, see `docs/ha-failover.md`.

## 6) Common mistakes

- **Forgot provider mapping**: `enable_dr = true` but no `aws.dr` mapping in module block.
- **Only primary resolvers created**: DR API exists, but DR resolver resources are missing.
- **Mismatched data source keys**: code expects `transactions`, but DR map uses a different key.
- **Schema auth mismatch**: endpoint is healthy, but operations fail with `Unauthorized` due to missing auth directives.
