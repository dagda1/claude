---
name: cdk-iam-least-privilege
description: AWS IAM least-privilege patterns in CDK — no wildcard actions/resources without justification, scoped resource ARNs, conditions on trust policies, prefer grant() helpers over inline policies. Use when writing or reviewing CDK IAM code.
---

# CDK IAM — least privilege

The default for every policy is **deny**. Every grant must justify what it allows and to what.

## Prefer `grant*()` helpers over inline policies

CDK ships `grant*()` methods on most L2 constructs. They give the minimum required actions on the specific resource — use them.

```ts
// BAD — too broad, easy to drift
fn.addToRolePolicy(new PolicyStatement({
  actions: ['s3:*'],
  resources: ['*'],
}));

// GOOD — narrowly scoped, refactor-safe
bucket.grantReadWrite(fn);
```

```python
# BAD
fn.add_to_role_policy(iam.PolicyStatement(
    actions=["s3:*"],
    resources=["*"],
))

# GOOD
bucket.grant_read_write(fn)
```

If a `grant*()` doesn't exist for what you need, write a tight inline policy — never reach for `*`.

## No wildcard actions without justification

`actions: ['s3:*']`, `dynamodb:*`, `lambda:*` are almost never the right answer. Even for "internal" tools.

If you genuinely need a wildcard (e.g. `kms:*` for key administration, `logs:*` for an observability sidecar), put a comment explaining *why* — but the comment is a code smell, not a license.

## No wildcard resources

`resources: ['*']` defeats the entire point of resource-level policies. Scope to the specific ARN.

```ts
// BAD
resources: ['*']

// GOOD
resources: [bucket.arnForObjects('uploads/*')]
resources: [`${table.tableArn}/index/*`]
```

Some actions genuinely require `*` (`logs:CreateLogGroup`, some `iam:Pass*` patterns) — those are the exceptions, document them.

## Trust policies need conditions

A role assumable by `sts:AssumeRole` from `*` is a backdoor. Every cross-account / federated trust must have conditions:

- `aws:PrincipalArn` for specific principals.
- `aws:SourceAccount` to prevent confused-deputy.
- `token.actions.githubusercontent.com:sub` for GitHub OIDC (scope to repo + branch).
- `aws:SourceArn` for service principals when supported.

```ts
// BAD — anyone in any GitHub repo can assume this role
new iam.Role(this, 'CIRole', {
  assumedBy: new iam.WebIdentityPrincipal(githubOidcProvider.openIdConnectProviderArn),
});

// GOOD — scoped to a specific repo
new iam.Role(this, 'CIRole', {
  assumedBy: new iam.WebIdentityPrincipal(githubOidcProvider.openIdConnectProviderArn, {
    StringLike: {
      'token.actions.githubusercontent.com:sub': 'repo:my-org/my-repo:ref:refs/heads/main',
    },
  }),
});
```

## No hardcoded ARNs / account IDs

Use `Arn.format`, `Stack.of(this).account`, `Stack.of(this).region`, or props passed into the construct. Hardcoded `arn:aws:...:123456789012:...` strings break across environments.

## What to flag in review

- `actions: ['*']` or any `service:*` wildcard
- `resources: ['*']` (unless action genuinely requires it — e.g. `logs:CreateLogGroup`)
- Inline `PolicyStatement` where a `grant*()` helper exists
- Trust policies without conditions (especially OIDC, cross-account)
- Hardcoded account IDs / ARNs
- `iam:PassRole` without a scoped resource
- `*:*` permissions in any form
- Roles attached to multiple unrelated services (a Lambda execution role used by an EC2 instance, etc.)
