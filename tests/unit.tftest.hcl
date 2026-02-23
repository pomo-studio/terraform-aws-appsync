mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      name = "us-east-1"
    }
  }

  mock_resource "aws_appsync_graphql_api" {
    defaults = {
      id  = "mock-api-id"
      arn = "arn:aws:appsync:us-east-1:123456789012:apis/mock-api-id"
      uris = {
        GRAPHQL  = "https://mock-api-id.appsync-api.us-east-1.amazonaws.com/graphql"
        REALTIME = "wss://mock-api-id.appsync-realtime-api.us-east-1.amazonaws.com/graphql"
      }
    }
  }

  mock_resource "aws_appsync_datasource" {
    defaults = {
      name = "MockDataSource"
    }
  }

  mock_resource "aws_cloudwatch_log_group" {
    defaults = {
      name = "/aws/appsync/apis/mock-api-id"
      arn  = "arn:aws:logs:us-east-1:123456789012:log-group:/aws/appsync/apis/mock-api-id"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      id  = "mock-role-id"
      arn = "arn:aws:iam::123456789012:role/mock-role"
    }
  }

  mock_resource "aws_appsync_api_key" {
    defaults = {
      id  = "mock-key-id"
      key = "mock-key"
    }
  }
}

run "basic_appsync_api" {
  command = plan

  variables {
    name   = "test-api"
    schema = "type Query { ping: String }"
  }

  assert {
    condition     = aws_appsync_graphql_api.this.name == "test-api"
    error_message = "Should create one AppSync GraphQL API with requested name"
  }

  assert {
    condition     = aws_appsync_datasource.none.name == "NoneDataSource"
    error_message = "Should create None data source for subscriptions"
  }

  assert {
    condition     = aws_appsync_graphql_api.this.authentication_type == "AWS_IAM"
    error_message = "Default primary auth should be AWS_IAM when Cognito ARN is not set"
  }
}

run "cognito_authentication" {
  command = plan

  variables {
    name                  = "test-api"
    schema                = "type Query { ping: String }"
    cognito_user_pool_arn = "arn:aws:cognito-idp:us-east-1:123456789012:userpool/us-east-1_testuserpool"
  }

  assert {
    condition     = aws_appsync_graphql_api.this.authentication_type == "AMAZON_COGNITO_USER_POOLS"
    error_message = "Should use Cognito auth when cognito_user_pool_arn is set"
  }
}

run "invalid_cognito_arn" {
  command = plan

  variables {
    name                  = "test-api"
    schema                = "type Query { ping: String }"
    cognito_user_pool_arn = "invalid-arn-format"
  }

  expect_failures = [var.cognito_user_pool_arn]
}

run "dynamodb_data_source" {
  command = plan

  variables {
    name   = "test-api"
    schema = "type Query { ping: String }"
    dynamodb_data_sources = {
      transactions = {
        table_name = "tx-table"
        table_arn  = "arn:aws:dynamodb:us-east-1:123456789012:table/tx-table"
      }
    }
  }

  assert {
    condition     = aws_appsync_datasource.dynamodb["transactions"].type == "AMAZON_DYNAMODB"
    error_message = "Should create DynamoDB data source"
  }
}
