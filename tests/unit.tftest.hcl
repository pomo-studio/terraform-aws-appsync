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

mock_provider "aws" {
  alias = "dr"

  mock_data "aws_region" {
    defaults = {
      name = "us-west-2"
    }
  }

  mock_resource "aws_appsync_graphql_api" {
    defaults = {
      id  = "mock-dr-api-id"
      arn = "arn:aws:appsync:us-west-2:123456789012:apis/mock-dr-api-id"
      uris = {
        GRAPHQL  = "https://mock-dr-api-id.appsync-api.us-west-2.amazonaws.com/graphql"
        REALTIME = "wss://mock-dr-api-id.appsync-realtime-api.us-west-2.amazonaws.com/graphql"
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
      name = "/aws/appsync/apis/mock-dr-api-id"
      arn  = "arn:aws:logs:us-west-2:123456789012:log-group:/aws/appsync/apis/mock-dr-api-id"
    }
  }

  mock_resource "aws_iam_role" {
    defaults = {
      id  = "mock-dr-role-id"
      arn = "arn:aws:iam::123456789012:role/mock-dr-role"
    }
  }

  mock_resource "aws_appsync_api_key" {
    defaults = {
      id  = "mock-dr-key-id"
      key = "mock-dr-key"
    }
  }
}

run "basic_appsync_api" {
  command = plan
  providers = {
    aws    = aws
    aws.dr = aws.dr
  }

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
  providers = {
    aws    = aws
    aws.dr = aws.dr
  }

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
  providers = {
    aws    = aws
    aws.dr = aws.dr
  }

  variables {
    name                  = "test-api"
    schema                = "type Query { ping: String }"
    cognito_user_pool_arn = "invalid-arn-format"
  }

  expect_failures = [var.cognito_user_pool_arn]
}

run "dynamodb_data_source" {
  command = plan
  providers = {
    aws    = aws
    aws.dr = aws.dr
  }

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

run "dr_api_enabled" {
  command = plan
  providers = {
    aws    = aws
    aws.dr = aws.dr
  }

  variables {
    name      = "test-api"
    schema    = "type Query { ping: String }"
    enable_dr = true
  }

  assert {
    condition     = aws_appsync_graphql_api.dr[0].name == "test-api-dr"
    error_message = "Should create DR AppSync API with '-dr' suffix when enable_dr is true"
  }

  assert {
    condition     = aws_appsync_datasource.none_dr[0].name == "NoneDataSource"
    error_message = "Should create DR None data source when enable_dr is true"
  }

}

run "dr_parity_data_sources" {
  command = plan
  providers = {
    aws    = aws
    aws.dr = aws.dr
  }

  variables {
    name      = "test-api"
    schema    = "type Query { ping: String }"
    enable_dr = true

    dr_dynamodb_data_sources = {
      transactions = {
        table_name = "tx-table-dr"
        table_arn  = "arn:aws:dynamodb:us-west-2:123456789012:table/tx-table-dr"
      }
    }

    dr_lambda_data_sources = {
      enricher = {
        function_arn = "arn:aws:lambda:us-west-2:123456789012:function:enricher"
      }
    }

    dr_http_data_sources = {
      upstream = {
        endpoint = "https://example.com"
      }
    }
  }

  assert {
    condition     = aws_appsync_datasource.dynamodb_dr["transactions"].type == "AMAZON_DYNAMODB"
    error_message = "Should create DR DynamoDB data source when dr_dynamodb_data_sources is provided"
  }

  assert {
    condition     = aws_appsync_datasource.lambda_dr["enricher"].type == "AWS_LAMBDA"
    error_message = "Should create DR Lambda data source when dr_lambda_data_sources is provided"
  }

  assert {
    condition     = aws_appsync_datasource.http_dr["upstream"].type == "HTTP"
    error_message = "Should create DR HTTP data source when dr_http_data_sources is provided"
  }
}
