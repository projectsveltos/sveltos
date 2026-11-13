---
title: Sveltos - Troubleshooting Section
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative cluster APIs. Learn here how to install Sveltos.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
    - troubleshooting
authors:
    - Eleni Grosdouli
---

## Introduction
In this section, we will help Sveltos users identify ways to troubleshoot the Sveltos installation alongside deployed add-ons down the different clusters. In general, it is a good practice to get the Sveltos version alongside the `sveltosctl` version (if used) as it is helpful for the team to provide better assistance and recommendations.

### Sveltos Version
```bash
$ kubectl get job register-mgmt-cluster-job -n projectsveltos -o=jsonpath='{.spec.template.spec.containers[0].image}'
```

### sveltosctl Version
```bash hl_lines="2-3"
$ sveltosctl version
I0428 09:05:01.496691 2181388 version.go:64] "Client Version:   v0.27.0-17-2fb25f7e7a15a3"
I0428 09:05:01.496715 2181388 version.go:65] "Git commit:       2fb25f7e7a15a3adc351e569f79ec1f80ae1ac7e"
```

## Common Issues

## Sveltos Installation Namespace
It is a **requirement** for Sveltos to get installed in the `projectsveltos` namespace. If Sveltos is installed in a different namespace, issues with the Kubernetes resources deployment will arise.

## Sveltos ClusterProfile, Profile is not applied to the cluster/s
This is a very common case scenario where the deployed Sveltos `ClusterProfile`, and `Profile` resources are not deployed to the targeted cluster/s. This might be due to an issue with the Sveltos installation, incorrect Sveltos namespace installation, incorrect `cluster-label` set to the cluster or something else that might be disallowing the deployment.

The _Status_ section of a ClusterProfile or Profile instance displays all clusters that meet its criteria. These matching clusters are listed under the __matchingClusters__ field.

Here's an example of what the _Status_ section might look like:

```yaml
status:
  matchingClusters:
  - apiVersion: cluster.x-k8s.io/v1beta1
    kind: Cluster
    name: clusterapi-workload
    namespace: default
  - apiVersion: lib.projectsveltos.io/v1beta1
    kind: SveltosCluster
    name: mgmt
    namespace: mgmt
```

To confirm if a specific cluster is considered a match for a ClusterProfile or Profile, check the __matchingClusters__ list within the _Status_ section of the ClusterProfile/Profile instance.
If the cluster details are present in the list, then Sveltos considered it a matching cluster.

Sveltos automatically creates a ClusterSummary resource whenever a cluster aligns with a configured ClusterProfile or Profile. This summary serves as a record of the cluster's configuration and deployment status.

Imagine a SveltosCluster named __mgmt__ residing in the __mgmt__ namespace, with labels indicating environment (env=fv). Now, consider a ClusterProfile named __deploy-kyverno__ that has a `clusterSelector` targeting clusters with the label env=fv.
If these conditions are met, Sveltos will generate a __ClusterSummary__ within the mgmt namespace. This ClusterSummary will resemble the following:

```yaml
---
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterSummary
metadata:
  name: deploy-kyverno-sveltos-mgmt
  namespace: mgmt
spec:
  clusterName: mgmt
  clusterNamespace: mgmt
  clusterType: Sveltos
  clusterProfileSpec:
    clusterSelector:
      matchLabels:
        env: fv
    helmCharts:
    - chartName: kyverno/kyverno
      chartVersion: v3.3.3
      helmChartAction: Install
      releaseName: kyverno-latest
      releaseNamespace: kyverno
      repositoryName: kyverno
      repositoryURL: https://kyverno.github.io/kyverno/
status:
  dependencies: no dependencies
  featureSummaries:
  - featureID: Helm
    hash: ujsdjTgHzPfqEx3bHtAIFcs3kjSvcuTkRCXc3o7AqrY=
    lastAppliedTime: "2024-05-10T14:25:58Z"
    status: Provisioned
```

The _Status_ section of a ClusterSummary is crucial. It reflects whether the configured add-ons or applications are successfully deployed (Provisioned). If any issues arise during deployment, a _FailureMessage_ field will appear, providing details about the encountered error.

### Check the Overall Sveltos Installation (Management Cluster)
```bash
$ kubectl get pods -n projectsveltos
```

All the pods need to be in a `Running` state. If a pod is in a different state, perform the below commands to get a better understanding. The Events section or the logs provided by the pod will be sufficient to get an understanding of what might be failing.

```bash
$ kubectl describe pod <pod-name> -n projectsveltos

$ kubectl logs <pod-name> -n projectsveltos -f
```

### Fixing ‘Cannot Re-Use a Name That Is Still In Use’

Do you encounter the error "**cannot re-use a name that is still in use**" while deploying Helm charts with Sveltos? Don't worry, this is a common issue with a straightforward solution.

The error typically arises when a secret related to a previous Helm chart deployment still lingers in the target namespace of the **managed** cluster. These lingering secrets can cause naming conflicts when deploying new charts.

