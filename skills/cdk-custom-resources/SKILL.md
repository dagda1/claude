---
name: cdk-custom-resources
description: AWS CDK CustomResource patterns — Version property to force re-runs on behavior change, idempotent handlers, proper Create/Update/Delete handling. Use when writing or reviewing CDK CustomResource constructs.
---

# CDK CustomResource patterns

CustomResources let CDK run arbitrary Lambda code during stack lifecycle events. They have one critical gotcha and several easy mistakes.

## Bump a `Version` property when handler behavior changes

CloudFormation only re-runs a CustomResource on **Update** if its `properties` change. If the Lambda handler code changes but the properties don't, the new code is deployed but **never invoked**. This is the #1 source of "I changed the handler but it didn't run" bugs.

```ts
new CustomResource(this, 'Resource', {
  serviceToken: provider.serviceToken,
  properties: {
    Version: '3',  // <-- bump when handler behavior changes
    // other props that genuinely vary
  },
});
```

```python
CustomResource(self, "Resource",
    service_token=provider.service_token,
    properties={
        "Version": "3",  # bump when handler behavior changes
    },
)
```

Treat `Version` as a manual version pin. Bump it whenever the Lambda's effect on AWS state changes. Comment in the PR description what changed.

## Handlers must be idempotent

A CustomResource may receive the same event multiple times (CloudFormation retries on transient failures). Your handler must produce the same end state regardless.

```python
# BAD — fails on second run because the user already exists
cursor.execute("CREATE USER foo;")

# GOOD — idempotent
cursor.execute("DO $$ BEGIN ... IF NOT EXISTS (...) THEN CREATE USER foo; END IF; END $$;")
```

Same applies to file uploads, secret rotation, role grants — design for "may be called twice".

## Handle all three lifecycle events

The handler receives `RequestType: Create | Update | Delete`. At minimum:

- **Create:** do the work.
- **Update:** do the work (treat as another Create — your handler is idempotent, right?).
- **Delete:** clean up if cleanup is required, otherwise return success. **Returning failure on Delete will block stack deletion forever.**

```python
def handler(event, context):
    if event.get("RequestType") == "Delete":
        return {"PhysicalResourceId": event["PhysicalResourceId"]}
    # ... do the work
    return {"PhysicalResourceId": "stable-id"}
```

## Stable `PhysicalResourceId`

The `PhysicalResourceId` you return identifies the resource in CloudFormation. **If it changes between Create and Update, CloudFormation interprets that as "old resource deleted, new one created" and calls Delete on the old one.**

For most cases, return a stable string (`"bootstrap"`, `"migration"`) — not something derived from a value that might change.

## Errors during the handler

- Surface the error message clearly — it shows up in the CloudFormation console.
- For Postgres / SQL handlers, include the failing statement and arguments in the error.
- Don't swallow exceptions to "make the stack succeed" — a half-applied bootstrap is worse than a failed deploy.

## What to flag in review

- CustomResource without a `Version` property (or never bumped despite handler changes).
- Handler missing the `RequestType == "Delete"` early-return.
- Handler that returns a different `PhysicalResourceId` between Create and Update.
- Non-idempotent operations (`CREATE USER`, `INSERT INTO ... VALUES`, `mkdir`) without existence checks.
- Bare `except: pass` or generic `try/except` that hides failures.
- Custom resources doing slow work without a corresponding Lambda timeout bump.
- Custom resources not in a VPC when they need to reach VPC-only resources (RDS, ElastiCache).
