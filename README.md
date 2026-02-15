# terraform-aws-appsync

Opinionated Terraform module for AWS AppSync GraphQL APIs.

**Registry**: `pomo-studio/appsync/aws`

## What it creates

**Always:**
- `aws_appsync_graphql_api` with schema supplied by the caller
- CloudWatch log group + IAM role (logging on by default — people always forget this)
- `NoneDataSource` — always present, required for subscriptions
- X-Ray tracing enabled by default

**Conditional:**
- Cognito User Pool auth (when `cognito_user_pool_arn` set)
- Additional auth modes: AWS_IAM, API_KEY, OIDC, Lambda
- API key resource (when `enable_api_key = true`)
- DynamoDB data sources with **per-table least-privilege IAM roles**
- Lambda data sources + IAM invoke permission
- HTTP data sources
- Custom domain + Route53 record

The module handles plumbing only. Resolvers stay in the calling module — they're always app-specific.

## Usage

```hcl
module "appsync" {
  source  = "pomo-studio/appsync/aws"
  version = "~> 1.0"

  name   = "${var.env}-my-api"
  schema = file("${path.module}/schema.graphql")

  cognito_user_pool_arn = aws_cognito_user_pool.main.arn

  additional_auth_modes = [
    { auth_type = "AWS_IAM" },
    { auth_type = "API_KEY" }
  ]

  enable_api_key = true

  dynamodb_data_sources = {
    users = {
      table_name = aws_dynamodb_table.users.name
      table_arn  = aws_dynamodb_table.users.arn
    }
  }

  lambda_data_sources = {
    processor = { function_arn = aws_lambda_function.processor.arn }
  }

  tags = { Environment = var.env }
}

# Attach resolvers — these are always app-specific
resource "aws_appsync_resolver" "get_user" {
  api_id      = module.appsync.api_id
  type        = "Query"
  field       = "getUser"
  data_source = module.appsync.data_source_names["users"]

  runtime {
    name            = "APPSYNC_JS"
    runtime_version = "1.0.0"
  }
  code = file("${path.module}/resolvers/get_user.js")
}
```

## Key outputs

| Output | Description |
|--------|-------------|
| `api_id` | Use to attach resolvers |
| `api_url` | HTTPS GraphQL endpoint |
| `realtime_url` | WebSocket endpoint (wss://) for subscriptions |
| `data_source_names` | Map of logical key → AppSync data source name |
| `none_data_source_name` | Always `"NoneDataSource"` — for subscription resolvers |
| `api_key` | Sensitive. Null if `enable_api_key = false` |
| `log_group_name` | CloudWatch log group |

## Requirements

| Provider | Version |
|----------|---------|
| aws | ~> 5.0 |

## Opinionated defaults

- Logging **on** by default at `ERROR` level
- X-Ray **on** by default
- Per-data-source IAM roles (never a shared policy)
- `NoneDataSource` always created
- `realtime_url` always in outputs (subscriptions are first-class)
- Caller owns resolvers — module handles plumbing only
