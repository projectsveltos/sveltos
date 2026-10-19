---
title: Sveltos Health Monitoring
description: Learn how Sveltos keeps watching the resources a ClusterProfile or Profile deployed and reports the ones that are not healthy, in every cluster, with sveltosctl, the dashboard and the MCP server.
tags:
    - Kubernetes
    - Sveltos
    - add-ons
    - helm
    - clusterapi
    - health monitoring
authors:
    - Gianluca Mardente
---

## Health Monitoring

Deploying a resource and having it stay healthy are two different things. A Deployment can be rolled out successfully and fail an hour later because of a bad image, an exhausted quota or a node that went away.

With *healthMonitoring* enabled in a ClusterProfile or Profile, Sveltos keeps watching the resources that profile deployed in each matching cluster, and reports the ones that are not healthy. Raw YAML resources and Helm charts are both covered. Sveltos does not need to know what the chart contains: it looks at what was deployed.

```yaml
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: nginx-ingress
spec:
  clusterSelector:
    matchLabels:
      env: prod
  helmCharts:
  - repositoryURL:    https://kubernetes.github.io/ingress-nginx
    repositoryName:   ingress-nginx
    chartName:        ingress-nginx/ingress-nginx
    chartVersion:     4.12.0
    releaseName:      ingress-nginx
    releaseNamespace: ingress-nginx
    helmChartAction:  Install
  healthMonitoring:
    enabled: true
```

That is all it takes. Sveltos starts monitoring a profile in a cluster once the profile is provisioned there, and stops when monitoring is disabled, the profile is deleted or the cluster does not match anymore.

!!! note
    Health monitoring does not change how a profile is deployed. It only reports. To make a profile wait until the resources are ready, and to make profiles that depend on it wait too, use [validateHealths](../deployment_order/depends_on_with_health_checks.md).

## What Is Monitored

By default, Sveltos monitors the following kinds, when they were deployed by the profile:

| Kind | Healthy when |
|---|---|
| Deployment | The rollout completed and all the replicas are available |
| StatefulSet | All the replicas are ready and the rolling update finished |
| DaemonSet | The rollout completed and all the scheduled pods are ready |
| Job | The Job completed. A failed Job is Degraded, a running Job is Progressing |
| PersistentVolumeClaim | The claim is bound. A lost claim is Degraded |

A resource is reported with one of these statuses:

| Status | Meaning |
|---|---|
| `Degraded` | The resource failed, for instance a Deployment that exceeded its progress deadline or a Job that failed |
| `Progressing` | The resource is not healthy yet but is moving toward it, for instance a rollout in progress |
| `Suspended` | The resource is paused on purpose, for instance a paused Deployment or a suspended Job |

Only the resources that are not healthy are reported. A resource that is healthy is not listed.

Resources that exist in the same namespaces but were not deployed by the profile are ignored. A Deployment someone created by hand next to the chart is not the profile's business.

### Limitations

- Pods and ReplicaSets are not monitored directly. A Deployment with a failing Pod is reported through the Deployment.
- Only a Job deployed directly is covered. A Job created by a CronJob is not.
- A PersistentVolumeClaim created by a StatefulSet `volumeClaimTemplate` is not covered.
- A PersistentVolumeClaim whose storage class waits for the first consumer is `Progressing` until a Pod uses it: the claim cannot be told from one that cannot bind.
- For a Helm chart, Sveltos selects the resources in the release namespace that carry the release annotation. A chart that creates resources in other namespaces is only partly covered.

## Customize the Checks

*healthMonitoring* has three fields:

| Field | Default | Meaning |
|---|---|---|
| `enabled` | | Turns health monitoring on for the profile |
| `defaultChecks` | `true` | Monitors the kinds in the table above |
| `healthChecks` | | Names of [HealthCheck](../observability/notifications.md) instances to monitor in addition to the default checks |

`healthChecks` lets you monitor what the default checks do not know about, such as a Certificate or a custom resource, with a [HealthCheck](../observability/notifications.md) you write. Sveltos deploys it to the clusters and reports its resources together with the others. You own the selectors and the Lua of your HealthCheck, so make it select only what you care about.

```yaml
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: cert-manager
spec:
  clusterSelector:
    matchLabels:
      env: prod
  helmCharts:
  - repositoryURL:    https://charts.jetstack.io
    repositoryName:   jetstack
    chartName:        jetstack/cert-manager
    chartVersion:     v1.16.2
    releaseName:      cert-manager
    releaseNamespace: cert-manager
    helmChartAction:  Install
  healthMonitoring:
    enabled: true
    healthChecks:
    - certificates-ready
```

Set `defaultChecks` to `false` to monitor only the HealthChecks you list. This keeps the sveltos-agent lighter in a cluster with little memory.

The following is rejected when the profile is created:

- `healthChecks` with `enabled: false`;
- `enabled: true` with `defaultChecks: false` and no `healthChecks`: there would be nothing to monitor.

