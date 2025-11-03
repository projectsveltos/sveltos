---
title: Notifications - Projectsveltos
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative APIs to deploy Kubernetes add-ons across multiple clusters.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
    - Sveltos
    - Slack
authors:
    - Gianluca Mardente
---

## Introduction to Notifications

Sveltos uses ClusterProfiles/Profiles to automatically track matching clusters and deploy specified add-ons (like Helm charts or Kubernetes resources). It can then assess the cluster health (ensuring all add-ons are ready) and send notifications. These notifications allow external tools to trigger further workflows, like CI/CD pipelines, only once the cluster is confirmed healthy and stable.

## ClusterHealthCheck

[ClusterHealthCheck](https://github.com/projectsveltos/libsveltos/raw/main/api/v1beta1/clusterhealthcheck_type.go) is the CRD that can be used to:

1. Define the cluster health checks;
2. Instruct Sveltos **when** and **how** to send notifications

### Cluster Selection

The `clusterSelector` field is a Kubernetes label selector. Sveltos uses it to detect all the clusters to assess health and send out notifications.

### LivenessChecks
The `livenessCheck` field is a list of __cluster liveness checks__ to be evaluated.

The supported types are:

1. __Addons__: Addons type instructs Sveltos to evaluate state of add-ond deployment in such a cluster;
2. __HealthCheck__: HealthCheck type allows to define a custom health check for any Kubernetes type.

### Notifications

The notifications fields is a list of all __notifications__ to be sent when the liveness check state changes.

The supported types are:

1. <img src="../../assets/slack_logo.png" alt="Slack" width="25" />  [Slack](./example_addon_notification.md#slack)
1. <img src="../../assets/webex_logo.png" alt="Webex" width="25" />  [Webex](./example_addon_notification.md#webex)
1. <img src="../../assets/teams_logo.svg" alt="Teams" width="25" />  [Teams](./example_addon_notification.md#teams)
1. <img src="../../assets/discord_logo.png" alt="Discord" width="25" />  [Discord](./example_addon_notification.md#discord)
1. <img src="../../assets/telegram_logo.png" alt="Telegram" width="25" />  [Telegram](./example_addon_notification.md#telegram)
1. <img src="../../assets/smtp_logo.png" alt="SMTP" width="25" />  [SMTP](./example_addon_notification.md#smtp)
1. <img src="../../assets/kubernetes_logo.png" alt="Kubernetes" width="25" /> [Kubernetes events](./example_addon_notification.md#kubernetes-event) (__reason=ClusterHealthCheck__)


### HealthCheck CRD

The [HealthCheck](https://github.com/projectsveltos/libsveltos/blob/main/api/v1beta1/healthcheck_type.go) resource defines a custom health assessment by first selecting Kubernetes resources and then applying custom evaluation logic to determine their collective health.

| Field | Purpose | Details |
| :--- | :--- | :--- |
| **`resourceSelectors`** | **Resource Selection** | An array of `ResourceSelector` objects that define the Kubernetes resources to monitor (by `Group`, `Version`, `Kind`, `Namespace`, `Name`). |
| `resourceSelectors[*].LabelFilters` | **Filtering by Label** | Filters resources using standard label operations: `Equal`, `Different`, `Has`, or `DoesNotHave`. |
| `resourceSelectors[*].Evaluate` | **Lua Pre-Filter** | Optional. A Lua script to *additionally* filter resources before the main health check. |
| `resourceSelectors[*].EvaluateCEL` | **CEL Pre-Filter** | Optional. A list of Common Expression Language (CEL) rules to *additionally* filter resources. |
| **`evaluateHealth`** | **Custom Health Evaluation** | **Mandatory** Lua script that performs the core health check on all selected resources. |


The `Spec.evaluateHealth` field must contain a Lua script with a function named **`evaluate()`**.

**Input Access:**
The function accesses all Kubernetes resources selected by `resourceSelectors` using the global Lua variable: **`resources`**.

**Required Output:**
It must return an **array of tables** (structured instances), with the following required and optional fields for each evaluated resource:

| Field | Type | Description |
| :---: | :---: | :--- |
| **`resource`** | Object | The specific Kubernetes resource that was evaluated. |
| **`healthStatus`** | String | The assessment. Must be one of: **`Healthy`**, **`Progressing`**, **`Degraded`**, or **`Suspended`**. |
| **`message`** | String | Optional, an informative message for the status. |
| **`reEvaluate`** | Boolean | Optional. If `true`, the check will be re-evaluated in 10 seconds. |
| **`ignore`** | Boolean | Optional. If `true`, Sveltos will ignore this resource's result. |

## Example: ConfigMap HealthCheck

In the follwoing example[^1], we are creating an HealthCheck that watches all the ConfigMap Kubernetes resources.

`hs` is the health status object we will return to Sveltos. It must contain a `status` attribute which indicates whether the resource is `Healthy`, `Progressing`, `Degraded` or `Suspended`. By default,the status is set to `Healthy` and the `hs.ignore` is set to `true`, as we do not want to mess with the status of other, non-OPA ConfigMaps. Optionally, the health status object may also contain a message.

In this example, we want to identify if the ConfigMap is an OPA policy or another kind of ConfigMap. If it is a OPA policy, we retrieve the value of the openpolicyagent.org/policy-status annotation. The annotation is set to {"status":"ok"} if the policy loaded successfully. If errors occurred during loading (e.g., the policy contained a syntax error) the cause will be reported in the annotation. Depending on the value of the annotation, we set the status and message attributes appropriately.

At the end, we return the `hs` object to Sveltos.

!!! example "Example - HealthCheck Definition"
    ```yaml
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: HealthCheck
    metadata:
      name: opa-configmaps
    spec:
      resourceSelectors:
      - group: ""
        version: v1
        kind: ConfigMap
      evaluateHealth: |
        function evaluate()
          statuses = {}

          status = "Healthy"
          message = ""

          local opa_annotation = "openpolicyagent.org/policy-status"

          for _,resource in ipairs(resources) do
            if resource.metadata.annotations ~= nil then
              if resource.metadata.annotations[opa_annotation] ~= nil then
                if obj.metadata.annotations[opa_annotation] == '{"status":"ok"}' then
                  status = "Healthy"
                  message = "Policy loaded successfully"
                else
                  status = "Degraded"
                  message = obj.metadata.annotations[opa_annotation]
                end
                table.insert(statuses, {resource=resource, status = status, message = message})
              end
            end
          end
          local hs = {}
          if #statuses > 0 then
            hs.resources = statuses
          end
          return hs
        end
    ```

The below `ClusterHealthCheck` resources, will send a Webex message as notification if a ConfigMap with an incorrect OPA policy is detected.

!!! example ""
    ```yaml
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: ClusterHealthCheck
    metadata:
      name: hc
    spec:
      clusterSelector:
        matchLabels:
          env: fv
      livenessChecks:
      - name: deployment
        type: HealthCheck
        livenessSourceRef:
          kind: HealthCheck
          apiVersion: lib.projectsveltos.io/v1beta1
          name: opa-configmaps
      notifications:
      - name: webex
        type: Webex
        notificationRef:
          apiVersion: v1
          kind: Secret
          name: webex
          namespace: default
    ```

[^1]: Credit for this example to https://blog.cubieserver.de/2022/argocd-health-checks-for-opa-rules/

## Notifications and multi-tenancy

If the below label is set on the HealthCheck instance created by the tenant admin

```
projectsveltos.io/admin-name: <admin>
```

Sveltos will ensure the tenant admin can define notifications only by looking at the resources it has been [authorized to by platform admin](../features/multi-tenancy-sharing-cluster.md).

Sveltos suggests using the below Kyverno ClusterPolicy, which takes care of adding proper labels to each HealthCheck at creation time.

!!! example ""
    ```yaml
    ---
    apiVersion: kyverno.io/v1
    kind: ClusterPolicy
    metadata:
      name: add-labels
      annotations:
        policies.kyverno.io/title: Add Labels
        policies.kyverno.io/description: >-
          Adds projectsveltos.io/admin-name label on each HealthCheck
          created by tenant admin. It assumes each tenant admin is
          represented in the management cluster by a ServiceAccount.
    spec:
      background: false
      rules:
      - exclude:
          any:
          - clusterRoles:
            - cluster-admin
        match:
          all:
          - resources:
              kinds:
              - HealthCheck
        mutate:
          patchStrategicMerge:
            metadata:
              labels:
                +(projectsveltos.io/serviceaccount-name): '{{serviceAccountName}}'
                +(projectsveltos.io/serviceaccount-namespace): '{{serviceAccountNamespace}}'
        name: add-labels
      validationFailureAction: enforce
    ```