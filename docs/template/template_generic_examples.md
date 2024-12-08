---
title: Templates Generic Examples
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

## Template Generic Examples

This section is designed to help users get started with the Sveltos template feature. It provides simple, easy-to-follow examples. Let's dive in!

## Example - Calico CNI Deployment

Imagine we want to set up Calico CNI on several CAPI powered clusters, **automatically** fetching **Pod CIDRs** from each cluster. Sveltos `ClusterProfile` definition lets you create a configuration with these details, and it will **automatically** deploy Calico to all **matching** clusters.

In the example below, we use the Sveltos cluster label `env=fv` to identify all clusters that should use Calico as their CNI.

!!! example "Example - ClusterProfile Calico Deployment"
    ```yaml
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: deploy-calico
    spec:
      clusterSelector:
        matchSelector:
          env: fv
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

Likewise, we can define any resource contained in a referenced ConfigMap/Secret as a template by adding the `projectsveltos.io/template` annotation. This ensures that the template is instantiated at the deployment time, making the deployments faster and more efficient.

## Example - Deploy Kyverno with different replicas

For this example, we have two Civo clusters already registered with Sveltos. The clusters are the **Sveltos managed clusters**.

```
$ kubectl get sveltoscluster -n civo --show-labels
NAME       READY   VERSION        LABELS
cluster1   true    v1.29.2+k3s1   env=demo,projectsveltos.io/k8s-version=v1.29.2
cluster2   true    v1.29.2+k3s1   env=demo,projectsveltos.io/k8s-version=v1.29.2
```

We also have two `ConfigMap` resources.

```
$ kubectl get configmap -n civo                   
NAME               DATA   AGE
cluster1           1      43m
cluster2           1      43m
```

The content of the ConfigMap with the name `civo/cluster1` can be found below.

!!! example "Example - ConfigMap cluster1 Definition"
    ```yaml
    ---
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: cluster1
      namespace: civo
    data:
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

The content of the ConfigMap with the `civo/cluster2` can be found below.

!!! example "Example - ConfigMap cluster2 Definition"
    ```yaml
    ---
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: cluster2
      namespace: civo
    data:
      values: |
        admissionController:
          replicas: 1
        backgroundController:
          replicas: 1
        cleanupController:
          replicas: 1
        reportsController:
          replicas: 1
    ```

Once we are happy with the configuration, we can proceed further with the Sveltos `ClusterProfile` resources. Have a look at the YAML definitions below.

!!! example "Example - ClusterProfile Kyverno"
    ```yaml
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: deploy-kyverno
    spec:
      clusterSelector:
        matchLabels:
          env: demo
      templateResourceRefs:
      - resource:
          apiVersion: v1
          kind: ConfigMap
          name: "{{ .ClusterName }}"
        identifier: ConfigData
      helmCharts:
      - repositoryURL:    https://kyverno.github.io/kyverno/
        repositoryName:   kyverno
        chartName:        kyverno/kyverno
        chartVersion:     v3.1.4
        releaseName:      kyverno-latest
        releaseNamespace: kyverno
        helmChartAction:  Install
        values: |
          {{ (getResource "ConfigData").data.values }}
    ```

The `ClusterProfile` above will deploy **Kyverno** with **_3_** replicas on `cluster1`.

```
$ KUBECONFIG=civo-cluster1-kubeconfig kubectl get deployments -n kyverno
NAME                            READY   UP-TO-DATE   AVAILABLE   AGE
kyverno-background-controller   3/3     3            3           15m
kyverno-reports-controller      3/3     3            3           15m
kyverno-cleanup-controller      3/3     3            3           15m
kyverno-admission-controller    3/3     3            3           15m
```

The `ClusterProfile` for `cluster02` will deploy **Kyverno** with **_1_** replicas.

```
$ KUBECONFIG=civo-cluster2-kubeconfig kubectl get deployments -n kyverno
NAME                            READY   UP-TO-DATE   AVAILABLE   AGE
kyverno-reports-controller      1/1     1            1           17m
kyverno-background-controller   1/1     1            1           17m
kyverno-cleanup-controller      1/1     1            1           17m
kyverno-admission-controller    1/1     1            1           17m
```

## Example - Autoscaler Definition

### ClusterProfile

The below YAML definition instruct Sveltos to find a Secret named _autoscaler_ in the _default_ namespace. Sveltos makes the Secret available to the template using the keyword _AutoscalerSecret_.

