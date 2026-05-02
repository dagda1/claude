---
name: cdk-stateful-resources
description: Safe handling of stateful AWS resources in CDK — explicit removal policies, deletion protection, backup retention, snapshot-on-delete. Use when writing or reviewing CDK that creates databases, buckets, tables, or any resource holding data.
---

# CDK stateful resources — safe by default

A stateless resource (Lambda, security group) can be destroyed and recreated. A stateful one (RDS, S3, DynamoDB, EFS) loses **data** on destroy. The defaults are not safe.

## Always set an explicit `removalPolicy`

Don't rely on the CDK default — it varies by resource type and changes between versions.

```ts
new rds.DatabaseInstance(this, 'Postgres', {
  // ...
  removalPolicy: RemovalPolicy.RETAIN,        // production
  // RemovalPolicy.SNAPSHOT,                  // staging — final snapshot
  // RemovalPolicy.DESTROY,                   // dev only
  deletionProtection: true,
});
```

Rule of thumb:
- **Prod data:** `RETAIN`. Resource is orphaned in AWS if the stack is deleted — you can recover.
- **Staging data:** `SNAPSHOT` (where supported — RDS, EFS).
- **Dev / ephemeral:** `DESTROY`. Be sure.

## Enable deletion protection where the API supports it

- RDS: `deletionProtection: true`
- DynamoDB: `deletionProtection: true`
- S3: `versioned: true` + a bucket policy denying `s3:DeleteBucket`
- EFS: enable lifecycle policies and backups

This protects against accidental `cdk destroy` even if the removal policy is wrong.

## Backup configuration

Stateful resources without backups are stateful resources you're prepared to lose.

- RDS: `backupRetention: Duration.days(7)` minimum for prod
- DynamoDB: `pointInTimeRecovery: true`
- S3: cross-region replication for critical buckets, lifecycle for cost
- EFS: AWS Backup integration

## Snapshots before destructive changes

Schema migrations, instance type changes, engine upgrades — all can fail mid-flight. Take a manual snapshot first if the change isn't atomic.

```ts
// In RDS, this happens automatically with SNAPSHOT removal policy on destroy.
// For in-place changes, take a snapshot manually before deploy.
```

## What to flag in review

- Any stateful resource (RDS, DynamoDB, S3, EFS, Aurora, Neptune, DocumentDB) without an explicit `removalPolicy`.
- `RemovalPolicy.DESTROY` in a prod stack.
- `deletionProtection: false` (or unset) on RDS / DynamoDB in any non-dev environment.
- S3 buckets without `versioned: true` for anything holding business data.
- RDS / Aurora without `backupRetention` configured.
- DynamoDB without `pointInTimeRecovery` for tables holding business data.
- A construct that recreates a stateful resource on minor prop changes (check the L1 properties that trigger replacement — engine version, instance class for some DBs, AZ changes).
