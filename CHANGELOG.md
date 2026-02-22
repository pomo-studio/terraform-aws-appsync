# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.3] - 2026-02-22

### Changed
- Created `versions.tf` with explicit Terraform and AWS provider version constraints
- Added full `## Inputs` and `## Outputs` reference tables to README
- Added value-prop bullets and Registry badge to README
- Renamed `## Opinionated defaults` to `## Design decisions`
- Added `## Examples` and `## License` sections to README

## [1.0.2] - 2026-02-21

### Fixed
- **Critical Security Fix**: Replaced fragile ARN parsing with robust validation
  - Changed from: `element(split("/", element(split(":", arn), length(split(":", arn)) - 1)), 1)`
  - Changed to: `can(regex("^arn:aws:cognito-idp:[a-z0-9-]+:[0-9]+:userpool/[a-zA-Z0-9_-]+$", arn)) ? element(split("/", arn), 1) : null`
  - Added `validation` block in `variables.tf` to ensure Cognito User Pool ARN matches expected pattern
  - Provides clear error message at plan-time instead of runtime failure

### Security Impact
The previous implementation used nested `split()` operations that would fail silently with malformed ARNs, potentially allowing invalid configurations to pass validation. The new implementation:
1. Validates ARN format at plan-time with clear error messages
2. Uses `can()` function to safely test regex match before extraction
3. Extracts user pool ID only from properly formatted ARNs

### Technical Details
- **File**: `main.tf` lines 20-21, 35-36
- **File**: `variables.tf` lines 11-22
- **Pattern**: `^arn:aws:cognito-idp:[a-z0-9-]+:[0-9]+:userpool/[a-zA-Z0-9_-]+$`
- **Extraction**: `element(split("/", arn), 1)` after validation

### Recommended Action
All users should upgrade to v1.0.2 to benefit from the improved ARN validation. No breaking changes to inputs or outputs.

## [1.0.1] - 2026-02-21

### Added
- Support for multiple authentication modes (Cognito, AWS_IAM, API_KEY, OIDC, Lambda)
- DynamoDB data sources with per-table least-privilege IAM roles
- Lambda data sources with IAM invoke permissions
- CloudWatch logging enabled by default
- X-Ray tracing enabled by default

### Fixed
- Improved error handling for schema compilation
- Fixed IAM role permissions for CloudWatch logging

## [1.0.0] - 2026-02-21

### Added
- Initial release of AppSync module
- `aws_appsync_graphql_api` with configurable schema
- `NoneDataSource` for subscription support
- Cognito User Pool authentication
- API key resource (optional)
- Comprehensive input validation
- Basic and Complete examples

### Features
- **Production-ready**: Least-privilege IAM, logging, tracing
- **Flexible auth**: Multiple authentication modes
- **Developer-friendly**: Validation prevents common mistakes
- **Modular design**: Data sources as separate resources

[1.0.2]: https://github.com/pomo-studio/terraform-aws-appsync/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/pomo-studio/terraform-aws-appsync/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/pomo-studio/terraform-aws-appsync/releases/tag/v1.0.0