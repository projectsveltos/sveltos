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
Because the values are expressed as a template, Sveltos will dynamically replace the `{{ range ... }}` with the **actual CIDRs** from each target cluster. Calico will get configured with the **correct Pod CIDRs** for every cluster. No manual intervention is required.

!!! example "Example - ClusterProfile Calico Deployment"
    ```yaml hl_lines="18-25"
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

The entire __helmCharts__ section can be defined as a template

!!! example "Example - HelmCharts Section Defined as a Template"
    ```yaml hl_lines="21-24"
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: deploy-kyverno
    spec:
      clusterSelector:
        matchLabels:
          env: fv
      syncMode: Continuous
      templateResourceRefs: # Instruct Sveltos to fetch the Cluster instance so it reacts to **any** Cluster change
      - resource:
          apiVersion: cluster.x-k8s.io/v1beta1
          kind: Cluster
          name: "{{ .Cluster.metadata.name }}"
        identifier: Cluster
      helmCharts:
      - repositoryURL:    https://kyverno.github.io/kyverno/
        repositoryName:   kyverno
        chartName:        kyverno/kyverno
        chartVersion:     |-
          {{$version := index .Cluster.metadata.labels "k8s-version" }}{{if eq $version "v1.29.0"}}v3.2.5
          {{else}}v3.2.6
          {{end}}
        releaseName:      kyverno-latest
        releaseNamespace: kyverno
        helmChartAction:  Install
    ```

## Example - Deploy Kyverno with different replicas

We can define any resource contained in a referenced ConfigMap/Secret as a template by adding the `projectsveltos.io/template` annotation. This ensures that the template is instantiated at the deployment time, making the deployments faster and more efficient.

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
          name: "{{ .Cluster.metadata.name }}"
        identifier: ConfigData
      helmCharts:
      - repositoryURL:    https://kyverno.github.io/kyverno/
        repositoryName:   kyverno
        chartName:        kyverno/kyverno
        chartVersion:     v3.3.3
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

## Using ValuesFrom

The same outcome can be achieved by leveraging Sveltos's `valuesFrom` feature.

!!! example "Example - ClusterProfile Kyverno"
    ```yaml hl_lines="18-20"
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: deploy-kyverno
    spec:
      clusterSelector:
        matchLabels:
          env: demo
      helmCharts:
      - repositoryURL:    https://kyverno.github.io/kyverno/
        repositoryName:   kyverno
        chartName:        kyverno/kyverno
        chartVersion:     v3.3.3
        releaseName:      kyverno-latest
        releaseNamespace: kyverno
        helmChartAction:  Install
        valuesFrom:
        - kind: ConfigMap
          name: "{{ .Cluster.metadata.name }}"
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
        {{ copy "ESOSecret" }}
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

## Example - Replicate CloudConfig with Sveltos

In this scenario, the management cluster manages multiple clusters in a cloud provider. Let's assume the cloud provider for this specific example is Azure. In some setups, there would be a need to put a `cloud-config` Secret with dynamic content inside the managed clusters. We can leverage Sveltos templates for that.

Firstly we need to ensure that ClusterProfile (or Profile) has additional elements in `templateResourceRefs`, and `policies` defined:

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
          apiVersion: infrastructure.cluster.x-k8s.io/v1beta1
          kind: AzureClusterIdentity
          name: azure-cluster-identity
        identifier: InfrastructureProviderIdentity
      - resource:
          apiVersion: v1
          kind: Secret
          name: azure-cluster-identity-secret
        identifier: InfrastructureProviderIdentitySecret
      policyRefs:
      - kind: ConfigMap
        name: azure-cloud-provider
        namespace: default
    ```

We expose additional `InfrastructureProviderIdentity` and `InfrastructureProviderIdentitySecret` for templating purposes, and the `azure-cloud-provider` ConfigMap defined in policyRefs will be our template for pushing the `cloud-config` Secret to the managed clusters.

!!! example "Example - CloudConfig template"
    ```yaml
    ---
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: azure-cloud-provider
      namespace: default
      annotations:
        projectsveltos.io/template: "true"
    data:
      configmap.yaml: |
        {{- $cluster := .InfrastructureProvider -}}
        {{- $identity := (getResource "InfrastructureProviderIdentity") -}}
        {{- $secret := (getResource "InfrastructureProviderIdentitySecret") -}}
        {{- $subnetName := "" -}}
        {{- $securityGroupName := "" -}}
        {{- $routeTableName := "" -}}
        {{- range $cluster.spec.networkSpec.subnets -}}
          {{- if eq .role "node" -}}
            {{- $subnetName = .name -}}
            {{- $securityGroupName = .securityGroup.name -}}
            {{- $routeTableName = .routeTable.name -}}
            {{- break -}}
          {{- end -}}
        {{- end -}}
        {{- $cloudConfig := dict
          "aadClientId" $identity.spec.clientID
          "aadClientSecret" (index $secret.data "clientSecret" |b64dec)
          "cloud" $cluster.spec.azureEnvironment
          "loadBalancerName" ""
          "loadBalancerSku" "Standard"
          "location" $cluster.spec.location
          "maximumLoadBalancerRuleCount" 250
          "resourceGroup" $cluster.spec.resourceGroup
          "routeTableName" $routeTableName
          "securityGroupName" $securityGroupName
          "securityGroupResourceGroup" $cluster.spec.networkSpec.vnet.resourceGroup
          "subnetName" $subnetName
          "subscriptionId" $cluster.spec.subscriptionID
          "tenantId" $identity.spec.tenantID
          "useInstanceMetadata" true
          "useManagedIdentityExtension" false
          "vmType" "vmss"
          "vnetName" $cluster.spec.networkSpec.vnet.name
          "vnetResourceGroup" $cluster.spec.networkSpec.vnet.resourceGroup
        -}}
        ---
        apiVersion: v1
        kind: Secret
        metadata:
          name: azure-cloud-provider
          namespace: kube-system
        type: Opaque
        data:
          cloud-config: {{ $cloudConfig | toJson |b64enc }}
        ---
        apiVersion: v1
        kind: ConfigMap
        metadata:
          name: dump-cluster-sveltos-object
          namespace: default
        data:
          object: |
            {{ .Cluster | toYaml | nindent 4 }}
    ```

Note that we have 2 objects that are going to be created inside managed clusters via templating. `azure-cloud-provider` is the actual `cloud-config` that we need, and `dump-cluster-sveltos-object` is referenced here for illustrative purposes and can be used for debugging the template itself (seeing what values the reference object contains).

It's worth mentioning also that template rendering status can be seen in the related `ClusterSummary` object status, this helps a lot in developing template script.
