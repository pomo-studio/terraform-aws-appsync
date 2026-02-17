locals {
  # Determine primary auth type
  primary_auth_type = var.cognito_user_pool_arn != null ? "AMAZON_COGNITO_USER_POOLS" : "AWS_IAM"

  # Build additional_authentication_provider blocks
  additional_auth_modes = var.additional_auth_modes

  custom_domain_enabled = var.domain_name != null && var.route53_zone_id != null && var.acm_certificate_arn != null
}

resource "aws_appsync_graphql_api" "this" {
  name                = var.name
  authentication_type = local.primary_auth_type
  schema              = var.schema

  dynamic "user_pool_config" {
    for_each = var.cognito_user_pool_arn != null ? [1] : []
    content {
      # Extract user pool ID from ARN: arn:aws:cognito-idp:REGION:ACCOUNT:userpool/POOL_ID
      user_pool_id   = element(split("/", element(split(":", var.cognito_user_pool_arn), length(split(":", var.cognito_user_pool_arn)) - 1)), 1)
      aws_region     = element(split(":", var.cognito_user_pool_arn), 3)
      default_action = "ALLOW"
    }
  }

  dynamic "additional_authentication_provider" {
    for_each = local.additional_auth_modes
    content {
      authentication_type = additional_authentication_provider.value.auth_type

      dynamic "user_pool_config" {
        for_each = additional_authentication_provider.value.auth_type == "AMAZON_COGNITO_USER_POOLS" && additional_authentication_provider.value.cognito_user_pool_arn != null ? [1] : []
        content {
          # Extract user pool ID from ARN: arn:aws:cognito-idp:REGION:ACCOUNT:userpool/POOL_ID
          user_pool_id = element(split("/", element(split(":", additional_authentication_provider.value.cognito_user_pool_arn), length(split(":", additional_authentication_provider.value.cognito_user_pool_arn)) - 1)), 1)
          aws_region   = element(split(":", additional_authentication_provider.value.cognito_user_pool_arn), 3)
        }
      }

      dynamic "openid_connect_config" {
        for_each = additional_authentication_provider.value.auth_type == "OPENID_CONNECT" && additional_authentication_provider.value.oidc_issuer != null ? [1] : []
        content {
          issuer = additional_authentication_provider.value.oidc_issuer
        }
      }

      dynamic "lambda_authorizer_config" {
        for_each = additional_authentication_provider.value.auth_type == "AWS_LAMBDA" && additional_authentication_provider.value.lambda_authorizer_arn != null ? [1] : []
        content {
          authorizer_uri                   = additional_authentication_provider.value.lambda_authorizer_arn
          authorizer_result_ttl_in_seconds = additional_authentication_provider.value.lambda_authorizer_ttl
          identity_validation_expression   = additional_authentication_provider.value.lambda_authorizer_regex
        }
      }
    }
  }

  dynamic "log_config" {
    for_each = var.enable_logging ? [1] : []
    content {
      cloudwatch_logs_role_arn = aws_iam_role.appsync_logging[0].arn
      field_log_level          = var.log_level
    }
  }

  xray_enabled = var.enable_xray

  tags = var.tags
}

# --- Logging ---

resource "aws_cloudwatch_log_group" "appsync" {
  count             = var.enable_logging ? 1 : 0
  name              = "/aws/appsync/apis/${aws_appsync_graphql_api.this.id}"
  retention_in_days = 30
  tags              = var.tags
}

resource "aws_iam_role" "appsync_logging" {
  count = var.enable_logging ? 1 : 0
  name  = "${var.name}-appsync-logging"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "appsync.amazonaws.com" }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "appsync_logging" {
  count = var.enable_logging ? 1 : 0
  name  = "${var.name}-appsync-logging"
  role  = aws_iam_role.appsync_logging[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Resource = "${aws_cloudwatch_log_group.appsync[0].arn}:*"
    }]
  })
}

# --- API Key ---

resource "aws_appsync_api_key" "this" {
  count   = var.enable_api_key ? 1 : 0
  api_id  = aws_appsync_graphql_api.this.id
  expires = timeadd(timestamp(), "${var.api_key_expires_days * 24}h")

  lifecycle {
    ignore_changes = [expires]
  }
}

# --- None data source (always present — required for subscriptions) ---

resource "aws_appsync_datasource" "none" {
  api_id = aws_appsync_graphql_api.this.id
  name   = "NoneDataSource"
  type   = "NONE"
}

# --- Custom domain ---

resource "aws_appsync_domain_name" "this" {
  count           = local.custom_domain_enabled ? 1 : 0
  domain_name     = var.domain_name
  certificate_arn = var.acm_certificate_arn
}

resource "aws_appsync_domain_name_api_association" "this" {
  count       = local.custom_domain_enabled ? 1 : 0
  api_id      = aws_appsync_graphql_api.this.id
  domain_name = aws_appsync_domain_name.this[0].domain_name
}

resource "aws_route53_record" "appsync" {
  count   = local.custom_domain_enabled ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.domain_name
  type    = "CNAME"
  ttl     = 300
  records = [aws_appsync_domain_name.this[0].appsync_domain_name]
}
