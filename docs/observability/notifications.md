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

1. __Addons__: tracks the __deployment__ of the add-ons. It is satisfied when Sveltos has successfully deployed everything the matching ClusterProfiles/Profiles ask for;
2. __HealthCheck__: tracks the __live state__ of resources in the managed clusters. It evaluates any Kubernetes resource, whether or not Sveltos deployed it, and keeps watching it.

The two types answer different questions, and it is important to pick the right one.

An __Addons__ liveness check reflects the status of the ClusterSummary, and the ClusterSummary status changes only when Sveltos has something to do: a new cluster matches, a ClusterProfile changes, a referenced ConfigMap or Secret changes, or drift is detected and reconciled. Once everything is deployed, nothing changes in the ClusterSummary until one of those events happens. Sveltos does not keep checking whether the deployed workloads are actually running.

A __HealthCheck__ liveness check does not depend on what Sveltos deploys or when. It evaluates the resources in the managed cluster continuously, and a state change of those resources is reflected in the ClusterHealthCheck.

!!! example "Example"
    Sveltos deploys a Deployment on day 0. The ClusterSummary reports `Provisioned`, and the __Addons__ liveness check passes. A week later the Pods start crash-looping because of an expired credential or a node problem. Nobody changed the ClusterProfile and the Deployment is not drifted, so the ClusterSummary stays `Provisioned` and the __Addons__ liveness check keeps passing. Only a __HealthCheck__ that evaluates those Pods (see [Example: Filtering Out Flapping Resources](#example-filtering-out-flapping-resources)) detects the problem and triggers the notification.

In short:

| | Addons | HealthCheck |
|---|---|---|
| Question answered | Did Sveltos deploy what was asked? | Are the resources healthy right now? |
| Changes when | Sveltos deploys, updates or removes something, or reconciles drift | The state of the watched resources changes in the managed cluster |
| Detects a Pod crashing a week after deployment | No | Yes |
| Detects a resource not deployed by Sveltos | No | Yes |

Most production setups use both: __Addons__ to know when a cluster is ready, __HealthCheck__ to know it is still healthy afterwards.

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

### Notification policy

By default, a notification is sent the first time a cluster is evaluated, every time the state of a liveness check flips, and every time the failure message changes while a liveness check is failing. Any change causes Sveltos to send the notification again to all the channels configured for that cluster.

On a large fleet, or with a liveness check that flips often, this can become noisy. Each notification can define an optional __policy__ that decides when that notification is delivered. Policies are evaluated per cluster and per notification, so the same ClusterHealthCheck can page a team immediately on one channel and send a calmer summary on another.

* **`policy.onlyOnTransition`**
    * **Purpose:** Notify on state changes only (Optional)
    * **Details:** When `true`, a notification is sent only when a cluster moves from passing to failing, or from failing to passing. A change of the failure message while the cluster is still failing is not sent.
* **`policy.minInterval`**
    * **Purpose:** Rate limit (Optional)
    * **Details:** The minimum time between two deliveries of this notification for the same cluster. A notification held back by `minInterval` is not lost: once the interval has elapsed, Sveltos sends it, unless the cluster is back in the state that was last delivered.
* **`policy.failingFor`**
    * **Purpose:** Hold-back for transient failures (Optional)
    * **Details:** How long a cluster must have been failing before the failure is reported. If the cluster recovers within this time, nothing is sent: neither the failure nor the recovery.

Both `minInterval` and `failingFor` are durations, for example `30s`, `5m` or `1h`. The three fields can be combined.

A few things worth knowing:

1. A notification without a `policy` (or with an empty one) behaves exactly as described above. Existing ClusterHealthCheck instances are not affected.
1. When a policy is set, a cluster that is healthy the first time it is evaluated is not notified. There is nothing to report until something fails.
1. `failingFor` is measured from the moment the oldest failing liveness check started failing. It only delays a failure being reported. A recovery is sent right away, but only if the failure it recovers from was reported before.
1. If a delivery fails (for example, the Slack API is unreachable), Sveltos retries without waiting for `minInterval`.
1. A notification with a policy is evaluated on its own. A change that makes another notification fire does not re-send this one.
1. When a notification is being held back, Sveltos schedules a new evaluation for the moment the hold-back ends. There is no need for the cluster state to change again.

Sveltos records what it last delivered in the ClusterHealthCheck status, for each cluster and for each notification, inside `notificationSummaries`:

* **`lastSentTime`**: when the notification was last delivered;
* **`lastSentFailing`**: whether the cluster was failing at that time;
* **`lastSentMessageHash`**: a short hash identifying the failure message that was delivered.

!!! note
    The `policy` field acts on the ClusterHealthCheck notifications, so on the state of a cluster as a whole. To avoid reporting a single resource that flips briefly, see the `flapping` field of the [HealthCheck CRD](#healthcheck-crd). The two can be used together: `flapping` filters noise out of a single HealthCheck, `policy` controls how often the resulting state is notified.

See [Example: Reducing Notification Volume](#example-reducing-notification-volume) below.

### HealthCheck CRD

The [HealthCheck](https://github.com/projectsveltos/libsveltos/blob/main/api/v1beta1/healthcheck_type.go) resource defines a custom health assessment by first selecting Kubernetes resources and then applying custom evaluation logic to determine their collective health.

* **`resourceSelectors`**
    * **Purpose:** Resource Selection
    * **Details:** An array of `ResourceSelector` objects. These define the Kubernetes resources to monitor by specifying their `Group`, `Version`, `Kind`, `Namespace`, and `Name`.
* **`resourceSelectors[*].LabelFilters`**
    * **Purpose:** Filtering by Label
    * **Details:** Filters the selected resources using standard label operations: `Equal`, `Different`, `Has`, or `DoesNotHave`.
* **`resourceSelectors[*].Evaluate`**
    * **Purpose:** Lua Pre-Filter (Optional)
    * **Details:** An optional Lua script used to *additionally* filter resources before the main health check is performed.
* **`resourceSelectors[*].EvaluateCEL`**
    * **Purpose:** CEL Pre-Filter (Optional)
    * **Details:** An optional list of Common Expression Language (CEL) rules used to *additionally* filter resources.
* **`evaluateHealth`**
    * **Purpose:** Custom Health Evaluation
    * **Details:** A **mandatory** Lua script that performs the core health check logic on all the final, filtered resources.
* **`flapping.consecutiveEvaluations`**
    * **Purpose:** Flapping mitigation (Optional)
    * **Details:** The number of consecutive evaluations a resource must be found in the same non-Healthy status before it is reported. Omit `flapping` entirely to report every non-Healthy resource immediately, exactly as before this field existed. See [Example: Filtering Out Flapping Resources](#example-filtering-out-flapping-resources) below.

The `Spec.evaluateHealth` field must contain a Lua script with a function named **`evaluate()`**.

The [`healthcheck-manager/examples/healthchecks`](https://github.com/projectsveltos/healthcheck-manager/tree/main/examples/healthchecks) directory collects ready-to-apply `HealthCheck` definitions for well-known CRDs (Velero `Backup`, Kyverno `PolicyReport`, cert-manager `Certificate`, `Job`, `StatefulSet` rollout, CloudNativePG `Cluster`, Contour `HTTPProxy`, Knative `Service`). Each one is covered by a unit test, so the scripts are exactly what's tested, not a copy that can drift out of sync.

**Input Access:**
The function accesses all Kubernetes resources selected by `resourceSelectors` using the global Lua variable: **`resources`**.

**Required Output:**
It must return an **array of tables** (structured instances), with the following required and optional fields for each evaluated resource:

* **`resource`**
    * **Type:** Object
    * **Description:** The specific Kubernetes resource that was evaluated.
* **`healthStatus`**
    * **Type:** String
    * **Description:** The assessment of the resource's health. Must be one of: **`Healthy`**, **`Progressing`**, **`Degraded`**, or **`Suspended`**.
* **`message`**
    * **Type:** String
    * **Description:** Optional, an informative message providing context for the status.
* **`reEvaluate`**
    * **Type:** Boolean
    * **Description:** Optional. If set to `true`, the health check will be automatically re-evaluated in 10 seconds.
* **`ignore`**
    * **Type:** Boolean
    * **Description:** Optional. If set to `true`, Sveltos will ignore this resource's result during the overall health calculation.

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

## Example: Filtering Out Flapping Resources

By default, a `HealthCheck` re-evaluates a resource only when Sveltos detects a change to it. This is efficient, but it also means a resource that flips briefly into a bad state (a Pod restarting once, a Job failing and immediately retrying) can trigger a `Degraded` report for something that was never really a problem.

The `flapping` field tells Sveltos to hold a resource in a pending state until it has been observed in the same non-Healthy status for a set number of consecutive evaluations, instead of reporting it right away. Recovery is always immediate: as soon as a resource is evaluated `Healthy` again, any pending count for it is cleared.

While a resource has not yet crossed the threshold, Sveltos keeps re-evaluating that `HealthCheck`, even without a new change on the resource, so the pending count keeps advancing until it either crosses the threshold or the resource recovers. In this scenario, `HealthCheck` instances are re-evaluated roughly every 10 seconds on average.

Take the classic `CrashLoopBackOff` Pod: without `flapping`, a script has to hand-roll its own debounce logic, parsing `lastTransitionTime` off a condition and comparing it to `os.time()`. With `flapping`, the script only needs to report the instantaneous truth and Sveltos takes care of the rest:

!!! example "Example - HealthCheck Definition with Flapping"
    ```yaml
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: HealthCheck
    metadata:
      name: pod-crashloopbackoff
    spec:
      collectResources: true
      resourceSelectors:
      - group: ""
        version: v1
        kind: Pod
      flapping:
        consecutiveEvaluations: 6
      evaluateHealth: |
        function evaluate()
          local statuses = {}

          for _, pod in ipairs(resources) do
            local hasError = false

            if pod.status and pod.status.containerStatuses then
              for _, container in ipairs(pod.status.containerStatuses) do
                if container.state and container.state.waiting then
                  local reason = container.state.waiting.reason
                  if reason == "CrashLoopBackOff" or reason == "BackOff" then
                    hasError = true
                  end
                end
              end
            end

            if hasError then
              table.insert(statuses, {resource = pod, status = "Degraded",
                message = "Container is in CrashLoopBackOff"})
            end
          end

          local hs = {}
          if #statuses > 0 then
            hs.resources = statuses
          end
          return hs
        end
    ```

With `HealthCheck` instances re-evaluated roughly every 10 seconds on average, `consecutiveEvaluations: 6` means a Pod has to be observed crash-looping for about 60 seconds before it is reported `Degraded`. A single restart, or two restarts a few seconds apart, never reaches the threshold and is never reported.

## Example: Reducing Notification Volume

In the following ClusterHealthCheck, the same liveness checks drive two notifications with different policies:

* the `slack-oncall` notification is sent only when a cluster has been failing for at least 5 minutes, and it is sent at most once every 30 minutes for a given cluster. It is not sent again when the failure message changes while the cluster is still failing;
* the `kubernetes-events` notification has no policy: every change is recorded as a Kubernetes event, as before.

!!! example "Example - ClusterHealthCheck with Notification Policies"
    ```yaml
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: ClusterHealthCheck
    metadata:
      name: production
    spec:
      clusterSelector:
        matchLabels:
          env: production
      livenessChecks:
      - name: addons
        type: Addons
      - name: pods
        type: HealthCheck
        livenessSourceRef:
          kind: HealthCheck
          apiVersion: lib.projectsveltos.io/v1beta1
          name: pod-crashloopbackoff
      notifications:
      - name: slack-oncall
        type: Slack
        notificationRef:
          apiVersion: v1
          kind: Secret
          name: slack
          namespace: default
        policy:
          onlyOnTransition: true
          minInterval: 30m
          failingFor: 5m
      - name: kubernetes-events
        type: KubernetesEvent
    ```

With this configuration:

1. A cluster that is healthy when first evaluated does not trigger a Slack message.
1. A cluster that starts failing is reported on Slack only if it is still failing 5 minutes later. A failure that clears within 5 minutes produces no message at all.
1. When the cluster recovers, Slack is notified, provided the failure was reported and at least 30 minutes have passed since the previous Slack message for that cluster. If not, the recovery is sent as soon as the 30 minutes have elapsed.
1. If the cluster is still failing and the failure message changes (for example, a second Pod starts crash-looping), no new Slack message is sent because `onlyOnTransition` is set. Remove `onlyOnTransition` to be notified of these changes, still at most once every 30 minutes.

To see what was last delivered for a cluster:

```bash
kubectl get clusterhealthcheck production -o yaml
```

and look at `status.clusterCondition[*].notificationSummaries`.

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