Pointing to the managed cluster, run the below command to list all secrets in the desired namespace, filtering for those associated with Helm.

```
$ kubectl -n <your namespace> get secrets | grep helm
```

If the command reveals any secrets with a status of "**pending-install**", proceed and delete them.

By removing the lingering secrets, we eliminate potential naming conflicts and pave the way for smooth Helm chart deployments.

### Check Sveltos Registered Clusters
```bash
$ kubectl get sveltosclusters -A
```

Ensure the Sveltos clusters are in a `READY=true` state. If Sveltos is unable to communicate with a cluster, we will see spot it directly from the output above.

#### Healthy Cluster State
```bash
$ kubectl get sveltoscluster -A
NAMESPACE        NAME            READY   VERSION
projectsveltos   vcluster-dev    true    v1.29.0+k3s1
projectsveltos   vcluster-prod   true    v1.29.0+k3s1
mgmt             mgmt            true    v1.28.7+k3s1
```

#### Unhealthy Cluster State
```bash
$ kubectl get sveltoscluster -A
NAMESPACE        NAME            READY   VERSION
projectsveltos   vcluster-dev
mgmt             mgmt            true    v1.28.7+k3s1
```

In the output above, we can spot that the `vcluster-dev` cluster in the `projectsveltos` namespace is not in a `READY` state. That could mean network issues disallowing communication with the cluster or something is wrong with the cluster itself.

### How to work with an Unhealthy Cluster?

#### Step 1: Ensure the correct kubeconfig provided
This would mean that during the registration of the cluster, the provided kubeconfig is sufficient to authenticate with the clusters.

On a new terminal, perform the below.

```bash
$ export KUBECONFIG=<directory of the provided cluster kubeconfig>
$ kubectl get nodes
$ kubectl get pods -A
```

If you are not able to reach the cluster via the specified kubeconfig file, it could be an invalid kubeconfig. Doublecheck the file generated and ensure is the correct one.

#### Step 2: Network Connectivity
If `Step 1` is fine and we can access the cluster resources with the `kubeconfig`, continue the investigation with the network and firewall setup in the environment. Ensure nothing is blocking the traffic from the management cluster to the managed cluster.

!!! tip
    In specific Operating Systems (Suse Enterprise Linux), the security hardening disallowed the `sveltosctl` to validate and register the cluster due to the certificate issue. In this case, we have to import the cluster certificate to the trusted store.

### Check Labels set to Registered Clusters

```bash
$ kubectl get sveltosclusters -A --show-labels
```
Ensure the labels set to the Sveltos clusters do match the labels defined in the Sveltos `ClusterProfile`, `Profile`.

If the cluster labels are incorrect, we can overwrite them with the below command.

```bash
$ kubectl label sveltoscluster <cluster-name> -n <cluster namespace> env=dev --overwrite
```
- `env=dev` is the new label set to the cluster

#### Validate
```bash
$ sveltosctl show addons
```

We assume the output above is empty. This implies that Sveltos was not able to deploy an add-on to a cluster or a set of clusters. Continue with the `clusterprofiles` and `clustersummary` resource investigation.

```bash
$ kubectl get clustersummary,clusterprofile -A
```

Even if the Kubernetes add-ons are not deployed, both resources will be available to the management cluster.

```bash
$ kubectl get clusterprofile <clusterprofile name> -n <clusterprofile namespace> -o jsonpath='{.status}'
```

```bash
$ kubectl get clustersummary <clustersummary name> -n <clustersummary namespace> -o jsonpath='{.status}'
```

