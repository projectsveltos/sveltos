---
title: Templates
description: Helm chart values and resources contained in referenced ConfigMaps/Secrets can be defined as template. 
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
    - template
authors:
    - Gianluca Mardente
---

## Introduction to Templates

Sveltos lets you define add-ons and applications using templates. Before deploying to the managed clusters, Sveltos instantiates these templates using information gathered from the management cluster.

### Example - Calico Deployment

Imagine you want to set up Calico CNI on several clusters powered by CAPI, automatically fetching Pod CIDRs from each cluster. Sveltos's ClusterProfile definition lets you create a configuration with these details, and it will automatically deploy Calico to all matching clusters.

In the example below, we use the Sveltos label _env=fv_ to identify all clusters that should use Calico as their CNI.

```yaml
---
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: deploy-calico
spec:
  clusterSelector: env=fv
  helmCharts:
  - repositoryURL:    https://projectcalico.docs.tigera.io/charts
    repositoryName:   projectcalico
    chartName:        projectcalico/tigera-operator
    chartVersion:     v3.24.5
    releaseName:      calico
    releaseNamespace: tigera-operator
    helmChartAction:  Install
    values: |
      installation:
        calicoNetwork:
          ipPools:
          {{ range $cidr := .Cluster.spec.clusterNetwork.pods.cidrBlocks }}
            - cidr: {{ $cidr }}
              encapsulation: VXLAN
          {{ end }}
```

Likewise, you can define any resource contained in a referenced ConfigMap/Secret as a template by adding the `projectsveltos.io/template` annotation. This ensures that the template is instantiated at the time of deployment, making your deployments faster and more efficient.

