---
title: Sveltos - Kubernetes Add-on Compliance Controller | Load and Enforce Add-on Compliance
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative APIs to deploy Kubernetes add-ons across multiple clusters.
tags:
    - Kubernetes
    - add-ons
    - compliance
authors:
    - Gianluca Mardente
---

## What is Kubernetes add-on compliance

Kubernetes add-on compliance refers to the process of ensuring that all Kubernetes add-ons within a cluster meet the specific security and compliance requirements of an organization.

## Kubernetes add-on compliance with Projectsveltos

Sveltos is a tool that facilitates the deployment of Kubernetes add-ons across multiple clusters. It supports various deployment methods such as Helm charts, Kustomize resources, and YAML files. Add-ons can be sourced from different locations.

When programmatically deploying add-ons using Sveltos, it is crucial to ensure that the deployed add-ons adhere to specific compliance requirements. These requirements may differ depending on the cluster, with production clusters typically having more stringent requirements compared to test clusters.

Sveltos enables the definition of compliance requirements[^2] for a group of clusters and enforces those requirements for all add-ons deployed to those clusters. It employs Lua to enforce compliance:

1. [Lua](https://www.lua.org): Lua is a scripting language that can be used to execute arbitrary code. Sveltos can use Lua to write custom compliance checks. For example, Sveltos could be configured to check that all deployments have a corresponding HorizontalPodAutoscaler.

By using Lua, Sveltos provides a comprehensive solution for enforcing Kubernetes add-on compliance[^1]. This helps organizations in ensuring that their Kubernetes clusters are both secure and compliant with industry regulations and standards.

Here are some additional benefits of using Sveltos to enforce Kubernetes add-on compliance:

1. Scalability: Sveltos can be used to manage compliance for a large number of clusters.
2. Flexibility: Sveltos supports a variety of deployment methods and compliance requirements.
3. Ease of use: Sveltos is easy to use and configure.

## AddonComplaince CRD

A new Custom Resource Definition is introduced: [AddonCompliance](https://raw.githubusercontent.com/projectsveltos/libsveltos/main/api/v1alpha1/addoncompliance_type.go).

Here is an example:

```yaml
apiVersion: lib.projectsveltos.io/v1alpha1
kind: AddonCompliance
metadata:
 name: depl-replica
spec:
  clusterSelector: env=production
  luaValidationRefs:
  - namespace: default
    name: depl-horizontalpodautoscaler
    kind: ConfigMap
```

Above instance is definining a set of compliances (contained in the referenced ConfigMap) which needs to be enforced in any managed cluster matching the clusterSelector field.
ClusterSelector field is just a pure Kubernetes label selector. So any cluster with label `env: production` will be a match.

The referenced ConfigMap contains a Lua validation. 

### ConfigMap with a Lua policy

```yaml
apiVersion: lib.projectsveltos.io/v1alpha1
kind: AddonCompliance
metadata:
 name: depl-replica
spec:
  clusterSelector: env=production
  luaValidationRefs:
  - namespace: default
    name: depl-horizontalpodautoscaler
    kind: ConfigMap
```

Following ConfigMap contains an Lua policy enforcing that any deployment in the __foo__ namespace has an associated __HorizontalPodAutoscaler__

```yaml
apiVersion: v1
data:
  lua.yaml: |
    function evaluate()
        local hs = {}
        hs.valid = true
        hs.message = ""

        local deployments = {}
        local autoscalers = {}

        -- Separate deployments and services from the resources
        for _, resource in ipairs(resources) do
            local kind = resource.kind
            if resource.metadata.namespace == "foo" then
                if kind == "Deployment" then
                    table.insert(deployments, resource)
                elseif kind == "HorizontalPodAutoscaler" then
                    table.insert(autoscalers, resource)
                end
            end
        end

        -- Check for each deployment if there is a matching HorizontalPodAutoscaler
        for _, deployment in ipairs(deployments) do
            local deploymentName = deployment.metadata.name
            local matchingAutoscaler = false

            for _, autoscaler in ipairs(autoscalers) do
                if autoscaler.spec.scaleTargetRef.name == deployment.metadata.name then
                    matchingAutoscaler = true
                    break
                end
            end

            if not matchingAutoscaler then
                hs.valid = false
                hs.message = "No matching autoscaler found for deployment: " .. deploymentName
                break
            end
        end

        return hs
    end
kind: ConfigMap
metadata:
  name: depl-horizontalpodautoscaler
  namespace: default
```

## Sveltos implementation details

There are two main components involved:

1. The Sveltos addon-controller: It is responsible for deploying add-ons to managed clusters. You can find more information about it on the [addon-controller GitHub page](https://github.com/projectsveltos/addon-controller).
2. The Sveltos addon-compliance-controller: It is responsible for identifying all the compliances for each cluster. More details can be found on the [addon-compliance-controller GitHub page](https://github.com/projectsveltos/addon-compliance-controller).

These two controllers work together using a synchronization mechanism. When a new cluster is created, the controllers ensure that all the existing compliances for that cluster are discovered before any add-on is deployed.

When Sveltos needs to deploy an add-on in a managed cluster, it follows these steps:

1. It collects all the compliances currently associated with the cluster.
1. It validates each resource against the current compliances one by one.
1. If a resource fails to satisfy any of the compliances, an error is thrown, and the corresponding error is reported.
1. Finally validates all resources together against all Lua compliance policies.

![Add-on compliances in action](assets/addon_compliance.gif)


```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: kyverno
spec:
  clusterSelector: env=production
  syncMode: Continuous
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
```

An error is reported back


Changing the replicas to 3, will make sure Kyverno helm chart satisfies all compliances and helm chart is deployed:

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: kyverno
spec:
  clusterSelector: env=production
  helmCharts:
  - chartName: kyverno/kyverno
    chartVersion: v3.0.1
    helmChartAction: Install
    releaseName: kyverno-latest
    releaseNamespace: kyverno
    repositoryName: kyverno
    repositoryURL: https://kyverno.github.io/kyverno/
    values: |
      admissionController:
        replicas: 3
      backgroundController:
        replicas: 3
      cleanupController:
        replicas: 3
      reportsController:
        replicas: 3
```

```bash
➜  addon-controller git:(dev) ✗ kubectl exec -it -n projectsveltos  sveltosctl-0    -- /sveltosctl show addons
+-------------------------------------+---------------+-----------+----------------+---------+-------------------------------+------------------+
|               CLUSTER               | RESOURCE TYPE | NAMESPACE |      NAME      | VERSION |             TIME              | CLUSTER PROFILES |
+-------------------------------------+---------------+-----------+----------------+---------+-------------------------------+------------------+
| default/sveltos-management-workload | helm chart    | kyverno   | kyverno-latest | 3.0.1   | 2023-06-14 02:57:12 -0700 PDT | kyverno          |
+-------------------------------------+---------------+-----------+----------------+---------+-------------------------------+------------------+
```

## Choosing this Approach over Using an Admission Controller

Let's explore the advantages of choosing this approach instead of relying on an admission controller like Kyverno or OPA.

One immediate benefit is that you won't need to deploy additional services in your managed clusters. By opting for this approach, you can simplify your cluster architecture and reduce the complexity associated with extra services.

However, there are more significant advantages to consider:

1. **Synchronization without Hassle**: When using an admission controller, you must ensure that no add-ons are deployed until the controller is up and running. This requires a synchronization mechanism to ensure everything is in order. With this approach, Sveltos takes care of this for you. When a new cluster is discovered, the add-on controller patiently waits for the add-on compliance controller to load all existing compliances specific to that cluster. This guarantees a smooth and orderly deployment process.
2. **Consistency in Resource Deployment**: Another important aspect is the behavior regarding resource deployment. In the case of an Helm chart, it often deploys multiple resources together. With this approach, a strict rule applies: either all resources are valid and satisfy the existing compliances, or none of them are deployed. This ensures consistency and avoids partial or incomplete deployments, providing a reliable and predictable deployment process.

By considering these advantages, you can make an informed decision when choosing between this approach and utilizing an admission controller for your cluster management and add-on deployment needs.

## Validating your Lua policies

If you want to validate your Lua policies:

1. clone sveltos addon-controller repo: git clone  git@github.com:projectsveltos/addon-controller.git
2. cd controllers/validate_lua
3. Create your own directory within the `validate_lua` directory. Inside this directory, create the following files:
- `lua_policy.yaml`: This file should contain your Lua policy.
- `valid_resource.yaml`: This file should contain the resources that satisfy the Lua policy.
- `invalid_resource.yaml`: This file should contain the resources that do not satisfy the Lua policy.
4. run `make test` from repo directory.


Running `make test` will initiate the validation process, which thoroughly tests your Lua policies against the provided resource files. This procedure ensures that your defined policy is not only syntactically correct but also functionally accurate. By executing the validation tests, you can gain confidence in the correctness and reliability of your policies written in Lua.
By following these steps, you can easily validate your Lua policies using the Sveltos addon-controller repository.

[^1]: If your clusters use mutating webhooks, you should carefully consider whether Sveltos add-on compliance will be effective for you. This is because Sveltos cannot see what mutating webhooks do, so it cannot guarantee that your clusters will be compliant. 

[^2]: Helm charts containing both CustomResourceDefinitions and instances of such CRDs cannot be deployed on clusters where compliance validations where defined. This is because helm dry run won't return full list of resources the helm chart would deploy and so Sveltos won't be able to validate.
