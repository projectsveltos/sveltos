---
title: Event Driven Addon Distribution - Project Sveltos
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative APIs to deploy Kubernetes add-ons across multiple clusters.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
    - Sveltos
    - event driven
authors:
    - Gianluca Mardente
---

## Referenced Resources

EventTrigger allows you to reference resources within your configuration dynamically. These resources can be referenced from `PolicyRefs` or `ValuesFrom` located in either the `Spec.HelmCharts` or `Spec.KustomizationRefs` sections.
To achieve this dynamic referencing, EventTrigger uses templates. Templates allow you to define placeholders that will be filled with actual values from the cluster at deployment time.

- cluster namespace: `{{ .Cluster.metadata.namespace }}`  This will be replaced with the actual namespace of the cluster.
- cluster name: `{{ .Cluster.metadata.name }}` This will be replaced with the actual name of the cluster.
- cluster type: `{{ .Cluster.kind }}` This will be replaced with the kind of cluster (e.g., "Cluster", "SveltosCluster").

## PolicyRefs Behavior

Sveltos offers a way to dynamically generate policy resources based on events using the `projectsveltos.io/instantiate` annotation. This is particularly useful when the policy content depends on event data:

1. If the resource referenced by EventTrigger has the annotation `projectsveltos.io/instantiate` Sveltos creates a new ConfigMap (or Secret) in the management cluster first. Then, ClusterProfile.Spec.PolicyRefs references this newly created resource.
2. Without `projectsveltos.io/instantiate` annotation, ClusterProfile.Spec.PolicyRefs directly references the resource specified in the EventTrigger.

![projectsveltos.io/instantiate annotation](../assets/instantiate_annotation.png)

Consider a scenario where you want to automatically create a NetworkPolicy whenever a LoadBalancer Service is created in a managed cluster. 
The network-policy ConfigMap referenced by the EventTrigger in this case would have the `projectsveltos.io/instantiate` annotation and its content would be a template like the provided YAML snippet.
This template utilizes placeholders to dynamically generate the NetworkPolicy name and pod selector based on the metadata of the newly created LoadBalancer Service.

```yaml
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: network-policy
      namespace: default
      annotations:
        projectsveltos.io/instantiate: ok # this annotation is what tells Sveltos to instantiate this ConfigMap
    data:
      networkpolicy.yaml: |
        kind: NetworkPolicy
        apiVersion: networking.k8s.io/v1
        metadata:
          name: front-{{ .Resource.metadata.name }}
          namespace: {{ .Resource.metadata.namespace }}
        spec:
          podSelector:
            matchLabels:
              {{ range $key, $value := .Resource.spec.selector }}
              {{ $key }}: {{ $value }}
              {{ end }}
          ingress:
            - from:
              - podSelector:
                  matchLabels:
                    app: internal
              ports:
                {{ range $port := .Resource.spec.ports }}
                - port: {{ $port.port }}
                {{ end }}
```

Sveltos assigns a randomly generated name to the newly created ConfigMap or Secret.

## Generators and TemplateResourceRefs

Imagine a management cluster where each managed cluster has a dedicated ConfigMap storing essential details like server IP:Port and certificate authority data. We want to leverage the event framework to automatically deploy a Secret containing a Kubeconfig whenever a specific ServiceAccount is created in a managed cluster. This Kubeconfig requires the ServiceAccount's token (obtained from the event data), the server IP:Port, and certificate authority data.

The initial approach might be to have an EventTrigger reference a ConfigMap with the `projectsveltos.io/instantiate` annotation. This would involve instantiating the ConfigMap with the ServiceAccount token (from event data) along with the server IP:Port and certificate authority data. However, this is not feasible because the event framework can only access data directly related to the event itself (ServiceAccount creation) and cluster metadata. It lacks the capability to fetch additional resources like the ConfigMap containing server IP:Port and certificate authority data.

