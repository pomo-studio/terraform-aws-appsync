# DR Parity AppSync API

Shows an AppSync API with a paired DR deployment in a second region.

## What it creates

- A Cognito user pool and two DynamoDB tables, one per region.
- A primary AppSync API plus a DR API with `enable_dr = true`.
- Matching DynamoDB, Lambda, and HTTP data sources in both regions.
- Outputs for both API URLs and both data source name maps.

## Before you start

- AWS provider v5 or later. Region is `us-east-1` primary and `us-west-2` DR.
- The Lambda functions referenced by ARN must already exist, or plan will still run but apply targets them.
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
