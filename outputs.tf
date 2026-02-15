output "api_id" {
  description = "AppSync GraphQL API ID — use this to attach resolvers in the calling module"
  value       = aws_appsync_graphql_api.this.id
}

output "api_url" {
  description = "HTTPS GraphQL endpoint"
  value       = aws_appsync_graphql_api.this.uris["GRAPHQL"]
}

output "realtime_url" {
  description = "WebSocket (wss://) endpoint for AppSync subscriptions"
  value       = aws_appsync_graphql_api.this.uris["REALTIME"]
}

output "data_source_names" {
  description = "Map of logical key → AppSync data source name for DynamoDB, Lambda, and HTTP sources. Keys match the map keys passed in dynamodb_data_sources, lambda_data_sources, and http_data_sources."
  value = merge(
    { for k, v in aws_appsync_datasource.dynamodb : k => v.name },
    { for k, v in aws_appsync_datasource.lambda : k => v.name },
    { for k, v in aws_appsync_datasource.http : k => v.name },
  )
}

output "none_data_source_name" {
  description = "Name of the always-present None data source — use this for subscription resolvers"
  value       = aws_appsync_datasource.none.name
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

output "log_group_name" {
  description = "CloudWatch log group name. Null if enable_logging = false."
  value       = var.enable_logging ? aws_cloudwatch_log_group.appsync[0].name : null
}

output "custom_domain_url" {
  description = "HTTPS URL using custom domain. Null if no custom domain configured."
  value       = local.custom_domain_enabled ? "https://${var.domain_name}/graphql" : null
}
