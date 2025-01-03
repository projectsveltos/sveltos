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

When a ClusterProfile is instantiated using Sveltos, it automatically watches for clusters that match the ClusterProfile clusterSelector field. When a match is found, [Sveltos](https://github.com/projectsveltos) deploys all of the referenced add-ons, such as helm charts or Kubernetes resources.

Once the necessary add-ons are deployed, there might be a need to perform other operations on the cluster, such as running a CI/CD pipeline. However, it is important to ensure that the cluster is healthy, i.e., all necessary add-ons are deployed, before proceeding. Sveltos can be configured to **assess** the cluster health and send notifications if any changes are detected.

The notifications can be used by other tools to perform additional actions or trigger workflows. Sveltos will ensure the necessary Kubernetes add-ons are deployed and managed while ensuring the health and stability of the clusters.

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
To define a custom health check, simply create a [HealthCheck](https://github.com/projectsveltos/libsveltos/blob/main/api/v1beta1/healthcheck_type.go) instance.

The `HealthCheck` specification can can contain the below fields:

1. ```Spec.Group*/*Spec.Version*/*Spec.Kind`` fields indicates which Kubernetes resources the HealthCheck is for. Sveltos will watch and evaluate these resources anytime a change occurs;
2. ```Spec.Namespace``` field can be used to filter resources by namespace;
3. ```Spec.LabelFilters``` field can be used to filter resources by labels;
4. ```Spec.Script``` can contain a [Lua](https://www.lua.org/pil/contents.html) script, which define a custom health check.

The Lua script must contain the function `evaluate()` that returns a table with a status field (__Healthy__/__Progressing__/__Degraded__/__Suspended__) and optional message field.

When providing Sveltos with a [Lua script](https://www.lua.org/), Sveltos expects following format:

1. Must contain a function ```function evaluate()```. The function is directly invoked and passed a Kubernetes resource (inside the function ```obj``` represents the passed in Kubernetes resource);
2.Must return a Lua table with following fields:
   1. `status`: which can be set to either one of	__Healthy__/__Progressing__/__Degraded__/__Suspended__;
   2. `ignore`: is a boolean field indicating whether Sveltos should ignore the resource. If hs.ignore is set to `true`, Sveltos will ignore the resource causing that result;
   3. `message`: is a string that can be set and Sveltos will print a message if it is set

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

The below `ClusterHealthCheck` resources, will send a Webex message as notification if a ConfigMap
with an incorrect OPA policy is detected.

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

!!! tip

    If the Lua language is preferred to write the HealthCheck, it might be handy to validate the definition before use.

    This can be achieved by cloning the [sveltos-agent](https://github.com/projectsveltos/sveltos-agent) repository. In the *pkg/evaluation/healthchecks* directory, create a directory for the deployed resources if it does not exist already. If a directory already exists, create a subdirectory instead.

    In the directory or the subdirectory, create the below points.

    1. The file named *healthcheck.yaml* containing the HealthCheck instance with Lua script;
    2. The file named *healthy.yaml* containing a Kubernetes resource supposed to be Healthy for the Lua script created in #1 (this is optional);
    3. The file named *progressing.yaml* containing a Kubernetes resource supposed to be Progressing for the Lua script created in #1 (this is optional);
    4. The file named *degraded.yaml* containing a Kubernetes resource supposed to be Degraded for the Lua script created in #1 (this is optional);
    3. The file named *suspended.yaml* containing a Kubernetes resource supposed to be Suspended for the Lua script created in #1 (this is optional);
    5. *make test*

    As mentioned above, one of the following statuses will get returned (`Healthy`, `Progressing`, `Degraded` or `Suspended`) once the resources are verified.


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
