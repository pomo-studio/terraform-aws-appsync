# Unit tests for terraform-aws-appsync
#
# Requires Terraform >= 1.9.0
#   - mock_provider support (>= 1.7.0)
#   - cross-variable references in validation blocks (>= 1.9.0)
#
# NOTE: mock_provider generates synthetic ARNs that may not pass AWS ARN format
# validation in assert conditions. Tests here focus on resource counts, names,
# and configuration attributes — not ARNs — to stay compatible with mock mode.

mock_provider "aws" {
  # Provide valid ARN formats so the AWS provider's ARN validation doesn't
  # reject the synthetic values that mock_provider generates by default.

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
    }
  }

  mock_data "aws_region" {
    defaults = {
      name = "us-east-1"
    }
  }

  mock_resource "aws_appsync_graphql_api" {
    defaults = {
      arn              = "arn:aws:appsync:us-east-1:123456789012:apis/mock-api"
      uris             = {
        GRAPHQL = "https://mock-api-id.appsync-api.us-east-1.amazonaws.com/graphql"
        REALTIME = "wss://mock-api-id.appsync-realtime-api.us-east-1.amazonaws.com/graphql"
      }
    }
  }

  mock_resource "aws_cognito_user_pool" {
    defaults = {
      arn = "arn:aws:cognito-idp:us-east-1:123456789012:userpool/mock-userpool"
      id  = "us-east-1_mockuserpool"
    }
  }

  mock_resource "aws_dynamodb_table" {
    defaults = {
      arn = "arn:aws:dynamodb:us-east-1:123456789012:table/mock-table"
    }
  }

  mock_resource "aws_lambda_function" {
    defaults = {
      arn = "arn:aws:lambda:us-east-1:123456789012:function/mock-function"
    }
  }
}

# Test 1: Basic AppSync API creation
run "basic_appsync_api" {
  command = plan

  variables {
    name = "test-api"
    schema = jsonencode({
      data = {
        hello = "world"
      }
    })
  }

  assert {
    condition     = length(aws_appsync_graphql_api.this) == 1
    error_message = "Should create one AppSync GraphQL API"
  }

  assert {
    condition     = length(aws_appsync_datasource.none) == 1
    error_message = "Should create None data source for subscriptions"
  }

  assert {
    condition     = length(aws_cloudwatch_log_group.this) == 1
    error_message = "Should create CloudWatch log group for logging"
  }
}

# Test 2: Cognito authentication
run "cognito_authentication" {
  command = plan

  variables {
    name = "test-api"
    schema = jsonencode({
      data = {
        hello = "world"
      }
    })
    cognito_user_pool_arn = "arn:aws:cognito-idp:us-east-1:123456789012:userpool/us-east-1_testuserpool"
  }

  assert {
    condition     = length(aws_appsync_graphql_api.this) == 1
    error_message = "Should create AppSync API with Cognito auth"
  }

  # Should have additional authentication configuration
  assert {
    condition     = aws_appsync_graphql_api.this[0].authentication_type == "AMAZON_COGNITO_USER_POOLS"
    error_message = "Should use Cognito user pools authentication"
  }
}

# Test 3: Invalid Cognito ARN validation
run "invalid_cognito_arn" {
  command = plan

  variables {
    name = "test-api"
    schema = jsonencode({
      data = {
        hello = "world"
      }
    })
    cognito_user_pool_arn = "invalid-arn-format"  # Should fail validation
  }

  expect_failures = [
    var.cognito_user_pool_arn
  ]
}

# Test 4: Multiple authentication modes
run "multiple_authentication" {
  command = plan

  variables {
    name = "test-api"
    schema = jsonencode({
      data = {
        hello = "world"
      }
    })
    cognito_user_pool_arn = "arn:aws:cognito-idp:us-east-1:123456789012:userpool/us-east-1_testuserpool"
    enable_api_key = true
    additional_authentication_provider = [
      {
        authentication_type = "AWS_IAM"
      }
    ]
  }

  assert {
    condition     = length(aws_appsync_api_key.this) == 1
    error_message = "Should create API key when enabled"
  }

  # Should have multiple auth providers
  assert {
    condition     = length(aws_appsync_graphql_api.this[0].additional_authentication_provider) == 1
    error_message = "Should have additional authentication providers"
  }
}

# Test 5: DynamoDB data sources
run "dynamodb_data_sources" {
  command = plan

  variables {
    name = "test-api"
    schema = jsonencode({
      data = {
        hello = "world"
      }
    })
    dynamodb_data_sources = {
      users = {
        table_name = "users-table"
      }
      posts = {
        table_name = "posts-table"
      }
    }
  }

  assert {
    condition     = length(aws_appsync_datasource.dynamodb) == 2
    error_message = "Should create two DynamoDB data sources"
  }

  assert {
    condition     = length(aws_iam_role.dynamodb) == 2
    error_message = "Should create two IAM roles for DynamoDB data sources"
  }
}

# Test 6: Lambda data sources
run "lambda_data_sources" {
  command = plan

  variables {
    name = "test-api"
    schema = jsonencode({
      data = {
        hello = "world"
      }
    })
    lambda_data_sources = {
      processor = {
        function_arn = "arn:aws:lambda:us-east-1:123456789012:function/processor"
      }
    }
  }

  assert {
    condition     = length(aws_appsync_datasource.lambda) == 1
    error_message = "Should create one Lambda data source"
  }

  assert {
    condition     = length(aws_lambda_permission.appsync) == 1
    error_message = "Should create Lambda permission for AppSync"
  }
}

# Test 7: X-Ray tracing
run "xray_tracing" {
  command = plan

  variables {
    name = "test-api"
    schema = jsonencode({
      data = {
        hello = "world"
      }
    })
    xray_enabled = true
  }

  assert {
    condition     = aws_appsync_graphql_api.this[0].xray_enabled == true
    error_message = "Should enable X-Ray tracing"
  }
}