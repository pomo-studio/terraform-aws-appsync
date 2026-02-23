.PHONY: test fmt validate smoke-failover

## Run all unit tests
test:
	terraform test

## Check Terraform formatting
fmt:
	terraform fmt -check -recursive

## Validate all examples
validate:
	cd examples/basic && terraform init -backend=false -upgrade && terraform validate
	cd examples/dr-parity && terraform init -backend=false -upgrade && terraform validate

## Run failover smoke check against deployed APIs (requires env vars)
smoke-failover:
	bash scripts/smoke-failover.sh