!!! example "Example - ClusterProfile Resource Definition"
    ```yaml
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: deploy-resources
    spec:
      clusterSelector:
        matchLabels:
          env: fv
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

By adding the special annotation (`projectsveltos.io/template: "true"`) to a ConfigMap named _info_ (also in the _default_ namespace), we can define a template within it. Find the example template below.

!!! example "Example - ConfigMap Definition"
    ```yaml
    ---
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
          namespace: {{ (getResource "AutoscalerSecret").metadata.namespace }}
        data:
          token: {{ (getResource "AutoscalerSecret").data.token }}
          ca.crt: {{ $data:=(getResource "AutoscalerSecret").data }} {{ (index $data "ca.crt") }}
    ```

Sveltos will use the content of the _AutoscalerSecret_ to fill in the placeholders when deploying the resources to your managed clusters.

!!! tip
    Sveltos stores information about fetched resources internally using a __map__ data structure. For more technical details, feel free to get in touch via [Slack](https://projectsveltos.slack.com/join/shared_invite/zt-1hraownbr-W8NTs6LTimxLPB8Erj8Q6Q#/shared-invite/email).

To use any resource that Sveltos has found based on the defintion, simply use the syntax below in the YAML template:

```yaml
(getResource "<Identifier>")
```

Replace `<Identifier>` with the name you gave that resource in your ClusterProfile definition (like _AutoscalerSecret_).

This works the same way for Helm charts. Inside the `values` section of the Helm chart, we can reference any data stored in the autoscaler Secret from the _default_ namespace using the same identifier (_AutoscalerSecret_).

## Example - Replicate Secrets with Sveltos

In this scenario, imagine the management cluster has an **External Secret Operator** set up. The operator acts as a bridge, securely fetching secrets from a separate system. The secrets are stored safely within the management cluster.

Suppose the following YAML code represents a Secret **within** the **management cluster** managed by External Secret Operator.

!!! example "Example - Secret Definition"
    ```yaml
    ---
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

Firstly, we create a `ConfigMap` named _replicate-external-secret-operator-secret_ in the _default_ namespace. The data section of this ConfigMap will act as a template for deploying the secret.

!!! example "Example - ConfigMap Definition"
    ```yaml
    ---
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
          name: {{ (getResource "ESOSecret").metadata.name }}
          namespace: {{ (getResource "ESOSecret").metadata.namespace }}
        data:
          {{ range $key, $value := (getResource "ESOSecret").data }}
            {{$key}}: {{ $value }}
          {{ end }}
    ```

- The `projectsveltos.io/template: "true"` annotation tells Sveltos this is a template
- The template references a placeholder named _ESOSecret_, which will be filled with the actual secret data later

Next, we will define a `ClusterProfile` named _replicate-external-secret-operator-secret_. The profile instructs Sveltos on how to deploy the secrets:

!!! example "Example - ClusterProfile Resources Definition"
    ```yaml
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: replicate-external-secret-operator-secret
    spec:
      clusterSelector:
        matchLabels:
          env: production
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

- The clusterSelector targets clusters with the label `env=production`
- The templateResourceRefs section tells Sveltos to fetch the Secret named _external-secret-operator_ from the _default_ namespace. This secret managed by External Secret Operator that holds the actual data we want to replicate
- The identifier: _ESOSecret_ connects this fetched secret to the placeholder in the template
- The policyRefs section references the ConfigMap we created earlier, which contains the template for deploying the secret

By following the steps above, Sveltos will automatically deploy the secrets managed by the External Secret Operator to all your production clusters. This ensures consistent and secure access to these secrets across your production environment.

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

1. Create a ServiceAccount for the autoscaler instance in the management cluster
1. Deploy the autoscaler in the managed cluster
1. Pass the autoscaler instance a Kubeconfig associated with the ServiceAccount created in step 1


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

!!! note
    Since we are not specifying the namespace, Sveltos will automatically fetch this Secret from the cluster namespace.

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

!!! example "Example - ConfigMap Definition"
    ```yaml
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
      secret.yaml: |
        apiVersion: v1
        kind: Secret
        metadata:
          name: autoscaler
          namespace: {{ (getResource "AutoscalerSecret").metadata.namespace }}
        data:
          token: {{ (getResource "AutoscalerSecret").data.token }}
          ca.crt: {{ $data:=(getResource "AutoscalerSecret").data }} {{ (index $data "ca.crt") }}
    ```

### Autoscaler All-in-One - YAML Definition

![Dynamically create resource in management cluster](../assets/autoscaler.gif)

!!! example "Example - Autoscaler Deployment"
    ```yaml
    ---
    apiVersion: config.projectsveltos.io/v1beta11
    kind: ClusterProfile
    metadata:
      name: deploy-resources
    spec:
      clusterSelector:
        matchLabels:
          env: fv
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
          namespace: {{ (getResource "AutoscalerSecret").metadata.namespace }}
        data:
          token: {{ (getResource "AutoscalerSecret").data.token }}
          ca.crt: {{ $data:=(getResource "AutoscalerSecret").data }} {{ (index $data "ca.crt") }}
    ```
