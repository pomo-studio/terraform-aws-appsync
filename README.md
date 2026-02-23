# terraform-aws-appsync

Opinionated Terraform module for AWS AppSync GraphQL APIs.

- Cognito + AWS_IAM + API_KEY + OIDC + Lambda authorizer in any combination — one `additional_auth_modes` list
- Per-table least-privilege IAM roles for DynamoDB data sources — never a shared policy
- NoneDataSource always created — subscriptions work without extra setup
- CloudWatch logging and X-Ray tracing on by default
- Optional DR API skeleton via `enable_dr` + `aws.dr` provider alias
- Optional DR parity data sources (`dr_dynamodb_data_sources`, `dr_lambda_data_sources`, `dr_http_data_sources`)
- Resolvers stay in the calling module — this module handles plumbing only

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
  version = "~> 1.1"

  providers = {
    aws    = aws.primary
    aws.dr = aws.dr
  }

  name   = "${var.env}-my-api"
  schema = file("${path.module}/schema.graphql")

  cognito_user_pool_arn = aws_cognito_user_pool.main.arn

  additional_auth_modes = [
    { auth_type = "AWS_IAM" },
    { auth_type = "API_KEY" }
  ]

  enable_api_key = true
  enable_dr      = true

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

# Example: IAM policy for Lambda mutation access
resource "aws_iam_role_policy" "lambda_appsync" {
  name = "my-lambda-appsync"
  role = aws_iam_role.my_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "appsync:GraphQL"
      Resource = "${module.appsync.graphql_field_arn_prefix}/Mutation/fields/notifyTransaction"
    }]
  })
}
```

Note: when using `enable_dr = true`, pass both `aws` and `aws.dr` provider mappings in the module block.

## Inputs

| Name | Type | Default | Description |
|----------|------|---------|-------------|
| `name` | `string` | required | Resource naming prefix (e.g. `"dev-my-api"`) |
| `schema` | `string` | required | GraphQL schema string — use `file()` to load from disk |
| `cognito_user_pool_arn` | `string` | `null` | Cognito User Pool ARN for primary auth. Null disables Cognito auth |
| `additional_auth_modes` | `list(object)` | `[]` | Additional auth modes. Each object: `auth_type` + optional `cognito_user_pool_arn`, `oidc_issuer`, `lambda_authorizer_arn`, `lambda_authorizer_ttl`, `lambda_authorizer_regex` |
| `dynamodb_data_sources` | `map(object)` | `{}` | DynamoDB data sources. Each key is the logical name used in `data_source_names`. Object: `table_name`, `table_arn` |
| `dr_dynamodb_data_sources` | `map(object)` | `{}` | DR DynamoDB data sources (used when `enable_dr = true`). Object: `table_name`, `table_arn` |
| `lambda_data_sources` | `map(object)` | `{}` | Lambda data sources. Each key is the logical name. Object: `function_arn` |
| `dr_lambda_data_sources` | `map(object)` | `{}` | DR Lambda data sources (used when `enable_dr = true`). Object: `function_arn` |
| `http_data_sources` | `map(object)` | `{}` | HTTP data sources. Each key is the logical name. Object: `endpoint` |
| `dr_http_data_sources` | `map(object)` | `{}` | DR HTTP data sources (used when `enable_dr = true`). Object: `endpoint` |
| `enable_api_key` | `bool` | `false` | Create an API key for unauthenticated/public access |
| `api_key_expires_days` | `number` | `365` | Days until API key expires (1–365) |
| `enable_logging` | `bool` | `true` | Enable CloudWatch logging |
| `log_level` | `string` | `"ERROR"` | CloudWatch log level: `NONE`, `ERROR`, or `ALL` |
| `enable_xray` | `bool` | `true` | Enable X-Ray tracing |
| `enable_dr` | `bool` | `false` | Create secondary region API skeleton with provider alias `aws.dr` |
| `domain_name` | `string` | `null` | Custom domain name (e.g. `api.example.com`). Requires `route53_zone_id` and `acm_certificate_arn` |
| `route53_zone_id` | `string` | `null` | Route53 hosted zone ID for custom domain |
| `acm_certificate_arn` | `string` | `null` | ACM certificate ARN for custom domain (must be in same region) |
| `tags` | `map(string)` | `{}` | Tags applied to all resources |

## Outputs

| Output | Description |
|--------|-------------|
| `api_id` | AppSync GraphQL API ID — use this to attach resolvers |
| `api_arn` | AppSync GraphQL API ARN |
| `dr_api_id` | Secondary region API ID. Null if `enable_dr = false` |
| `dr_api_arn` | Secondary region API ARN. Null if `enable_dr = false` |
| `api_url` | HTTPS GraphQL endpoint |
| `realtime_url` | WebSocket (`wss://`) endpoint for subscriptions |
| `dr_api_url` | Secondary region GraphQL endpoint. Null if `enable_dr = false` |
| `dr_realtime_url` | Secondary region realtime endpoint. Null if `enable_dr = false` |
| `data_source_names` | Map of logical key → AppSync data source name (covers DynamoDB, Lambda, HTTP sources) |
| `dr_data_source_names` | Map of logical key → DR AppSync data source name (empty when `enable_dr = false`) |
| `none_data_source_name` | Name of the always-present None data source — use for subscription resolvers |
| `dr_none_data_source_name` | DR None data source name. Null if `enable_dr = false` |
| `api_key` | Sensitive. API key value. Null if `enable_api_key = false` |
| `api_key_id` | API key ID. Null if `enable_api_key = false` |
| `dr_api_key` | Sensitive DR API key value. Null unless `enable_api_key` and `enable_dr` are true |
| `dr_api_key_id` | DR API key ID. Null unless `enable_api_key` and `enable_dr` are true |
| `log_group_name` | CloudWatch log group name. Null if `enable_logging = false` |
| `dr_log_group_name` | DR log group name. Null unless `enable_logging` and `enable_dr` are true |
| `custom_domain_url` | HTTPS URL using custom domain. Null if no custom domain configured |
| `graphql_field_arn_prefix` | Base ARN prefix for GraphQL IAM field resources |

## Requirements

| Provider | Version |
|----------|---------|
| aws | ~> 5.0 |

## Design decisions

- Logging **on** by default at `ERROR` level
- X-Ray **on** by default
- Per-data-source IAM roles (never a shared policy)
- `NoneDataSource` always created
- `realtime_url` always in outputs (subscriptions are first-class)
- `enable_dr` creates a secondary API and optional DR parity data sources; resolvers remain caller-owned
- Caller owns resolvers — module handles plumbing only

## HA parity contract (Level 2)

When `enable_dr = true`, parity means:

1. Two APIs exist with the same schema/auth baseline (primary + DR).
2. Caller may provide equivalent DR data sources using `dr_*_data_sources` maps.
3. Resolvers are still app-owned and must be attached to both APIs by the caller.

What this module does not decide:

- endpoint failover policy for clients,
- active-active conflict semantics,
- app-specific resolver rollout order.

## Examples

- [`examples/basic`](examples/basic/) — Cognito auth, single DynamoDB source
- [`examples/dr-parity`](examples/dr-parity/) — dual-region API with parity data source maps

## License

MIT
