# AppSync HA Failover Strategy (Level 3)

This document defines operational HA behavior for consumers of `pomo-studio/appsync/aws`.

## Scope

Module responsibilities:
- provision primary + DR AppSync APIs (`enable_dr = true`)
- expose endpoints and datasource names for both regions

Consumer responsibilities:
- create resolver parity in both APIs
- choose endpoint failover policy in clients
- run failover/recovery drills

## Endpoint Strategy

### Browser/WebSocket clients

1. default to primary `api_url` / `realtime_url`
2. on endpoint-unreachable or auth/5xx burst threshold, reconnect to DR endpoints
3. keep a short cool-down before probing primary for failback

### Server callers (Lambda/SSR)

1. default to primary endpoint
2. on retriable failures (network, 429, 5xx), retry against DR endpoint
3. keep idempotency key semantics in caller for mutations

## Failover Triggers (Recommended)

- 3 consecutive connection failures to primary within 60s
- or 5xx rate > 20% for 2 minutes
- or explicit operator override during incident response

## Recovery (Failback)

1. Verify primary health via smoke query/mutation.
2. Drain new writes from DR path only after smoke is stable.
3. Switch read/subscription clients back to primary.
4. Record incident and run duration.

## Verification Checklist

- [ ] parity resolvers exist in primary and DR APIs
- [ ] smoke query succeeds on both endpoints
- [ ] smoke mutation succeeds on both endpoints
- [ ] subscription connect succeeds on both realtime endpoints
- [ ] runbook executed at least once in non-prod

## Runbook Hooks

- Use `scripts/smoke-failover.sh` for endpoint health and failover readiness checks.
- Store latest smoke output with incident notes.

## Troubleshooting Matrix

Use this table during failover drills and incidents to reduce diagnosis time.

| Symptom | Likely cause | Fix |
|---|---|---|
| `dr_api_id` is null | `enable_dr` disabled or missing `aws.dr` provider mapping in module call | Set `enable_dr = true` and pass both providers: `aws` and `aws.dr` |
| DR endpoint returns `Unauthorized` for query/mutation | Schema auth directives do not allow the caller auth mode, or DR resolver not attached | Align auth directives for operation/type and create matching DR resolver resources |
| Primary query works but DR query returns empty items | No data replication to DR backing store, or DR resolver points to wrong data source | Verify DR data path (replication/replay) and confirm `dr_data_source_names` key mapping |
| Smoke script fails only on DR | DR API key missing/expired, wrong DR URL/key, or resolver/data source parity incomplete | Recheck `dr_api_url`, `dr_api_key_id`/`dr_api_key`, and resolver parity in DR |
| Terraform warning about `aws.dr` undefined provider in child module | Child module does not declare alias name in `required_providers` | Non-blocking in current module usage; keep explicit provider mapping in caller and optionally declare alias in child module when you control it |
| Resolver exists in primary but not DR | Caller created only primary resolver resources | Mirror resolver resources in DR (`provider = aws.dr`, `api_id = module.appsync.dr_api_id`) |
| Mutation appears successful but no DR records are visible | Deployed Lambda/runtime artifact is stale or DR mutation path not executed | Rebuild and redeploy runtime artifact, then re-run business-query drill and compare transaction IDs across regions |
