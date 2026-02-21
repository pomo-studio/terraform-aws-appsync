.PHONY: test fmt validate

## Run all unit tests
test:
	terraform test

## Check Terraform formatting
fmt:
	terraform fmt -check -recursive

## Validate all examples
validate:
	cd examples/basic && terraform init -backend=false -upgrade && terraform validate
	cd examples/complete && terraform init -backend=false -upgrade && terraform validate