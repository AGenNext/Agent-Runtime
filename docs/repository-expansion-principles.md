# Repository expansion principles

AGenNext repositories should expand by architectural responsibility, not by convenience.

## Core rule

If a capability clearly belongs to an existing architectural layer, keep it in that layer's repository.

If a capability does not fit cleanly into any existing layer, create a new repository with a clear boundary.

## Examples

### Keep inside an existing repo

`k8smicro` belongs inside `AGenNext/Agent-Runtime` because it is a runtime profile.

```txt
AGenNext/Agent-Runtime
  └── profiles/k8smicro
```

### Create a new repo

`AgentKube` deserved its own repository because Kubernetes operations are a distinct layer, not just a runtime profile.

```txt
AGenNext/AgentKube
```

## Layer ownership

| Layer | Repository |
|---|---|
| Runtime engine and runtime profiles | `AGenNext/Agent-Runtime` |
| Graph contracts and workflow model | `AGenNext/Agent-Graph` |
| Kubernetes operations | `AGenNext/AgentKube` |
| Identity, DID, VC, approvals | `AGenNext/Agent-Identity` |
| Auth/session/API authorization | `AGenNext/Agent-Auth` |
| Cloud-provider agents | `unboxd-cloud/cloud-architect-agents` |

## Decision checklist

Before creating a new repository, ask:

1. Is this a reusable architectural layer?
2. Does it have independent ownership and release lifecycle?
3. Would multiple runtimes or products depend on it?
4. Would putting it inside an existing repo blur that repo's responsibility?
5. Can the repo be described in one sentence without referencing implementation detail?

If the answer is yes, create a new repository.

If not, keep it as a module/profile/package inside the correct existing repository.

## Principle

Repositories are product and architecture boundaries.

Folders are implementation boundaries.