!!! important
    `healthChecks` is only honored by a ClusterProfile. It is ignored by a (namespaced) Profile, which gets the default checks only. A HealthCheck is a cluster scoped resource and its report is shared by every profile that references it on a cluster, with no filtering by namespace. If a Profile could reference one, a tenant could name a HealthCheck it does not own and learn about resources outside its namespace through the shared report. The default checks are safe for a Profile because they select only the resources that Profile deployed.

### Memory Cost

The sveltos-agent running in the managed cluster watches the kinds to monitor. On a typical cluster the five default kinds cost about 15 MB of heap (65 MB resident). On a cluster with thousands of objects they cost more, up to about 90 MB of heap in a cluster with 5,700 objects. Each kind you add with a HealthCheck adds a watch as well.

## Health Monitoring Versus validateHealths

Both fields use health checks, for different purposes:

| | `validateHealths` | `healthMonitoring` |
|---|---|---|
| Question it answers | Is what I just deployed ready? | Is what I deployed still healthy? |
| When it runs | While deploying | Continuously, after the profile is provisioned |
| Effect | Holds the profile in a non-provisioned state, and the profiles that `dependsOn` it | None: it only reports |
| Where you define it | Lua, CEL, metric and Job checks, written by you | The default checks, plus HealthChecks you list |

They work together. A common setup is `validateHealths` to roll out safely, and `healthMonitoring` to know when something breaks later.

## Reading the Result

Each cluster, and each profile on a cluster, has a state:

| State | Meaning |
|---|---|
| `NotEnabled` | No profile has health monitoring enabled on the cluster, and there is no health report |
| `NoData` | Monitoring is enabled but no report has been received yet. This is normal right after a profile is deployed |
| `Healthy` | A report was received and nothing is unhealthy |
| `Suspended`, `Progressing`, `Degraded` | At least one resource has this status. The state is the worst of the resources |

A cluster that shows nothing and a cluster that is healthy are different things, so the tools below always tell `NotEnabled` and `NoData` apart from `Healthy`.

For each unhealthy resource, Sveltos tells which profile deployed it. A resource reported by several checks is listed once. When a profile owns a report, the status and message come from the reports owned by profiles. When two reports of the same kind disagree, the worst status wins.

If a HealthCheck reports resources and no profile with monitoring enabled owns it, for instance a HealthCheck a profile used to list, the resources are still listed. Their owner is shown as the HealthCheck name instead of a profile.

Sveltos changes the state of a resource only after it has stayed in the new state for a few consecutive evaluations, so a resource that flips for a moment does not show up.

## Where to See It

- **Dashboard**: the [Sveltos dashboard](#dashboard) shows the health of each cluster and profile, and lists the unhealthy resources of a cluster.
- **sveltosctl**: [show unhealthy-resources](../getting_started/sveltosctl/features/visibility.md#show-unhealthy-resources) lists the unhealthy resources of any cluster and profile.
- **MCP server**: the [Sveltos MCP Server](mcp.md) has a `get_cluster_health` tool, and `diagnose_cluster` and `diagnose_profile` include the unhealthy resources in their findings.

## Dashboard

The dashboard shows health monitoring in three places.

**Clusters.** Each cluster card has a health badge: `Healthy`, `Progressing`, `Degraded`, `Suspended` or `No data`. A cluster with nothing monitored has no badge. Click the badge to open the unhealthy resources of the cluster.

**Profiles tab.** Open a cluster and select the *Profiles* tab. The *Health* column shows the state of each profile on that cluster. A profile that does not have health monitoring enabled shows a dash. Click the badge of a profile to see its unhealthy resources.

![Health of the profiles deployed in a cluster](../assets/dashboard_profiles_health.png)

**Unhealthy resources tab.** The *Unhealthy resources* tab of the cluster lists the resources that are not healthy: the group, version, kind, namespace and name of each resource, its status, why it is not healthy and the profile that deployed it. The worst status comes first. You can filter by profile (kind and name), by resource kind, by namespace and by resource name.

![Unhealthy resources of a cluster](../assets/dashboard_unhealthy_resources.png)

When a profile is not selected in the filter, the tab lists the unhealthy resources of all the profiles on the cluster, plus the ones reported by a HealthCheck no profile owns. For those, the *Profile* column shows the HealthCheck name.

When the list is empty, the tab says why, so that an empty list is never mistaken for a healthy cluster:

- *Nothing is monitored on this cluster*: no profile has health monitoring enabled and there are no health reports;
- *Health monitoring is enabled, but no report has been received yet*;
- *All the monitored resources are healthy*.

## Without a Tool

The same data is in the management cluster. Each monitored profile on a cluster has a generated HealthCheck, named `hm-` followed by a hash, and a HealthCheckReport for it:

```bash
kubectl get healthcheckreports -n <cluster namespace>
```

The report names do not tell which profile they belong to. `sveltosctl show unhealthy-resources` and the dashboard make that link for you.
