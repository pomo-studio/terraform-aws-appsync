# Basic AppSync API

Shows a single-region AppSync GraphQL API with Cognito auth, an API key, and a DynamoDB data source.

## What it creates

- A Cognito user pool for the primary auth mode.
- A DynamoDB table used as an `items` data source.
- The AppSync module with a schema, AWS_IAM and API_KEY added auth modes, and an API key.
- Sample resolvers for `getUser` and the `onTickerUpdate` subscription.

## Before you start

- AWS provider v5 or later. This example uses Terraform Cloud (org `Pitangaville`, workspace `appsync-example`).
- Region is `us-east-2` primary and `us-west-2` DR.
- Uses the local module source `../../`.

## Run it

```bash
terraform init
terraform plan
terraform apply
```

## Clean up

```bash
terraform destroy
```
