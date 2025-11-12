---
title: Combining Rollout and Progressive Rollout Across Clusters
description: This example shows how to use both rollout and progressive rollout features of Sveltos together.
tags:
    - Kubernetes
    - add-ons
    - rolling update
    - cluster-management
    - multi-tenancy
    - Sveltos
authors:
    - Eleni Grosdouli
---

# All in One: Rollout and Progressive Rollout Example

## Introduction

Navigating through the [rolling update](./rolling_update_strategy.md) or the [progressive rollout](./progressive_rollout.md) documentation, we get a good understanding of how these features work and what the benefits of using them are. However, the power comes when they are combined.

In this example, we will show how to use both features in a single manifest file. We will use the `ClusterPromotion` Custom Resource Definition (CRD) to create a strong deployment and update strategy for applications and add-ons in various environments. We will deploy cert-manager to a group of clusters in various environments: dev, staging, and prod. We will control the deployment by setting the `maxUpdate` field. We will use the `validateHealths` and `PostDelayHealthChecks` fields, which will help us confirm that cert-manager, the necessary `ClusterIssuer`, and the `secret` are available in the cluster.

For simplicity, the manifest file will be split into different parts to provide an explanation of what we have deployed and how it works.

## Benefits

There are many benefits when combining the two features. Below are some of them.

- **No Additional Tools Needed**: Rolling updates and progressive rollouts can be managed without relying on extra tools.
- **Reduced Risk**: Detect problems at an early stage.
- **Simplified Administration**: Configure settings once and let Sveltos manage the process.
- **Health Checks**: Confirm that clusters are ready before proceeding.
- **Staged Deployment**: Gradual rollout changes gradually across different environments.
- **Flexible Control**: Auto or manual promotion.

## Full Manifest Outline

!!! example ""
    ```yaml hl_lines="8 20-34 35-38 48-76"
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterPromotion
    metadata:
      name: cert-manager-rollout-auto
    spec:
      profileSpec:
        syncMode: Continuous
        maxUpdate: 10%
        helmCharts:
        - repositoryURL:    https://charts.jetstack.io
          repositoryName:   jetstack
          chartName:        jetstack/cert-manager
          chartVersion:     v1.19.1
          releaseName:      cert-manager
          releaseNamespace: cert-manager
          helmChartAction:  Install
          values: |
            installCRDs: true
        # Ensure the cert-manager Helm chart has been successfully deployed
        validateHealths:
        - name: deployment-health
          featureID: Helm
          group: "apps"
          version: "v1"
          kind: "Deployment"
          namespace: cert-manager
          script: |
            function evaluate()
              local hs = {healthy = false, message = "available replicas not matching requested replicas"}
              if obj.status and obj.status.availableReplicas ~= nil and obj.status.availableReplicas == obj.spec.replicas then
                hs.healthy = true
              end
              return hs
            end
        # Store the ClusterIssuer and Secret in a ConfigMap
        policyRefs:
        - name: secret-clusterissuer-config
          namespace: default
          kind: ConfigMap
      # Stages are processed sequentially
      stages:
      - name: dev # Stage 1: dev environment
        clusterSelector:
          matchLabels:
            env: dev
        trigger:
          auto:
            delay: 2m # Wait 5 minutes after successful deployment before promoting
            postDelayHealthChecks:
            - name: cert-manager-resources-health
              featureID: Resources
              group: "cert-manager.io"
              version: "v1"
              kind: "ClusterIssuer"
              namespace: cert-manager
              script: |
                function evaluate()
                  hs = {}
                  hs.status = "Degraded"
                  hs.message = "Missing Secret or ClusterIssuer not ready"
                  local secret = getResource("v1", "Secret", "cert-manager", "cloudflare-api-token")
                  local issuerReady = false
                  if obj.status and obj.status.conditions then
                    for _, cond in ipairs(obj.status.conditions) do
                      if cond.type == "Ready" and cond.status == "True" then
                        issuerReady = true
                        break
                      end
                    end
                  end
                  if secret and issuerReady then
                    hs.status = "Healthy"
                    hs.message = "ClusterIssuer and Secret are ready"
                  end
                  return hs
                end
      - name: staging # Stage 2: staging environment
        clusterSelector:
          matchLabels:
            env: staging
        trigger:
          auto:
            delay: 2m # Wait 5 minutes after successful deployment before promoting
      - name: production # Stage 3: Production environment
        clusterSelector:
          matchLabels:
            env: production
        trigger:
          auto:
            delay: 2m # Wait 5 minutes after successful deployment (optional for final stage)
    ```

!!! example "secret-clusterissuer-config"
    ```yaml
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: secret-clusterissuer-config
    data:
      cert-manager-config.yaml: |
        apiVersion: v1
        kind: Secret
        metadata:
          name: cloudflare-api-token
          namespace: cert-manager
        type: Opaque
        stringData:
          api-token: <Cloudflare API token>
        ---
        apiVersion: cert-manager.io/v1
        kind: ClusterIssuer
        metadata:
          name: cloudflare-issuer
        spec:
          acme:
            server: https://acme-staging-v02.api.letsencrypt.org/directory # For production environments, set the URL to https://acme-v02.api.letsencrypt.org/directory
            email: "<Your email address>"
            privateKeySecretRef:
              name: cloudflare-private-key
            solvers:
              - dns01:
                  cloudflare:
                    apiTokenSecretRef:
                      name: cloudflare-api-token
                      key: api-token
    ```

