---
title: Sveltos - Kubernetes Add-on Controller | Manage Kubernetes Add-ons with Ease
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative APIs to deploy Kubernetes add-ons across multiple clusters.
tags:
    - Kubernetes
    - add-ons
    - helm
    - kustomize
    - clusterapi
    - multi-tenancy
    - Sveltos
authors:
    - Gianluca Mardente
---
## Profiles

[Profile](https://github.com/projectsveltos/sveltos-manager/blob/main/api/v1beta1/profile_types.go "Profile to manage Kubernetes add-ons") is the CustomerResourceDefinition used to instruct Sveltos which add-ons to deploy on a set of clusters. 

Profile is a namespace-scoped resource.  It can only match clusters and reference resources within its own namespace.

### Spec.ClusterSelector 

*clusterSelector* field selects a set of managed clusters where listed add-ons and applications will be deployed.
Only cluster in the same namespace can be a match.

```yaml
  clusterSelector:
    matchLabels:
      env: prod
```

### Spec.HelmCharts

*helmCharts* field consists of a list of helm charts to be deployed to the clusters matching clusterSelector;

```yaml
  helmCharts:
  - repositoryURL:    https://kyverno.github.io/kyverno/
    repositoryName:   kyverno
    chartName:        kyverno/kyverno
    chartVersion:     v3.2.5
    releaseName:      kyverno-latest
    releaseNamespace: kyverno
    helmChartAction:  Install
```

### Spec.PolicyRefs

*policyRefs* field references a list of ConfigMaps/Secrets, each containing Kubernetes resources to be deployed in the clusters matching clusterSelector.

This field is a slice of *PolicyRef* structs. Each PolictRef has the following fields:

- *Kind*: The kind of the referenced resource. The supported kinds are Secret and ConfigMap.
- *Namespace*: The namespace of the resource being referenced. This field is automatically set to the namespace of the Profile instance. In other words, a Profile instance can only reference resources that are within its own namespace.
- *Name*: The name of the referenced resource. This field must be at least one character long.
- *DeploymentType*: The deployment type of the referenced resource. This field indicates whether the resource should be deployed to the management cluster (local) or the managed cluster (remote). The default value is Remote.

```yaml
policyRefs:
- kind: Secret
  name: my-secret-1
  namespace: my-namespace-1
  deploymentType: Local
- kind: Remote
  name: my-configmap-1
  namespace: my-namespace-1
  deploymentType: Remote
```

### Spec.KustomizationRefs
*kustomizationRefs* field is a list of sources containing kustomization files. Resources will be deployed in the clusters matching the clusterSelector specified. 

This field is a slice of *KustomizationRef* structs. Each KustomizationRef has the following fields:

- *Kind*: The kind of the referenced resource. The supported kinds are:
    
    - flux GitRepository, OCIRepository, Bucket: These kinds represent resources that store Kustomization manifests.
    - ConfigMap, Secret: These kinds represent resources that contain Kustomization manifests or overlays.

- *Namespace*: The namespace of the resource being referenced. This field is automatically set to the namespace of the Profile instance. In other words, a Profile instance can only reference resources that are within its own namespace.
- *Name*: The name of the referenced resource. This field must be at least one character long.
- *Path*: The path to the directory containing the kustomization.yaml file, or the set of plain YAMLs for which a kustomization.yaml should be generated. This field is optional and defaults to None, which means the root path of the SourceRef.
- *TargetNamespace*: The target namespace for the Kustomization deployment. This field is optional and can be used to override the namespace specified in the kustomization.yaml file.
- *DeploymentType*: The deployment type of the referenced resource. This field indicates whether the Kustomization deployment should be deployed to the management cluster (local) or the managed cluster (remote). The default value is Remote.

### Spec.SyncMode

This field can be set to:

- *OneTime*
- *Continuous*
- *ContinuousWithDriftDetection*
- *DryRun*

Let's take a closer look at the *OneTime* syncMode option. Once you deploy a Profile with a OneTime configuration, Sveltos will check all of your clusters for a match with the clusterSelector. Any matching clusters will have the resources specified in the Profile deployed. However, if you make changes to the Profile later on, those changes will not be automatically deployed to already-matching clusters.

Now, if you're looking for real-time deployment and updates, the *Continuous* syncMode is the way to go. With Continuous, any changes made to the Profile will be immediately reconciled into matching clusters. This means that you can add new features, update existing ones, and remove them as necessary, all without lifting a finger. Sveltos will deploy, update, or remove resources in matching clusters as needed, making your life as a Kubernetes admin a breeze.

*ContinuousWithDriftDetection* instructs Sveltos to monitor the state of managed clusters and detect a configuration drift for any of the resources deployed because of that Profile.
When Sveltos detects a configuration drift, it automatically re-syncs the cluster state back to the state described in the management cluster.
To know more about configuration drift detection, refer to this [section](../features/configuration_drift.md).

Imagine you're about to make some important changes to your Profile, but you're not entirely sure what the results will be. You don't want to risk causing any unwanted side effects, right? Well, that's where the *DryRun* syncMode configuration comes in. By deploying your Profile with this configuration, you can launch a simulation of all the operations that would normally be executed in a live run. The best part? No actual changes will be made to the matching clusters during this dry run workflow, so you can rest easy knowing that there won't be any surprises. 
To know more about dry run, refer to this [section](../features/dryrun.md).

### Spec.StopMatchingBehavior

The *stopMatchingBehavior* field specifies the behavior when a cluster no longer matches a Profile. By default, all Kubernetes resources and Helm charts deployed to the cluster will be removed. However, if StopMatchingBehavior is set to *LeavePolicies*, any policies deployed by the Profile will remain in the cluster.

For instance 

!!! example "Example - Profile Kyverno Deployment"
    ```yaml
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: Profile
    metadata:
      name: kyverno
      namespace: eng
    spec:
      stopMatchingBehavior: WithdrawPolicies
      clusterSelector:
        matchLabels:
          env: prod
      helmCharts:
      - repositoryURL:    https://kyverno.github.io/kyverno/
        repositoryName:   kyverno
        chartName:        kyverno/kyverno
        chartVersion:     v3.0.1
        releaseName:      kyverno-latest
        releaseNamespace: kyverno
        helmChartAction:  Install
    ```

When a cluster matches the Profile, Kyverno Helm chart will be deployed in such a cluster. If the cluster's labels are subsequently modified and cluster no longer matches the Profile, the Kyverno Helm chart will be uninstalled. However, if the *stopMatchingBehavior* property is set to *LeavePolicies*, Sveltos will retain the Kyverno Helm chart in the cluster.

### Spec.Reloader

The *reloader* property determines whether rolling upgrades should be triggered for Deployment, StatefulSet, or DaemonSet instances managed by Sveltos and associated with this Profile when changes are made to mounted ConfigMaps or Secrets.
When set to true, Sveltos automatically initiates rolling upgrades for affected Deployment, StatefulSet, or DaemonSet instances whenever any mounted ConfigMap or Secret is modified. This ensures that the latest configuration updates are applied to the respective workloads.

Please refer to this [section](../features/rolling_upgrade.md) for more information.

### Spec.MaxUpdate

A Profile might match more than one cluster. When a change is maded to a Profile, by default all matching clusters are update concurrently.
The *maxUpdate* field specifies the maximum number of Clusters that can be updated concurrently during an update operation triggered by changes to the Profile's add-ons or applications.
The specified value can be an absolute number (e.g., 5) or a percentage of the desired cluster count (e.g., 10%). The default value is 100%, allowing all matching Clusters to be updated simultaneously.
For instance, if set to 30%, when modifications are made to the Profile's add-ons or applications, only 30% of matching Clusters will be updated concurrently. Updates to the remaining matching Clusters will only commence upon successful completion of updates in the initially targeted Clusters. This approach ensures a controlled and manageable update process, minimizing potential disruptions to the overall cluster environment.
Please refer to this [section](../addons/rolling_update_strategy.md) for more information.

### Spec.ValidateHealths

The *validateHealths* property defines a set of Lua functions that Sveltos executes against the managed cluster to assess the health and status of the add-ons and applications specified in the Profile. These Lua functions act as validation checks, ensuring that the deployed add-ons and applications are functioning properly and aligned with the desired state. By executing these functions, Sveltos proactively identifies any potential issues or misconfigurations that could arise, maintaining the overall health and stability of the managed cluster.

The ValidateHealths property accepts a slice of Lua functions, where each function encapsulates a specific validation check. These functions can access the managed cluster's state to perform comprehensive checks on the add-ons and applications. The results of the validation checks are aggregated and reported back to Sveltos, providing valuable insights into the health and status of the managed cluster's components.

Lua's scripting capabilities offer flexibility in defining complex validation logic tailored to specific add-ons or applications.
 
Please refer to this [section](../addons/rolling_update_strategy.md) for more information.

Consider a scenario where a new cluster with the label env:prod is created. The following instructions guide Sveltos to:

- Deploy Kyverno Helm chart;
- Validate Deployment Health: Perform health checks on each deployment within the kyverno namespace. Verify that the number of active replicas matches the requested replicas;
- Successful Deployment: Once the health checks are successfully completed, Sveltos considers the Profile as successfully deployed.

!!! example "Example - Profile Kyverno and Lua"
    ```yaml
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: Profile
    metadata:
      name: kyverno
      namespace: eng
    spec:
      clusterSelector:
        matchLabels:
          env: prod
      helmCharts:
      - repositoryURL:    https://kyverno.github.io/kyverno/
        repositoryName:   kyverno
        chartName:        kyverno/kyverno
        chartVersion:     v3.0.1
        releaseName:      kyverno-latest
        releaseNamespace: kyverno
        helmChartAction:  Install
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

### Spec.TemplateResourceRefs

The *templateResourceRefs* property specifies a collection of resources to be gathered from the management cluster. The values extracted from these resources will be utilized to instantiate templates embedded within referenced PolicyRefs and Helm charts.
Refer to [template](../template/template_generic_examples.md) section for more info and examples.

### Spec.DependsOn

The *dependsOn* property specifies a list of other Profiles that this instance relies on. In any managed cluster that matches to this Profile, the add-ons and applications defined in this instance will only be deployed after all add-ons and applications in the designated dependency Profiles have been successfully deployed.

For example, profile-a can depend on another *profile-b*. This implies that any Helm charts or raw YAML files associated with CProfile A will not be deployed until all add-ons and applications specified in Profile B have been successfully provisioned.

```yaml
---
apiVersion: config.projectsveltos.io/v1beta1
kind: Profile
metadata:
  name: profile_a
  namespace: eng
spec:
  dependsOn:
  - profile_b
```
