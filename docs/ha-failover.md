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
