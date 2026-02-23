output "api_id" {
  description = "AppSync GraphQL API ID — use this to attach resolvers in the calling module"
  value       = aws_appsync_graphql_api.this.id
}

output "api_arn" {
  description = "AppSync GraphQL API ARN — use this for IAM policy resource construction"
  value       = aws_appsync_graphql_api.this.arn
}

output "dr_api_id" {
  description = "Secondary region AppSync GraphQL API ID when enable_dr = true"
  value       = var.enable_dr ? aws_appsync_graphql_api.dr[0].id : null
}

output "dr_api_arn" {
  description = "Secondary region AppSync GraphQL API ARN when enable_dr = true"
  value       = var.enable_dr ? aws_appsync_graphql_api.dr[0].arn : null
}

output "api_url" {
  description = "HTTPS GraphQL endpoint"
  value       = aws_appsync_graphql_api.this.uris["GRAPHQL"]
}

output "realtime_url" {
  description = "WebSocket (wss://) endpoint for AppSync subscriptions"
  value       = aws_appsync_graphql_api.this.uris["REALTIME"]
}

output "dr_api_url" {
  description = "Secondary region HTTPS GraphQL endpoint when enable_dr = true"
  value       = var.enable_dr ? aws_appsync_graphql_api.dr[0].uris["GRAPHQL"] : null
}

output "dr_realtime_url" {
  description = "Secondary region WebSocket endpoint when enable_dr = true"
  value       = var.enable_dr ? aws_appsync_graphql_api.dr[0].uris["REALTIME"] : null
}

output "data_source_names" {
  description = "Map of logical key → AppSync data source name for DynamoDB, Lambda, and HTTP sources. Keys match the map keys passed in dynamodb_data_sources, lambda_data_sources, and http_data_sources."
  value = merge(
    { for k, v in aws_appsync_datasource.dynamodb : k => v.name },
    { for k, v in aws_appsync_datasource.lambda : k => v.name },
    { for k, v in aws_appsync_datasource.http : k => v.name },
  )
}

output "dr_data_source_names" {
  description = "Map of logical key -> DR AppSync data source name for DR DynamoDB, Lambda, and HTTP sources. Empty map when enable_dr = false."
  value = var.enable_dr ? merge(
    { for k, v in aws_appsync_datasource.dynamodb_dr : k => v.name },
    { for k, v in aws_appsync_datasource.lambda_dr : k => v.name },
    { for k, v in aws_appsync_datasource.http_dr : k => v.name },
  ) : {}
}

output "none_data_source_name" {
  description = "Name of the always-present None data source — use this for subscription resolvers"
  value       = aws_appsync_datasource.none.name
}

output "dr_none_data_source_name" {
  description = "Name of DR None data source when enable_dr = true"
  value       = var.enable_dr ? aws_appsync_datasource.none_dr[0].name : null
}

output "api_key" {
  description = "API key value. Null if enable_api_key = false."
  value       = var.enable_api_key ? aws_appsync_api_key.this[0].key : null
  sensitive   = true
}

output "api_key_id" {
  description = "API key ID. Null if enable_api_key = false."
  value       = var.enable_api_key ? aws_appsync_api_key.this[0].id : null
}

output "dr_api_key" {
  description = "Sensitive DR API key value. Null unless enable_api_key and enable_dr are true."
  value       = var.enable_api_key && var.enable_dr ? aws_appsync_api_key.dr[0].key : null
  sensitive   = true
}

output "dr_api_key_id" {
  description = "DR API key ID. Null unless enable_api_key and enable_dr are true."
  value       = var.enable_api_key && var.enable_dr ? aws_appsync_api_key.dr[0].id : null
}

output "log_group_name" {
  description = "CloudWatch log group name. Null if enable_logging = false."
  value       = var.enable_logging ? aws_cloudwatch_log_group.appsync[0].name : null
}

output "dr_log_group_name" {
  description = "DR CloudWatch log group name when enable_dr and enable_logging are true."
  value       = var.enable_logging && var.enable_dr ? aws_cloudwatch_log_group.appsync_dr[0].name : null
}

output "custom_domain_url" {
  description = "HTTPS URL using custom domain. Null if no custom domain configured."
  value       = local.custom_domain_enabled ? "https://${var.domain_name}/graphql" : null
}

output "graphql_field_arn_prefix" {
  description = "Base ARN prefix for GraphQL field IAM resources (append /Mutation/fields/Name, etc.)"
  value       = "${aws_appsync_graphql_api.this.arn}/types"
}
