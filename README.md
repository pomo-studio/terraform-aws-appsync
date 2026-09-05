# terraform-aws-appsync

[![Terraform Validation](https://github.com/pomo-studio/terraform-aws-appsync/actions/workflows/terraform.yml/badge.svg)](https://github.com/pomo-studio/terraform-aws-appsync/actions/workflows/terraform.yml)
[![Terraform Registry](https://img.shields.io/badge/terraform-registry-844FBA?logo=terraform)](https://registry.terraform.io/modules/pomo-studio/appsync/aws)

- [Changelog](CHANGELOG.md)

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
| aws | >= 5.0, < 7.0 |

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

## Level 3 operations

- DR enablement quickstart: [`docs/enable-dr.md`](docs/enable-dr.md)
- Failover strategy and runbook: [`docs/ha-failover.md`](docs/ha-failover.md)
- Smoke helper script: `scripts/smoke-failover.sh`

## Examples

- [`examples/basic`](examples/basic/) — Cognito auth, single DynamoDB source
- [`examples/dr-parity`](examples/dr-parity/) — dual-region API with parity data source maps

## License

MIT

## Maintaining This Module

The generated interface below is authoritative for requirements, providers, resources, inputs, and outputs. Regenerate with `terraform-docs` **v0.20.0**: `terraform-docs .`. CI fails on drift; keep explanatory prose outside the generated markers.

See the [contribution guide](https://github.com/pomo-studio/.github/blob/main/CONTRIBUTING.md) and [security policy](https://github.com/pomo-studio/.github/blob/main/SECURITY.md). PR validation does not prove a live plan or deployment. Infrastructure plans and applies belong in Terraform Cloud; never provide cloud credentials to untrusted PR code.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.5.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0, < 7.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.63.0 |
| <a name="provider_aws.dr"></a> [aws.dr](#provider\_aws.dr) | 6.63.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_appsync_api_key.dr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_api_key) | resource |
| [aws_appsync_api_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_api_key) | resource |
| [aws_appsync_datasource.dynamodb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_datasource) | resource |
| [aws_appsync_datasource.dynamodb_dr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_datasource) | resource |
| [aws_appsync_datasource.http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_datasource) | resource |
| [aws_appsync_datasource.http_dr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_datasource) | resource |
| [aws_appsync_datasource.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_datasource) | resource |
| [aws_appsync_datasource.lambda_dr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_datasource) | resource |
| [aws_appsync_datasource.none](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_datasource) | resource |
| [aws_appsync_datasource.none_dr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_datasource) | resource |
| [aws_appsync_domain_name.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_domain_name) | resource |
| [aws_appsync_domain_name_api_association.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_domain_name_api_association) | resource |
| [aws_appsync_graphql_api.dr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_graphql_api) | resource |
| [aws_appsync_graphql_api.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/appsync_graphql_api) | resource |
| [aws_cloudwatch_log_group.appsync](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_cloudwatch_log_group.appsync_dr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_role.appsync_logging](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.appsync_logging_dr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.dynamodb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.dynamodb_dr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.lambda_dr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.appsync_logging](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.appsync_logging_dr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.dynamodb](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.dynamodb_dr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.lambda_dr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_route53_record.appsync](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_region.current_dr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_acm_certificate_arn"></a> [acm\_certificate\_arn](#input\_acm\_certificate\_arn) | ACM certificate ARN for custom domain (must be in same region) | `string` | `null` | no |
| <a name="input_additional_auth_modes"></a> [additional\_auth\_modes](#input\_additional\_auth\_modes) | Additional authentication modes beyond the primary. Each object needs auth\_type plus optional config for OIDC/Lambda/API\_KEY modes. | <pre>list(object({<br/>    auth_type               = string<br/>    cognito_user_pool_arn   = optional(string)<br/>    oidc_issuer             = optional(string)<br/>    lambda_authorizer_arn   = optional(string)<br/>    lambda_authorizer_ttl   = optional(number, 300)<br/>    lambda_authorizer_regex = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_api_key_expires_days"></a> [api\_key\_expires\_days](#input\_api\_key\_expires\_days) | Number of days until the API key expires (1-365) | `number` | `365` | no |
| <a name="input_cognito_user_pool_arn"></a> [cognito\_user\_pool\_arn](#input\_cognito\_user\_pool\_arn) | Cognito User Pool ARN for primary auth. Null disables Cognito auth. Must match pattern: arn:aws:cognito-idp:REGION:ACCOUNT:userpool/POOL\_ID | `string` | `null` | no |
| <a name="input_domain_name"></a> [domain\_name](#input\_domain\_name) | Custom domain name for the AppSync API (e.g. api.example.com). Requires route53\_zone\_id and acm\_certificate\_arn. | `string` | `null` | no |
| <a name="input_dr_dynamodb_data_sources"></a> [dr\_dynamodb\_data\_sources](#input\_dr\_dynamodb\_data\_sources) | DR-region DynamoDB data sources used when enable\_dr = true. Each key becomes the logical name used in dr\_data\_source\_names output. | <pre>map(object({<br/>    table_name = string<br/>    table_arn  = string<br/>  }))</pre> | `{}` | no |
| <a name="input_dr_http_data_sources"></a> [dr\_http\_data\_sources](#input\_dr\_http\_data\_sources) | DR-region HTTP data sources used when enable\_dr = true. Each key becomes the logical name used in dr\_data\_source\_names output. | <pre>map(object({<br/>    endpoint = string<br/>  }))</pre> | `{}` | no |
| <a name="input_dr_lambda_data_sources"></a> [dr\_lambda\_data\_sources](#input\_dr\_lambda\_data\_sources) | DR-region Lambda data sources used when enable\_dr = true. Each key becomes the logical name used in dr\_data\_source\_names output. | <pre>map(object({<br/>    function_arn = string<br/>  }))</pre> | `{}` | no |
| <a name="input_dynamodb_data_sources"></a> [dynamodb\_data\_sources](#input\_dynamodb\_data\_sources) | DynamoDB data sources. Each key becomes the logical name used in data\_source\_names output. | <pre>map(object({<br/>    table_name = string<br/>    table_arn  = string<br/>  }))</pre> | `{}` | no |
| <a name="input_enable_api_key"></a> [enable\_api\_key](#input\_enable\_api\_key) | Create an API key for unauthenticated/public access | `bool` | `false` | no |
| <a name="input_enable_dr"></a> [enable\_dr](#input\_enable\_dr) | When true, create a secondary AppSync API in the aws.dr provider with matching schema/auth/log settings | `bool` | `false` | no |
| <a name="input_enable_logging"></a> [enable\_logging](#input\_enable\_logging) | Enable CloudWatch logging for the AppSync API | `bool` | `true` | no |
| <a name="input_enable_xray"></a> [enable\_xray](#input\_enable\_xray) | Enable X-Ray tracing for the AppSync API | `bool` | `true` | no |
| <a name="input_http_data_sources"></a> [http\_data\_sources](#input\_http\_data\_sources) | HTTP data sources. Each key becomes the logical name used in data\_source\_names output. | <pre>map(object({<br/>    endpoint = string<br/>  }))</pre> | `{}` | no |
| <a name="input_lambda_data_sources"></a> [lambda\_data\_sources](#input\_lambda\_data\_sources) | Lambda data sources. Each key becomes the logical name used in data\_source\_names output. | <pre>map(object({<br/>    function_arn = string<br/>  }))</pre> | `{}` | no |
| <a name="input_log_level"></a> [log\_level](#input\_log\_level) | AppSync field-level CloudWatch log level: NONE, ERROR, or ALL | `string` | `"ERROR"` | no |
| <a name="input_name"></a> [name](#input\_name) | Resource naming prefix (e.g. 'dev-vue-appsync') | `string` | n/a | yes |
| <a name="input_route53_zone_id"></a> [route53\_zone\_id](#input\_route53\_zone\_id) | Route53 hosted zone ID for custom domain DNS record | `string` | `null` | no |
| <a name="input_schema"></a> [schema](#input\_schema) | GraphQL schema string (use file() to load from disk) | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags applied to all resources | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_api_arn"></a> [api\_arn](#output\_api\_arn) | AppSync GraphQL API ARN — use this for IAM policy resource construction |
| <a name="output_api_id"></a> [api\_id](#output\_api\_id) | AppSync GraphQL API ID — use this to attach resolvers in the calling module |
| <a name="output_api_key"></a> [api\_key](#output\_api\_key) | API key value. Null if enable\_api\_key = false. |
| <a name="output_api_key_id"></a> [api\_key\_id](#output\_api\_key\_id) | API key ID. Null if enable\_api\_key = false. |
| <a name="output_api_url"></a> [api\_url](#output\_api\_url) | HTTPS GraphQL endpoint |
| <a name="output_custom_domain_url"></a> [custom\_domain\_url](#output\_custom\_domain\_url) | HTTPS URL using custom domain. Null if no custom domain configured. |
| <a name="output_data_source_names"></a> [data\_source\_names](#output\_data\_source\_names) | Map of logical key → AppSync data source name for DynamoDB, Lambda, and HTTP sources. Keys match the map keys passed in dynamodb\_data\_sources, lambda\_data\_sources, and http\_data\_sources. |
| <a name="output_dr_api_arn"></a> [dr\_api\_arn](#output\_dr\_api\_arn) | Secondary region AppSync GraphQL API ARN when enable\_dr = true |
| <a name="output_dr_api_id"></a> [dr\_api\_id](#output\_dr\_api\_id) | Secondary region AppSync GraphQL API ID when enable\_dr = true |
| <a name="output_dr_api_key"></a> [dr\_api\_key](#output\_dr\_api\_key) | Sensitive DR API key value. Null unless enable\_api\_key and enable\_dr are true. |
| <a name="output_dr_api_key_id"></a> [dr\_api\_key\_id](#output\_dr\_api\_key\_id) | DR API key ID. Null unless enable\_api\_key and enable\_dr are true. |
| <a name="output_dr_api_url"></a> [dr\_api\_url](#output\_dr\_api\_url) | Secondary region HTTPS GraphQL endpoint when enable\_dr = true |
| <a name="output_dr_data_source_names"></a> [dr\_data\_source\_names](#output\_dr\_data\_source\_names) | Map of logical key -> DR AppSync data source name for DR DynamoDB, Lambda, and HTTP sources. Empty map when enable\_dr = false. |
| <a name="output_dr_log_group_name"></a> [dr\_log\_group\_name](#output\_dr\_log\_group\_name) | DR CloudWatch log group name when enable\_dr and enable\_logging are true. |
| <a name="output_dr_none_data_source_name"></a> [dr\_none\_data\_source\_name](#output\_dr\_none\_data\_source\_name) | Name of DR None data source when enable\_dr = true |
| <a name="output_dr_realtime_url"></a> [dr\_realtime\_url](#output\_dr\_realtime\_url) | Secondary region WebSocket endpoint when enable\_dr = true |
| <a name="output_graphql_field_arn_prefix"></a> [graphql\_field\_arn\_prefix](#output\_graphql\_field\_arn\_prefix) | Base ARN prefix for GraphQL field IAM resources (append /Mutation/fields/Name, etc.) |
| <a name="output_log_group_name"></a> [log\_group\_name](#output\_log\_group\_name) | CloudWatch log group name. Null if enable\_logging = false. |
| <a name="output_none_data_source_name"></a> [none\_data\_source\_name](#output\_none\_data\_source\_name) | Name of the always-present None data source — use this for subscription resolvers |
| <a name="output_realtime_url"></a> [realtime\_url](#output\_realtime\_url) | WebSocket (wss://) endpoint for AppSync subscriptions |
<!-- END_TF_DOCS -->
