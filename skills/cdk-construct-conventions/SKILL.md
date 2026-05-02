---
name: cdk-construct-conventions
description: AWS CDK construct conventions — explicit typed props, deterministic construct IDs, consistent tagging, one construct per concern. Use when writing or reviewing CDK code (TypeScript or Python).
---

# CDK construct conventions

## Explicit, typed props interfaces

Every reusable construct has an explicit props interface. No `any`, no implicit `kwargs`, no hidden defaults.

```ts
// TypeScript
export interface DatabaseProps {
  readonly vpc: ec2.IVpc;
  readonly instanceType: ec2.InstanceType;
  readonly removalPolicy: RemovalPolicy;
}

export class Database extends Construct {
  constructor(scope: Construct, id: string, props: DatabaseProps) { ... }
}
```

```python
# Python
class Database(Construct):
    def __init__(
        self,
        scope: Construct,
        construct_id: str,
        *,
        vpc: ec2.IVpc,
        instance_type: ec2.InstanceType,
        removal_policy: RemovalPolicy,
    ) -> None:
        ...
```

Required vs optional must be visible at the call site. Never accept untyped `**kwargs` or `Record<string, unknown>`.

## Deterministic construct IDs

Logical IDs derive from construct paths. If you rename or restructure, CloudFormation sees a different resource and **destroys the old one**. For stateful resources this is catastrophic.

- Pick construct IDs deliberately and don't rename them lightly.
- For arrays of similar resources, use stable keys (item ID, name) — never array indexes.
- If you must rename, use `node.tryRemoveChild` + explicit logical ID overrides to preserve the original.

```ts
// BAD — index changes if the list reorders, destroys/recreates
buckets.forEach((name, i) => new s3.Bucket(this, `Bucket${i}`, { bucketName: name }));

// GOOD — name is stable
buckets.forEach((name) => new s3.Bucket(this, `Bucket${pascalCase(name)}`, { bucketName: name }));
```

## One construct per concern

Don't bundle unrelated resources into a single mega-construct. A `Database` construct creates the DB, security group, and secret — fine. A `Database` construct that also creates the API Gateway and Lambda — wrong.

If you find yourself passing 8+ props, the construct is doing too much. Split it.

## Tagging

- Use a single shared tagging pattern (`Tags.of(stack).add(...)` at the stack root, or a helper).
- Don't sprinkle `Tags.of(resource).add(...)` calls across constructs — drift risk.
- Common tags: `Project`, `Environment`, `Owner`, `CostCenter`.

## File organisation

- One construct per file (or one tightly-coupled construct group per file).
- File name matches the construct name.
- Constructs go under `lib/constructs/` (TS) or `<package>/<stack>/` (Python).
- Stack composition lives in stack files, not in constructs.

## What to flag in review

- Untyped props (`any`, `Record<string, unknown>`, `**kwargs`).
- Construct IDs that depend on array indexes instead of stable keys.
- Renamed construct IDs without logical-ID overrides (silent destroy/recreate of stateful resources).
- A single construct creating resources from 3+ different AWS services with no clear cohesion.
- Tags applied per-resource instead of at the stack root.
- Stacks importing from each other via concrete classes instead of interfaces.
