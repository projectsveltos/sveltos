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

# Rolling Update Strategy for ClusterProfiles

A ClusterProfile might match more than one cluster. When adding or modifying a ClusterProfile, it is helpful to:

- Incrementally add the new configuration to a few clusters at a time.
- Validate health before declaring deployment successful in a given managed cluster.

To support this, Sveltos has two ClusterProfile Spec fields: `MaxUpdate` and `ValidateHealths`.

## MaxUpdate

Indicates the maximum number of clusters that can be updated concurrently. Value can be an absolute number (e.g., 5) or a percentage of desired managed clusters (e.g., 10%). Defaults to 100%.

Example: When this field is set to 30%, when the list of add-ons/applications in ClusterProfile changes, only 30% of matching clusters will be updated in parallel. Only when updates in those clusters succeed will other matching clusters be updated.

## ValidateHealths

A slice of health validation expressed using the Lua language.

For instance, when deploying Helm charts, it is possible to instruct Sveltos to check deployment health (number of active replicas) before declaring the Helm chart deployment successful.

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

Above instructs Sveltos to fetch all deployments in the kyverno namespace. For each one of those, the Lua script is evaluated.

The `validateHealths` field in a ClusterProfile Spec allows you to specify health validation checks that Sveltos should perform before declaring an update successful. These checks are expressed using the Lua language.

The Lua function must be named `evaluate`. It is passed a single argument, which is an instance of the object being validated (`obj`). The function must return a struct containing a field `healthy`, which is a boolean indicating whether the resource is healthy or not. The struct can also have an optional field `message`, which will be reported back by Sveltos if the resource is not healthy.

## Benefits of a Rolling Update Strategy

A rolling update strategy allows you to update your clusters gradually, minimizing downtime and risk. By updating a few clusters at a time, you can identify and resolve any issues before rolling out the update to all of your clusters. Additionally, you can use the ValidateHealths field to ensure that your clusters are healthy before declaring the update successful.

## How to Use the Rolling Update Strategy

To use the rolling update strategy, simply set the MaxUpdate field in your ClusterProfile Spec to the desired number of clusters to update concurrently. You can also use the ValidateHealths field to specify any health validation checks that you want to perform.

For example, the following ClusterProfile Spec would update a maximum of 30% of matching clusters concurrently and would check that the number of active replicas for all deployments in the kyverno namespace is matches the requested replicas before declaring the update successful:

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: kyverno
spec:
  clusterSelector: env=fv
  syncMode: Continuous
  maxUpdate: 30%
  helmCharts:
  - repositoryURL:    https://kyverno.github.io/kyverno/
    repositoryName:   kyverno
    chartName:        kyverno/kyverno
    chartVersion:     v3.0.1
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

## Verify your Lua script

To verify your Lua script without a cluster, you can follow these steps:

- Clone [addon-controller](https://github.com/projectsveltos/addon-controller) repo
- Navigate to the `controllers/health_policies/deployment_health directory`: ```cd controllers/health_policies/deployment_health```
- create a directory ```mkdir my_script```
- Create a new file named `lua_policy.lua` in the directory you just created, and add your `evaluate` function to it.
- Create a new file named `valid_resource.yaml` in the same directory, and add a healthy resource to it. This is a resource that your evaluate function should evaluate to healthy.
- Create a new file named `invalid_resource.yaml` in the same directory, and add a non-healthy resource to it. This is a resource that your evaluate function should evaluate to false.
- Run the following command to build and run the unit tests: ```make ut```

If the unit tests pass, then your Lua script is valid.
