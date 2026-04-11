# OTel JS Semantic Conventions Gotchas

Verified against `@opentelemetry/semantic-conventions` v1.40.0 on 2026-04-11.

## Two entry-points — stable and incubating are separate

```typescript
// Stable — semver-safe, use in published libraries
import { ATTR_HTTP_REQUEST_METHOD } from '@opentelemetry/semantic-conventions';

// Incubating — breaking changes allowed in minor releases
import { ATTR_RPC_METHOD } from '@opentelemetry/semantic-conventions/incubating';
```

Never mix stable and incubating constants in a single import statement. Importing stable constants from `/incubating` works (it re-exports them) but is incorrect style.

## DB attributes were renamed — training data has the old names

Old (incubating + deprecated) → New (stable):
- `db.system` → **`db.system.name`** (constant: `ATTR_DB_SYSTEM_NAME`)
- `db.statement` → **`db.query.text`** (constant: `ATTR_DB_QUERY_TEXT`)

LLMs trained before 2025 almost always suggest the deprecated names. Prompts must explicitly forbid `db.system` and `db.statement`.

## HTTP URL is `url.full`, not `http.url`

- `http.url` (`ATTR_HTTP_URL`) — incubating + deprecated
- `http.target` (`ATTR_HTTP_TARGET`) — incubating + deprecated
- Replacements: `url.full` (`ATTR_URL_FULL`), `url.path` (`ATTR_URL_PATH`), `url.query` (`ATTR_URL_QUERY`) — all **stable**

## `SEMATTRS_*` still compiles but is wrong

`SEMATTRS_HTTP_METHOD`, `SEMATTRS_HTTP_STATUS_CODE` etc. still export and compile but carry `@deprecated`. They also use OLD attribute strings (`http.method` not `http.request.method`). Do not use.

## RPC and messaging are fully incubating — no stable equivalents

All `ATTR_RPC_*` and `ATTR_MESSAGING_*` constants live in `/incubating`. No stable versions exist yet.

## Incubating really does break on minor bumps

CHANGELOG v1.33.1: `DB_SYSTEM_NAME_VALUE_*` exports were moved back to incubating. This is confirmed evidence that "no semver guarantee" means what it says.

## Stable attributes that are commonly needed

HTTP: `ATTR_HTTP_REQUEST_METHOD`, `ATTR_HTTP_RESPONSE_STATUS_CODE`, `ATTR_URL_FULL`, `ATTR_HTTP_ROUTE`  
DB: `ATTR_DB_SYSTEM_NAME`, `ATTR_DB_QUERY_TEXT`  
Service: `ATTR_SERVICE_NAME`, `ATTR_SERVICE_VERSION`  
Enum values: `HTTP_REQUEST_METHOD_VALUE_GET` etc., `DB_SYSTEM_NAME_VALUE_MYSQL` etc.