Sveltos supports the template functions that are included from the [Sprig](https://masterminds.github.io/sprig/) open source project. The Sprig library provides over 70 template functions for Go’s template language. Some of the functions (for the full list please refer to [Sprig repo]([Sprig](https://masterminds.github.io/sprig/))):

1. **String Functions**: trim, wrap, randAlpha, plural, etc.
2. **String List Functions**: splitList, sortAlpha, etc.
3. **Integer Math Functions**: add, max, mul, etc.
4. **Integer Slice Functions**: until, untilStep
5. **Float Math Functions**: addf, maxf, mulf, etc.
6. **Date Functions**: now, date, etc.
7. **Defaults Functions**: default, empty, coalesce, fromJson, toJson, toPrettyJson, toRawJson, ternary
8. **Encoding Functions**: b64enc, b64dec, etc.
9. **Lists and List Functions**: list, first, uniq, etc.
10. **Dictionaries and Dict Functions**: get, set, dict, hasKey, pluck, dig, deepCopy, etc.
11. **Type Conversion Functions**: atoi, int64, toString, etc.
12. **Path and Filepath Functions**: base, dir, ext, clean, isAbs, osBase, osDir, osExt, osClean, osIsAbs
13. **Flow Control Functions**: fail

## Variables

By default, the templates have access to the below managment cluster resources:

1. CAPI Cluster instance. The keyword is `Cluster`
2. CAPI Cluster infrastructure provider. The keyword is `InfrastructureProvider`
3. CAPI Cluster kubeadm provider. The keyword is `KubeadmControlPlane` 
4. For cluster registered with Sveltos, the SveltosCluster instance. The keyword is `Cluster` 

Additionally, Sveltos can fetch any resource from the management cluster. You can set the **templateResourceRefs** in the ClusterProfile/Profile Spec section to instruct Sveltos to do so.

### Example - Autoscaler Definition

#### ClusterProfile

This YAML definition tells Sveltos to find a Secret named _autoscaler_ in the _default_ namespace. Sveltos then makes this Secret available to your template using the keyword _AutoscalerSecret_.

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: deploy-resources
spec:
  clusterSelector: env=fv
  templateResourceRefs:
  - resource:
      apiVersion: v1 
      kind: Secret
      name: autoscaler
      namespace: default
    identifier: AutoscalerSecret
  policyRefs:
  - kind: ConfigMap
    name: info
    namespace: default
```

By adding a special annotation (`projectsveltos.io/template: "true"`) to a ConfigMap named _info_ (also in the _default_ namespace), we can define a template within it.

Here's the template:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: info
  namespace: default
  annotations:
    projectsveltos.io/template: "true"  # add annotation to indicate Sveltos content is a template
data:
  secret.yaml: |
    # AutoscalerSecret now references the Secret default/autoscaler
    apiVersion: v1
    kind: Secret
    metadata:
      name: autoscaler
      namespace: {{ (index .MgmtResources "AutoscalerSecret").metadata.namespace }}
    data:
      token: {{ (index .MgmtResources "AutoscalerSecret").data.token }}
      ca.crt: {{ $data:=(index .MgmtResources "AutoscalerSecret").data }} {{ (index $data "ca.crt") }}
```

 Sveltos will use the content of the _AutoscalerSecret_ to fill in the placeholders when deploying the resources to your managed clusters.

**Please Note:** Sveltos stores information about fetched resources internally using a __map__ data structure. You don't need to worry about the technical details.
To use any resource that Sveltos has found for you, simply use this syntax in your YAML template:

```yaml
(index .MgmtResources "<Identifier>")
```

Replace `<Identifier>` with the name you gave that resource in your ClusterProfile definition (like _AutoscalerSecret_).

This works the same way for Helm charts. Inside the `values` section of your Helm chart, you can reference any data stored in the autoscaler Secret from the _default_ namespace using the same identifier (_AutoscalerSecret_).

### RBAC

Sveltos adhere to the least privilege principle. That means that Sveltos does not have all the necessary permissions to fetch resources from the management cluster by default. Therefore, when using `templateResourceRefs`, you need to provide Sveltos with the correct RBAC.

Providing the necessary RBACs to Sveltos is a straightforward process. The Sveltos' ServiceAccount is tied to the **addon-controller-role-extra** ClusterRole. To grant Sveltos the necessary permissions, simply edit the role.

If the ClusterProfile is created by a tenant administrator as part of a [multi-tenant setup](../features/multi-tenancy-sharing-cluster.md), Sveltos will act on behalf of (impersonate) the ServiceAccount that represents the tenant. This ensures that Kubernetes RBACs are enforced, which restricts the tenant's access to only authorized resources.

### templateResourceRefs: Namespace and Name

When using `templateResourceRefs` to find resources in the management cluster, the namespace field is optional. 

1. If you provide a namespace (like _default_), Sveltos will look for the resource in that specific namespace.
2. Leaving the namespace field blank tells Sveltos to search for the resource in the same namespace as the cluster during deployment.

The name field in `templateResourceRefs` can also be a template. This allows you to dynamically generate names based on information available during deployment.
You can use special keywords like _.ClusterNamespace_ and _.ClusterName_ within the name template to reference the namespace and name of the cluster where the resource is about to be deployed.
For example, the following template will create a name by combining the cluster's namespace and name:

```yaml
name: "{{ .ClusterNamespace }}-{{ .ClusterName }}"
```

## Example - Replicate Secrets with Sveltos

In this scenario, imagine the management cluster has External Secret Operator set up. This operator acts as a bridge, securely fetching secrets from a separate system. These secrets are stored safely within the management cluster.

Now, suppose the following YAML code represents a Secret within the management cluster managed by External Secret Operator:

```yaml
apiVersion: v1
data:
  key1: dmFsdWUx
  key2: dmFsdWUy
kind: Secret
metadata:
  creationTimestamp: "2024-05-27T13:51:00Z"
  name: external-secret-operator
  namespace: default
  resourceVersion: "28731"
  uid: 99411506-8f5e-4846-9628-58f82b3d01be
type: Opaque
```

We want to replicate across all our `production` clusters. Sveltos can automate this process. Here's a step-by-step approach.

We'll first create a ConfigMap named _replicate-external-secret-operator-secret_ in the _default_ namespace. The data section of this ConfigMap will act as a template for deploying the secret.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: replicate-external-secret-operator-secret
  namespace: default
  annotations:
    projectsveltos.io/template: "true"  # add annotation to indicate Sveltos content is a template
data:
  secret.yaml: |
    # This template references the Secret fetched by Sveltos (ESOSecret)
    apiVersion: v1
    kind: Secret
    metadata:
      name: {{ (index .MgmtResources "ESOSecret").metadata.name }}
      namespace: {{ (index .MgmtResources "ESOSecret").metadata.namespace }}
    data:
      {{ range $key, $value := (index .MgmtResources "ESOSecret").data }}
        {{$key}}: {{ $value }}
      {{ end }}
```

- The `projectsveltos.io/template: "true"` annotation tells Sveltos this is a template.
- The template references a placeholder named _ESOSecret_, which will be filled with the actual secret data later.

Next, we'll define a ClusterProfile named _replicate-external-secret-operator-secret_. This profile instructs Sveltos on how to deploy the secrets:

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: replicate-external-secret-operator-secret
spec:
  clusterSelector: env=production
  templateResourceRefs:
  - resource:
      apiVersion: v1 
      kind: Secret
      name: external-secret-operator
      namespace: default
    identifier: ESOSecret
  policyRefs:
  - kind: ConfigMap
    name: replicate-external-secret-operator-secret
    namespace: default
```

- The clusterSelector targets clusters with the label `env=production`.
- The templateResourceRefs section tells Sveltos to fetch the Secret named _external-secret-operator_ from the _default_ namespace. This secret managed by External Secret Operator that holds the actual data we want to replicate.
- The identifier: _ESOSecret_ connects this fetched secret to the placeholder in the template.
- The policyRefs section references the ConfigMap we created earlier, which contains the template for deploying the secret.

By following these steps, Sveltos will automatically deploy the secrets managed by the External Secret Operator to all your production clusters. This ensures consistent and secure access to these secrets across your production environment.

## Example - Autoscaler Dynamic Resource Creation

When deploying add-ons in a managed cluster, there may be a need to first dynamically create resources in the management cluster and then use their values to instantiate add-ons in the managed cluster.

For example, when deploying the `autoscaler` with [ClusterAPI](https://cluster-api.sigs.k8s.io/tasks/automated-machine-management/autoscaling.html), one option is to deploy the autoscaler in the managed cluster and provide it with a Kubeconfig to access the management cluster so it can scale up/down the nodes in the managed cluster using the ClusterAPI resources.

```
Management cluster            Managed cluster
+---------------+             +------------+
| mgmt/workload |             |     ?      |
|               |  kubeconfig | ---------- |
|               |<------------+ autoscaler |
+---------------+             +------------+
```

We want Sveltos to take care of everything. So we instruct Sveltos to perform the following tasks for each managed cluster:

1. Create a ServiceAccount for the autoscaler instance in the management cluster.
2. Deploy the autoscaler in the managed cluster.
3. Pass the autoscaler instance a Kubeconfig associated with the ServiceAccount created in step 1.


### Step 1: Create SA Management Cluster

When a new cluster matches the ClusterProfile's `clusterSelector`, we want Sveltos to automatically create a *ServiceAccount* and a *Secret* for that ServiceAccount in the management cluster. To achieve this, we can reference a ConfigMap containing the necessary resources and set `deploymentType: Local` to instruct Sveltos to deploy the resources in the management cluster.

```yaml
  policyRefs:
  - deploymentType: Local # Content of this ConfigMap will be deployed 
                          # in the management cluster
    kind: ConfigMap
    name: serviceaccount-autoscaler # Contain a template that will be 
                                    # instantiated and deployed in the 
                                    # management cluster
    namespace: default
```

In the above code block, the ConfigMap named `serviceaccount-autoscaler` contains the template for the ServiceAccount and the Secret, which will be deployed in the management cluster. The `deploymentType` is set to `Local` to indicate that the resources should be deployed in the management cluster.

To below the resource above, please remember to [grant Sveltos](#extra-rbacs) permissions to do so.

This ServiceAccount will be given permission to manage MachineDeployment for a specific clusterAPI powered cluster (we are leaving this part out).

### Step 2: Deploy Autoscaler Managed Cluster

When deploying autoscaler in the managed cluster, it is necessary to provide a Kubeconfig associated with the ServiceAccount that was created earlier. This enables the autoscaler running in the managed cluster to communicate with the management cluster and scale up/down the number of machines in the cluster.

To achieve this, the Secret Sveltos created in the management cluster needs to be fetched. We can do this by the use of the below code:

```yaml
  templateResourceRefs:
  - resource:
      kind: Secret
      name: autoscaler
    identifier: AutoscalerSecret
```

**Please Note:** Since we are not specifying the namespace, Sveltos will automatically fetch this Secret from the cluster namespace.

Next, we need to instruct Sveltos to take the content of the ConfigMap secret-info in the default namespace and deploy it to the managed cluster (`deploymentType: Remote`).

```yaml
 - deploymentType: Remote # Content of this ConfigMap will be 
                          # deployed in the managed cluster
    kind: ConfigMap
    name: secret-info # Contain a template that will be instantiated 
                      # and deployed in the managed cluster 
    namespace: default
```

The content of this ConfigMap is a template that uses the information contained in the Secret above:

```yaml
# This ConfigMap contains a Secret whose data section will contain token and ca.crt
# taken from AutoscalerSecret
apiVersion: v1
kind: ConfigMap
metadata:
  name: secret-info
  namespace: default
  annotations:
    projectsveltos.io/template: "true" # indicate Sveltos content of this ConfigMap is a template
data:
  secret.yaml: |
    apiVersion: v1
    kind: Secret
    metadata:
      name: autoscaler
      namespace: {{ (index .MgmtResources "AutoscalerSecret").metadata.namespace }}
    data:
      token: {{ (index .MgmtResources "AutoscalerSecret").data.token }}
      ca.crt: {{ $data:=(index .MgmtResources "AutoscalerSecret").data }} {{ (index $data "ca.crt") }}
```

### Autoscaler All-in-One - YAML Definition

![Dynamically create resource in management cluster](../assets/autoscaler.gif)

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: deploy-resources
spec:
  clusterSelector: env=fv
  templateResourceRefs:
  - resource:
      kind: Secret
      name: autoscaler
    identifier: AutoscalerSecret
  policyRefs:
  - deploymentType: Local # Content of this ConfigMap will be deployed
                          # in the management cluster
    kind: ConfigMap
    name: serviceaccount-autoscaler # Contain a template that will be 
                                    # instantiated and deployed in the management 
                                    # cluster
    namespace: default
  - deploymentType: Remote # Content of this ConfigMap will be deployed in the 
                           # managed cluster
    kind: ConfigMap
    name: secret-info # Contain a template that will be instantiated and deployed
                      # in the managed cluster 
    namespace: default
---
# This ConfigMap contains a ServiceAccount and a Secret for this ServiceAccount.
# Both are expressed as template and use managed cluster namespace/name
apiVersion: v1
kind: ConfigMap
metadata:
  name: serviceaccount-autoscaler
  namespace: default
  annotations:
    projectsveltos.io/template: "true" # indicate Sveltos content of this ConfigMap is a template
data:
  autoscaler.yaml: |
    apiVersion: v1
    kind: ServiceAccount
    metadata:
      name: "{{ .Cluster.metadata.name }}-autoscaler"
      namespace: "{{ .Cluster.metadata.namespace }}"
    ---
    # Secret to get serviceAccount token
    apiVersion: v1
    kind: Secret
    metadata:
      name: autoscaler
      namespace: "{{ .Cluster.metadata.namespace }}"
      annotations:
        kubernetes.io/service-account.name: "{{ .Cluster.metadata.name }}-autoscaler"
    type: kubernetes.io/service-account-token
---
# This ConfigMap contains a Secret whose data section will contain token and ca.crt
# taken from AutoscalerSecret
apiVersion: v1
kind: ConfigMap
metadata:
  name: secret-info
  namespace: default
  annotations:
    projectsveltos.io/template: "true" # indicate Sveltos content of this ConfigMap is a template
data:
  config.yaml: |
    apiVersion: v1
    kind: Secret
    metadata:
      name: autoscaler
      namespace: {{ (index .MgmtResources "AutoscalerSecret").metadata.namespace }}
    data:
      token: {{ (index .MgmtResources "AutoscalerSecret").data.token }}
      ca.crt: {{ $data:=(index .MgmtResources "AutoscalerSecret").data }} {{ (index $data "ca.crt") }}
```

# Learn More About Templates

1. **Helm Charts**: See the "Example: Express Helm Values as Templates" section in [here](../addons/helm_charts.md#example-express-helm-values-as-templates)
2. **YAML & JSON**: refer to the "Example Template with Git Repository/Bucket Content" section in [here](../addons/example_flux_sources.md#example-template-with-git-repositorybucket-content)
1. **Kustomize**: Substitution and templating are explained in this [section](../addons/kustomize.md#substitution-and-templating)