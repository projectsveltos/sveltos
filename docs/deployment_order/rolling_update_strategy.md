---
title: ClusterProfile Rolling Update Strategy
description: Sveltos rolling update strategy allows to update managed clusters gradually, minimizing downtime and risk.
tags:
    - Kubernetes
    - add-ons
    - rolling update
    - clusterapi
    - multi-tenancy
authors:
    - Gianluca Mardente
---

## ClusterProfile Rolling Update Strategy

A ClusterProfile might match more than one clusters. When adding or modifying a ClusterProfile, it is helpful to:

- Incrementally add a new configuration to a few clusters at a time.
- Validate the health of the deployment before declaring it successful.

To support this, Sveltos uses two `ClusterProfile Spec` fields: `MaxUpdate` and `ValidateHealths`.

### MaxUpdate

`MaxUpdate` indicates the maximum number of clusters that can be updated concurrently. The value can be an absolute number (e.g., 5) or a percentage of the desired managed clusters (e.g., 10%). The default vlue is set to 100%.

#### Example

When the field is set to 30%, the list of add-ons/applications in ClusterProfile changes, only 30% of the matching clusters will be updated in parallel. Only when the updates in these clusters succeed, it will proceed with the update of the remaining clusters

### ValidateHealths

The `validateHealths` field in a ClusterProfile Spec allows you to specify health validation checks that Sveltos should perform before declaring an update successful. These checks are expressed using the Lua language.

#### Example

For instance, when deploying Helm charts, it is possible to instruct Sveltos to check the deployments health (number of active replicas) before declaring the Helm chart deployment successful.

```yaml
validateHealths:
- name: deployment-health
  featureID: Helm
  group: "apps"
  version: "v1"
  kind: "Deployment"
  namespace: kyverno
  script: |
    function evaluate()
      hs = {}
      hs.healthy = false
      hs.message = "available replicas not matching requested replicas"
      if obj.status ~= nil then
        if obj.status.availableReplicas ~= nil then
          if obj.status.availableReplicas == obj.spec.replicas then
            hs.healthy = true
          end
        end
      end
      return hs
    end
```

The above YAML definition instructs Sveltos to fetch all the deployments in the kyverno namespace. For each of those, the Lua script is evaluated.

The Lua function must be named `evaluate`. It is passed as a single argument, which is an instance of the object being validated (`obj`). The function must return a struct containing a field `healthy`, which is a boolean indicating whether the resource is healthy or not. The struct can also have an optional field `message`, which will be reported back by Sveltos if the resource is not healthy.

## Rolling Update Strategy Benefits

A rolling update strategy allows you to update your clusters gradually, minimizing downtime and risk. By updating a few clusters at a time, you can identify and resolve any issues before rolling out the update to all of your clusters. Additionally, you can use the ValidateHealths field to ensure that your clusters are healthy before declaring the update successful.

## All in One: Example Rolling Update Strategy

To use the rolling update strategy, simply set the `MaxUpdate` field in the ClusterProfile Spec to the desired number of clusters to update concurrently. You can also use the `ValidateHealths` field to specify any health validation checks that you want to perform.

The following ClusterProfile Spec would update a maximum of 30% of matching clusters concurrently, and would check that the number of active replicas for all deployments in the kyverno namespace matche the requested replicas before declaring the update successful.

!!! example "Example ClusterProfile - Kyverno - Lua"
    ```yaml
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: kyverno
    spec:
      clusterSelector:
        matchLabels:
          env: fv
      syncMode: Continuous
      maxUpdate: 30%
      helmCharts:
      - repositoryURL:    https://kyverno.github.io/kyverno/
        repositoryName:   kyverno
        chartName:        kyverno/kyverno
        chartVersion:     v3.3.3
        releaseName:      kyverno-latest
        releaseNamespace: kyverno
        helmChartAction:  Install
        values: |
          admissionController:
            replicas: 1
      validateHealths:
      - name: deployment-health
        featureID: Helm
        group: "apps"
        version: "v1"
        kind: "Deployment"
        namespace: kyverno
        script: |
          function evaluate()
            hs = {}
            hs.healthy = false
            hs.message = "available replicas not matching requested replicas"
            if obj.status ~= nil then
              if obj.status.availableReplicas ~= nil then
                if obj.status.availableReplicas == obj.spec.replicas then
                  hs.healthy = true
                end
              end
            end
            return hs
          end
    ```

### Manual Verification Lua Script

To verify the Lua script without a cluster, you can follow steps pointers.

1. Clone [addon-controller](https://github.com/projectsveltos/addon-controller) repo
2. Navigate to the `controllers/health_policies/deployment_health directory`: ```cd controllers/health_policies/deployment_health```
3. Create a directory ```mkdir my_script```
4. Create a new file named `lua_policy.lua` in the directory you just created, and add your `evaluate` function to it.
5. Create a new file named `valid_resource.yaml` in the same directory, and add a healthy resource to it. This is a resource that your evaluate function should evaluate to healthy.
6. Create a new file named `invalid_resource.yaml` in the same directory, and add a non-healthy resource to it. This is a resource that your evaluate function should evaluate to false.
7. Run the following command to build and run the unit tests: ```make ut```

!!! tip
    If the unit tests pass, the Lua script is valid.