We are here to help! Whether you have questions, or issues or need assistance, our Slack channel is the perfect place for you. Click [here](https://app.slack.com/client/T0471SNT5CZ/C06UZCXQLGP) to join us.


## Kubernetes Events

Sveltos components record Kubernetes events when a failure occurs or when a cluster becomes unreachable or reachable again. The same applies when a `ClusterPromotion` changes stage. An event states the cause; the root cause of a failure is visible without reading the logs.

### Viewing events

To see the events of a resource, use `kubectl describe`. The [table](#events-recorded-by-sveltos) at the end of this section lists the resources that have events. For example, for a `ClusterSummary`:

```bash
$ kubectl describe clustersummary <name> -n <namespace>
```

To list the Warning events of all Sveltos resources, in all namespaces:

```bash
$ kubectl get events -A --field-selector type=Warning
```

For example, a Helm chart that cannot be installed on a cluster:

```
Events:
  Type     Reason         Age   From              Message
  ----     ------         ----  ----              -------
  Warning  FeatureFailed  2m    addon-controller  Feature Helm for cluster Sveltos default/cluster1 failed: ...
```

!!! note
    - Events about a cluster-scoped resource (for instance ClusterHealthCheck, EventTrigger, Classifier or ClusterPromotion) are recorded in the `default` namespace.
    - Kubernetes keeps events for about one hour. No event does not mean that nothing failed earlier: the status of the resource still has the last failure message.

### Events are not repeated

The system records an event the first time it sees a failure, and again when it changes the failure message. If a failure is retried and fails the same way, it is not recorded again, so a cluster that keeps failing does not fill the event list. Nothing is recorded for expected states: a paused cluster, a cluster that is not ready, or a deployment still in progress.

### Events recorded by Sveltos

| Recorded on | Reason | Type | Recorded when |
|-------------|--------|------|---------------|
| ClusterSummary | `FeatureDeployed` | Normal | A feature (Helm, Resources, Kustomize) was deployed on a cluster. |
| ClusterSummary | `FeatureFailed` | Warning | A feature failed to deploy, or to be removed, and Sveltos will retry. |
| ClusterSummary | `FeatureFailedNonRetriable` | Warning | A feature failed and will not be retried until something changes, for instance a template that cannot be instantiated. |
| ClusterSummary | `ProfileConflict` | Warning | A resource the profile wants to deploy is already managed by another profile. |
| ClusterSummary | `LicenseInvalid` | Warning | The cluster is in pull mode and is not covered by a license. |
| SveltosCluster | `ClusterUnreachable` | Warning | The management cluster cannot connect to the cluster (push mode). Recorded when the connection goes down. |
| SveltosCluster | `AgentUnhealthy` | Warning | The Sveltos agent of a cluster in pull mode is not healthy. Recorded when the connection goes down. |
| SveltosCluster | `ClusterRecovered` | Normal | A cluster that was reported with `ClusterUnreachable` or `AgentUnhealthy` is healthy again. |
| Classifier, ManagementClusterClassifier | `ClassifierFailed` | Warning | The classifier could not be evaluated or could not label a cluster. |
| Classifier, ManagementClusterClassifier | `ClassifierLabelConflict` | Warning | More than one classifier wants to manage the same label key on a cluster. One event per cluster. |
| EventTrigger | `EventTriggerFailed` | Warning | The EventTrigger could not be deployed to a cluster, or removed from it. The cluster is the related object. |
| EventReport | `EventTriggerFailed` | Warning | The ClusterProfile instances for an EventReport could not be generated. The event is in the namespace of the cluster. |
| ClusterHealthCheck | `ClusterHealthCheckFailed` | Warning | The ClusterHealthCheck could not be deployed to a cluster, or removed from it. |
| ClusterHealthCheck | `NotificationFailed` | Warning | A notification (Slack, Webex, Discord, Teams, Telegram, SMTP) could not be delivered for a cluster. |
| ClusterPromotion | `StageStarted` | Normal | A stage is being provisioned. |
| ClusterPromotion | `StageProvisioned` | Normal | A stage is deployed to all its clusters. |
| ClusterPromotion | `PromotionCompleted` | Normal | All the stages are provisioned. |
| ClusterPromotion | `ApprovalRequired` | Warning | A stage with a manual trigger is provisioned and waits for the approval. |
| ClusterPromotion | `StageFailed` | Warning | A feature failed on a cluster of the stage. One event for the stage, with the first failure and the number of failed features. |

The `Kubernetes events` notification of a ClusterHealthCheck is a different thing: it records the result of the liveness checks, with the reason `ClusterHealthCheck`. See [notifications](../observability/notifications.md).

Some failures do not have an event yet. This is the case for:

- A ClusterProfile or Profile whose selector cannot be resolved.
- A ClusterProfile or Profile whose dependencies cannot be resolved.
- The Sveltos agent.
- Drift detection.
- The AccessRequest and RoleRequest resources.

For these, check the status of the resource or the logs.

!!! tip
    Event-watching tools and observability platforms that ingest Kubernetes events surface these warnings automatically. The [Sveltos MCP server](../features/mcp.md) reads them with the `list_sveltos_events` tool.

## Debugging

Sveltos provides a custom resource called `DebuggingConfiguration` that allows users to configure the log level for various system components. This is useful for troubleshooting specific issues by increasing verbosity.

The following example sets the log level of AddonManager to LogLevelDebug:

```yaml
apiVersion: lib.projectsveltos.io/v1beta1
kind: DebuggingConfiguration
metadata:
  ...
  ...
spec:
  configuration:
  - component: AccessManager
    logLevel: LogLevelInfo
  - component: AddonManager
    logLevel: LogLevelDebug
  - component: Classifier
    logLevel: LogLevelInfo
  - component: DriftDetectionManager
    logLevel: LogLevelInfo
  - component: EventManager
    logLevel: LogLevelInfo
  - component: HealthCheckManager
    logLevel: LogLevelInfo
  - component: SveltosClusterManager
    logLevel: LogLevelInfo
  - component: UIBackend
    logLevel: LogLevelInfo
  - component: SveltosAgent
    logLevel: LogLevelInfo
  - component: ShardController
    logLevel: LogLevelInfo
  - component: ConversionWebhook
    logLevel: LogLevelInfo
  - component: Techsupport
    logLevel: LogLevelInfo

```