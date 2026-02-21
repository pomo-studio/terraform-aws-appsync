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

## Inputs

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `name` | `string` | required | Resource naming prefix (e.g. `"dev-my-api"`) |
| `schema` | `string` | required | GraphQL schema string — use `file()` to load from disk |
| `cognito_user_pool_arn` | `string` | `null` | Cognito User Pool ARN for primary auth. Null disables Cognito auth |
| `additional_auth_modes` | `list(object)` | `[]` | Additional auth modes. Each object: `auth_type` + optional `cognito_user_pool_arn`, `oidc_issuer`, `lambda_authorizer_arn`, `lambda_authorizer_ttl`, `lambda_authorizer_regex` |
| `dynamodb_data_sources` | `map(object)` | `{}` | DynamoDB data sources. Each key is the logical name used in `data_source_names`. Object: `table_name`, `table_arn` |
| `lambda_data_sources` | `map(object)` | `{}` | Lambda data sources. Each key is the logical name. Object: `function_arn` |
| `http_data_sources` | `map(object)` | `{}` | HTTP data sources. Each key is the logical name. Object: `endpoint` |
| `enable_api_key` | `bool` | `false` | Create an API key for unauthenticated/public access |
| `api_key_expires_days` | `number` | `365` | Days until API key expires (1–365) |
| `enable_logging` | `bool` | `true` | Enable CloudWatch logging |
| `log_level` | `string` | `"ERROR"` | CloudWatch log level: `NONE`, `ERROR`, or `ALL` |
| `enable_xray` | `bool` | `true` | Enable X-Ray tracing |
| `domain_name` | `string` | `null` | Custom domain name (e.g. `api.example.com`). Requires `route53_zone_id` and `acm_certificate_arn` |
| `route53_zone_id` | `string` | `null` | Route53 hosted zone ID for custom domain |
| `acm_certificate_arn` | `string` | `null` | ACM certificate ARN for custom domain (must be in same region) |
| `tags` | `map(string)` | `{}` | Tags applied to all resources |

## Outputs

| Output | Description |
|--------|-------------|
| `api_id` | AppSync GraphQL API ID — use this to attach resolvers |
| `api_url` | HTTPS GraphQL endpoint |
| `realtime_url` | WebSocket (`wss://`) endpoint for subscriptions |
| `data_source_names` | Map of logical key → AppSync data source name (covers DynamoDB, Lambda, HTTP sources) |
| `none_data_source_name` | Name of the always-present None data source — use for subscription resolvers |
| `api_key` | Sensitive. API key value. Null if `enable_api_key = false` |
| `api_key_id` | API key ID. Null if `enable_api_key = false` |
| `log_group_name` | CloudWatch log group name. Null if `enable_logging = false` |
| `custom_domain_url` | HTTPS URL using custom domain. Null if no custom domain configured |

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