While the event framework has limitations, we can effectively address this by utilizing ClusterProfile with [`TemplateResourceRefs`](../template/intro_template.md#templateresourcerefs-namespace-and-name). During deployment, a ClusterProfile can dynamically fetch any resource within the management cluster and incorporate its data into the desired configuration.

Before delving into the YAML configuration, it's essential to grasp a fundamental concept: Generators.

### ConfigMapGenerators and SecretGenerators

EventTriggers can reference ConfigMaps (via `ConfigMapGenerators`) and Secrets (via `SecretGenerators`). The namespace and name of these resources can be defined dynamically using templates, leveraging cluster metadata like namespace, name, and kind.

Upon an event, Sveltos retrieves information from the event itself and the cluster metadata. Similar to the `projectsveltos.io/instantiate` behavior, Sveltos uses this data to dynamically generate (instantiate) the referenced resources within the management cluster.

However, there are two key distinctions between this approach and using the projectsveltos.io/instantiate annotation:

1. *Policy Reference Omission*: The ClusterProfile instance created in response to the event does not reference the newly generated resources within its PolicyRefs section.
2. *Customizable Naming*: Unlike the random naming with projectsveltos.io/instantiate, each generator has a dedicated nameFormat field. This allows you to define a specific naming convention for the generated resources.

### Deep Dive into Configuration

To achieve dynamic Kubeconfig deployment based on ServiceAccount creation events, the following steps are involved:

1. *Event Source Definition*: Define an EventSource to monitor for the creation of Secrets associated with the _tigera-federation-remote-cluster_ ServiceAccount. This ensures that the event framework is triggered only when relevant events occur.
2. *Token Retrieval and Resource Creation*: Upon detecting a qualifying event, the event framework retrieves the token associated with the newly created ServiceAccount. It then generates a resource within the management cluster to store this token (via `ConfigMapGenerators`).
3. *ClusterProfile Generation and References*: The EventTrigger is also configured to create a ClusterProfile in response to the event. This ClusterProfile references both the newly created resource containing the token and the existing ConfigMap with server IP:Port and certificate authority data (in its `TemplateResourceRefs` section).
4. *Resource Fetching and Kubeconfig Deployment*: The ClusterProfile dynamically fetches these referenced resources, extracts the required information, constructs the Kubeconfig, and deploys it to the managed cluster.

```yaml
apiVersion: lib.projectsveltos.io/v1beta1
kind: EventSource
metadata:
  name: tigera-federation-service
spec:
  collectResources: true
  resourceSelectors:
  - group: ""
    version: "v1"
    kind: "Secret"
    namespace: kube-system
    name: tigera-federation-remote-cluster
```

Create an EventTrigger referencing above EventSource. 

```yaml hl_lines="14-24"
apiVersion: lib.projectsveltos.io/v1beta1
kind: EventTrigger
metadata:
  name: tigera-federation-service-cluster-a
spec:
  sourceClusterSelector:
    matchLabels:
      federationid: cluster-a
  destinationClusterSelector:
    matchLabels:
      federationid: cluster-b
  eventSourceName: tigera-federation-service
  oneForEvent: true
  configMapGenerator:
  - name: calico-sa-token-template
    namespace: default
    nameFormat: "{{ .Cluster.metadata.name }}-token"
  templateResourceRefs:
  - resource: # This refers to the resource that Sveltos dynamically generates using ConfigMapGenerator.
      apiVersion: v1
      kind: ConfigMap
      name: "{{ .Cluster.metadata.name }}-token"
      namespace: projectsveltos
    identifier: ConfigDataToken
  - resource: # This is the ConfigMap containing the cluster server IP:Port and cert auth data
      apiVersion: v1
      kind: ConfigMap
      name: "{{ .Cluster.metadata.name }}"
      namespace: "{{ .Cluster.metadata.namespace }}"
    identifier: ConfigData
  policyRefs:
  - name: calico-remote-cluster-config
    namespace: default
    kind: ConfigMap
```

Upon an event, Sveltos retrieves the ConfigMap referenced in the `ConfigMapGenerators` section. It then dynamically populates the ConfigMap content using both cluster metadata (like namespace and name) and event data. This newly generated ConfigMap is placed within the `projectsveltos` namespace.

Since the naming format for the generated ConfigMap is predefined using `{{ .Cluster.metadata.name }}-token`, the EventTrigger leverages `TemplateResourceRefs` to specifically fetch this resource. This ensures efficient retrieval by matching the referenced resource's name with its generated format.

Finally, the ClusterProfile utilizes the content from a ConfigMap referenced in its `PolicyRefs` section. This referenced ConfigMap plays a crucial role in policy generation:

1. *Template-Based Configuration*: The referenced ConfigMap is defined as a template, identifiable by the `projectsveltos.io/template` annotation. This template structure allows for flexible policy configuration.
2. *Dynamic Instantiation with Fetched Data*: Sveltos dynamically instantiates the template content using information retrieved from the resources referenced within the TemplateResourceRefs section (previously fetched resources).

By combining these steps, the ClusterProfile can generate and deploy customized policies based on relevant event data and other resources within the management cluster.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: calico-remote-cluster-config
  namespace: default
  annotations:
    projectsveltos.io/template: "ok"
data:
  secrets.yaml: |
    {{ $token := ((getResource "ConfigDataToken")).data.token }}
    {{ $certauthdata := ((getResource "ConfigData")).data.certauthdata }}
    {{ $server := (( getResource "ConfigData")).data.server }}
    {{ $config := `     apiVersion: v1
      kind: Config
      users:
        - name: tigera-federation-remote-cluster
          user:
            token: %s
      clusters:
        - name: tigera-federation-remote-cluster
          cluster:
            certificate-authority-data: %s
            server: %s
      contexts:
        - name: tigera-federation-remote-cluster-ctx
          context:
            cluster: tigera-federation-remote-cluster
            user: tigera-federation-remote-cluster
      current-context: tigera-federation-remote-cluster-ctx `  }}
    ---
    ---
    apiVersion: v1
    data:
      datastoreType: {{ "kubernetes" | b64enc }}
      kubeconfig: {{ printf $config $token $certauthdata $server | b64enc }}
    kind: Secret
    metadata:
      name: remote-cluster-secret-name
      namespace: (( getResource "ConfigData")).data.namespace
```
