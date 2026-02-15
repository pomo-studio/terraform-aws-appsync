variable "name" {
  description = "Resource naming prefix (e.g. 'dev-vue-appsync')"
  type        = string
}

variable "schema" {
  description = "GraphQL schema string (use file() to load from disk)"
  type        = string
}

variable "cognito_user_pool_arn" {
  description = "Cognito User Pool ARN for primary auth. Null disables Cognito auth."
  type        = string
  default     = null
}

variable "additional_auth_modes" {
  description = "Additional authentication modes beyond the primary. Each object needs auth_type plus optional config for OIDC/Lambda/API_KEY modes."
  type = list(object({
    auth_type               = string
    cognito_user_pool_arn   = optional(string)
    oidc_issuer             = optional(string)
    lambda_authorizer_arn   = optional(string)
    lambda_authorizer_ttl   = optional(number, 300)
    lambda_authorizer_regex = optional(string)
  }))
  default = []
}

variable "dynamodb_data_sources" {
  description = "DynamoDB data sources. Each key becomes the logical name used in data_source_names output."
  type = map(object({
    table_name = string
    table_arn  = string
  }))
  default = {}
}

variable "lambda_data_sources" {
  description = "Lambda data sources. Each key becomes the logical name used in data_source_names output."
  type = map(object({
    function_arn = string
  }))
  default = {}
}

variable "http_data_sources" {
  description = "HTTP data sources. Each key becomes the logical name used in data_source_names output."
  type = map(object({
    endpoint = string
  }))
  default = {}
}

variable "enable_api_key" {
  description = "Create an API key for unauthenticated/public access"
  type        = bool
  default     = false
}

variable "api_key_expires_days" {
  description = "Number of days until the API key expires (1-365)"
  type        = number
  default     = 365
}

variable "enable_logging" {
  description = "Enable CloudWatch logging for the AppSync API"
  type        = bool
  default     = true
}

variable "log_level" {
  description = "AppSync field-level CloudWatch log level: NONE, ERROR, or ALL"
  type        = string
  default     = "ERROR"
  validation {
    condition     = contains(["NONE", "ERROR", "ALL"], var.log_level)
    error_message = "log_level must be NONE, ERROR, or ALL."
  }
}

variable "enable_xray" {
  description = "Enable X-Ray tracing for the AppSync API"
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "Custom domain name for the AppSync API (e.g. api.example.com). Requires route53_zone_id and acm_certificate_arn."
  type        = string
  default     = null
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for custom domain DNS record"
  type        = string
  default     = null
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for custom domain (must be in same region)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