!!!tip
    Deploy the YAML manifest in the Kubernetes **management** cluster where Sveltos is installed.

### Workflow

With `maxUpdate` set to 10%, Sveltos will start the update of 10% of the clusters at a time in each stage (dev, staging, prod). For each cluster, it only moves to the next one after the `validateHealths` checks pass, ensuring the update is successful. Sveltos also does the `postDelayHealthChecks` to ensure the `ClusterIssuer` and `secret` are set up. When all clusters in a stage are updated, the Helm chart is deployed with the specified configuration (ConfigMap). Then, Sveltos moves on to the next stage.

- `validateHealths` and `maxUpdate` show the gradual deployment of an application in all clusters in a given stage
- `postDelayHealthChecks` and `delay` show how we can wait x minutes  and then run a different set of checks

### maxUpdate

The `maxUpdate` field shows the maximum number of clusters that can be updated at the same time. We can set it as a number (like 5) or as a percentage (like 10%). By default, it is 100%. This field lets us control how many clusters get the update at once. If something goes wrong, only a small group of clusters in a stage will be affected, so we can better manage updates.

### validateHealths

The `validateHealths` field lets us set health checks that Sveltos will run before declaring an update as successful. These checks can be written in [Lua](https://www.lua.org/) or [CEL](https://cel.dev/). For this demo, we used Lua to check if the `availableReplicas` in cert-manager match the desired count.

### delay

The field sets an optional wait time after the current stage is fully deployed. Then, it can move on to health checks.

### postDelayHealthChecks

The `postDelayHealthChecks` lets us set logical checks in Lua or CEL. We do this before marking a cluster as successfully deployed.

!!!note
    The `postDelayHealthChecks` have been defined only in the `dev` stage, but we can have this field enabled in every stage of our preference.

## Validation

### During Deployment

```bash
$ kubectl get clusterprofile,clustersummary,clusterpromotion -A
NAME                                                                    AGE
clusterprofile.config.projectsveltos.io/cert-manager-rollout-auto-dev   21s

NAMESPACE   NAME                                                                                  AGE
dev         clustersummary.config.projectsveltos.io/cert-manager-rollout-auto-dev-sveltos-dev01   21s

NAMESPACE   NAME                                                                  AGE
            clusterpromotion.config.projectsveltos.io/cert-manager-rollout-auto   21s
```

```bash
$ kubectl get clusterprofile.config.projectsveltos.io/cert-manager-rollout-auto-dev  -o yaml
...
status:
  matchingClusters:
  - apiVersion: lib.projectsveltos.io/v1beta1
    kind: SveltosCluster
    name: dev01
    namespace: dev
```

```bash
$ kubectl get clustersummary.config.projectsveltos.io/cert-manager-rollout-auto-dev-sveltos-dev01  -n dev -o yaml
...
status:
  dependencies: no dependencies
  deployedGVKs:
  - deployedGroupVersionKind:
    - Secret.v1.
    - ClusterIssuer.v1.cert-manager.io
    featureID: Resources
  featureSummaries:
  - featureID: Resources
    hash: NJRE7kroCo2BfsuIaXUxLezpk0dtbKtiZALjsg1N4HU=
    lastAppliedTime: "2025-11-09T16:56:55Z"
    status: Provisioned
  - featureID: Helm
    hash: B8mlg6lHmj8shmHObpLv+Tr6GJpgWkOh04D80ew3DVI=
    lastAppliedTime: "2025-11-09T16:56:55Z"
    status: Provisioned
  helmReleaseSummaries:
  - releaseName: cert-manager
    releaseNamespace: cert-manager
    status: Managing
    valuesHash: xqLPNIy7HQxDhOK9g2GIj65m4BTZqOHPiiWBzo3Oqm8=
```

### After Deployment

```bash
$ kubectl get clusterpromotion.config.projectsveltos.io/cert-manager-rollout-auto -o yaml
...
status:
  currentStageName: staging
  lastPromotionTime: "2025-11-09T17:02:25Z"
  profileSpecHash: XtxU0+WdS5gofaCkpJZ53zecEQY7AXZLp1CCXWvTltc=
  stages:
  - failureMessage: All matching clusters are successfully deployed.
    lastStatusCheckTime: "2025-11-09T16:58:25Z"
    lastSuccessfulAppliedTime: "2025-11-09T16:58:25Z"
    lastUpdateReconciledTime: "2025-11-09T16:56:25Z"
    name: dev
  - failureMessage: All matching clusters are successfully deployed.
    lastStatusCheckTime: "2025-11-09T17:04:25Z"
    lastSuccessfulAppliedTime: "2025-11-09T17:04:25Z"
    lastUpdateReconciledTime: "2025-11-09T17:02:25Z"
    name: staging
  stagesHash: 9IEZq/BvODcdF+6Ogxjvm+ayNbh/GejSU4RJijXK50s=
```

For more information about the `Automatic` and `Manual` promotion and available fields, have a look at the [ClusterPromotion Types](https://github.com/projectsveltos/addon-controller/blob/main/api/v1beta1/clusterpromotion_types.go).