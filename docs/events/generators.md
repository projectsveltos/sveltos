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

EventTrigger references `ConfigMap/Secret` instances. These resources can be referenced by `PolicyRefs` or `ValuesFrom` located in either the `Spec.HelmCharts` or the `Spec.KustomizationRefs` sections.

The *namespace* and the *name* can be defined in two ways:

- **Constant**: A fixed namespace and name, ensuring the same resource is always fetched.
- **Template**: A dynamic expression using templates, allowing different resources to be fetched depending on the specific cluster where the event is detected. When using templates, the following variables are available:
    - **cluster namespace**: `{{ .Cluster.metadata.namespace }}` This will be replaced with the actual namespace of the cluster.
    - **cluster name**: `{{ .Cluster.metadata.name }}` This will be replaced with the actual name of the cluster.
    - **cluster type**: `{{ .Cluster.kind }}` This will be replaced with the kind of cluster (e.g., "Cluster", "SveltosCluster").


## PolicyRefs Behavior

Sveltos offers a way to dynamically generate policy resources based on events using the `projectsveltos.io/instantiate` annotation. This is particularly useful when the policy content depends on event data:

1. If the resource referenced by EventTrigger has the annotation `projectsveltos.io/instantiate` Sveltos creates a new ConfigMap (or Secret) in the management cluster first. Then, ClusterProfile.Spec.PolicyRefs references this newly created resource.
2. Without `projectsveltos.io/instantiate` annotation, ClusterProfile.Spec.PolicyRefs directly references the resource specified in the EventTrigger.

![projectsveltos.io/instantiate annotation](../assets/instantiate_annotation.png)

Consider a scenario where you want to automatically create a NetworkPolicy whenever a LoadBalancer Service is created in a managed cluster.
The network-policy ConfigMap referenced by the EventTrigger in this case would have the `projectsveltos.io/instantiate` annotation and its content would be a template like the provided YAML snippet.
Sveltos will then automatically instantiate the template using the **details** of the `LoadBalancer` Service discovered by each managed cluster.

```yaml hl_lines="6-7 10-29"
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

Consider a scenario where a **management** cluster holds a **Secret** containing critical credentials. Our objective is to **automate** the deployment of the Secret to the **managed** clusters when a namespace with a specific labels is created.

Initially, one might consider an `EventTrigger` pointing to a `ConfigMap` with the `projectsveltos.io/instantiate` annotation. This would aim to populate the ConfigMap with both the qualifying namespaces (obtained from the event) and the credential data. However, this approach is impractical. The event framework's scope is limited to the event's immediate data (the namespaces requiring credentials) and cluster metadata. It cannot retrieve supplementary resources, such as the Secret that contains the actual credential information.

Although the event framework possesses inherent constraints, we can overcome them by employing ClusterProfiles in conjunction with [`TemplateResourceRefs`](../template/intro_template.md#templateresourcerefs-namespace-and-name). This mechanism allows a ClusterProfile to dynamically retrieve any resource residing within the management cluster during deployment, effectively incorporating its data into the intended configuration.

Prior to examining the YAML configuration, it's crucial to understand the foundational concept of Generators.

### ConfigMapGenerators and SecretGenerators

EventTriggers offer the capability to reference ConfigMaps through __ConfigMapGenerators__ and Secrets via __SecretGenerators__. Importantly, the namespace and name of these resources can be dynamically determined using templates, which incorporate cluster metadata such as namespace, name, and kind.

When an event is triggered, Sveltos gathers data from the event itself and the associated cluster metadata. Mirroring the functionality of the `projectsveltos.io/instantiate` annotation, Sveltos leverages this data to dynamically generate (instantiate) a new ConfigMap or Secret within the management cluster.

However, this approach differs significantly from using the projectsveltos.io/instantiate annotation in two critical ways:
First, the ClusterProfile instance created in response to the event does not include references to the newly generated resources within its PolicyRefs section. 
Second, instead of relying on random naming as seen with projectsveltos.io/instantiate, each generator provides a nameFormat field, enabling the definition of a custom naming convention for the generated resources.


### Deep Dive into Configuration: Replicate a Secret on demand

The goal is to dynamically replicate a Secret named __login-credentials__, located in the default namespace of the management Kubernetes cluster, to any namespace within any __production__ cluster that requires it. A namespace's need for these credentials is indicated by the presence of the label `secret: required`.

To achieve a dynamic Secret replication, we will establish a system that reacts to new namespaces requiring credentials. First, an `EventSource` will monitor for namespaces labeled `secret: required` within the production Kubernetes clusters. Upon detecting such a namespace, the system will retrieve its **name** and create a corresponding **resource** in the **management** cluster, storing the information using `ConfigMapGenerator`.

The `EventTrigger` will then generate a `ClusterProfile`. The ClusterProfile will reference both the newly created resource containing the namespace information and the **login-credentials** Secret from the **management** cluster's default namespace. Finally, the ClusterProfile will dynamically fetch the referenced resources, **extract** the necessary data, and **replicate** the **login-credentials** Secret into the identified namespaces within the production clusters.

```yaml
apiVersion: lib.projectsveltos.io/v1beta1
kind: EventSource
metadata:
  name: requiring-credentials
spec:
  collectResources: true
  resourceSelectors:
  - group: ""
    version: "v1"
    kind: "Namespace"
    labelFilters:
    - key: secret
      operation: Equal
      value: required
```

Create an EventTrigger referencing above EventSource.

```yaml hl_lines="14-26"
apiVersion: lib.projectsveltos.io/v1beta1
kind: EventTrigger
metadata:
  name: distribute-credentials
spec:
  sourceClusterSelector:
    matchLabels:
      env: production
  eventSourceName: requiring-credentials
  configMapGenerator: # Generates a ConfigMap named after the cluster, storing the namespaces retrieved by Sveltos from the event data.
  - name: namespaces
    namespace: default
    nameFormat: "{{ .Cluster.metadata.namespace }}-{{ .Cluster.metadata.name }}-namespaces"  
  templateResourceRefs:
  - resource: # This refers to the Secret in the management cluster containing the credentials
      apiVersion: v1
      kind: Secret
      name: login-credentials
      namespace: default
    identifier: Credentials
  - resource: # This refers to the resource that Sveltos dynamically generates using ConfigMapGenerator.
      apiVersion: v1
      kind: ConfigMap
      name: "{{ .Cluster.metadata.namespace }}-{{ .Cluster.metadata.name }}-namespaces"
      namespace: projectsveltos
    identifier: Namespaces
  policyRefs:
  - kind: ConfigMap
    name: info
    namespace: default
```

The referenced ConfigMaps are:

```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: namespaces
  namespace: default
  annotations: # This annotation indicates Sveltos to instantiate it using Event data, i.e, the namespaces requiring the credentials
    projectsveltos.io/instantiate: "true"
data:
  namespaces: |
    {{- range $v := .MatchingResources }}
       {{ $v.Name }}: "ok"
    {{- end }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: info
  namespace: default
  annotations: # This annotation indicates Sveltos the content is a template that needs to be instantiated using resources fetched in TemplateResourceRefs
    projectsveltos.io/template: "true" 
data:
  secret.yaml: |
    {{ $namespaces := ( ( index (getResource "Namespaces").data "namespaces" ) | fromYaml ) }}
    {{- range $key, $value := $namespaces }}
        apiVersion: v1
        kind: Secret
        metadata:
          namespace: {{ $key }}
          name: {{ (getResource "Credentials").metadata.name }}
        data:
          {{- range $secretKey, $secretValue := (getResource "Credentials").data }}
            {{ $secretKey }} : {{ $secretValue }}
          {{- end }}
    ---
    {{- end }}
```

![Sveltos: Distribute Secret](../assets/distribute_secret.gif)


When an event occurs, Sveltos accesses the ConfigMap specified in the __ConfigMapGenerators__ section. It then creates a fresh ConfigMap, populating it with data derived from both the triggering event and the cluster's metadata (such as its namespace and name). 
This newly generated ConfigMap is subsequently stored within the `projectsveltos` namespace.

Since the naming format for the generated ConfigMap is predefined using `{{ .Cluster.metadata.namespace }}-{{ .Cluster.metadata.name }}-namespaces`, the EventTrigger leverages `TemplateResourceRefs` to specifically fetch this resource. This ensures efficient retrieval by matching the referenced resource's name with its generated format.

Finally, the ClusterProfile utilizes the content from a ConfigMap referenced in its `PolicyRefs` section. This referenced ConfigMap plays a crucial role in policy generation:

1. *Template-Based Configuration*: The referenced ConfigMap is defined as a template, identifiable by the `projectsveltos.io/template` annotation. This template structure allows for flexible policy configuration.
2. *Dynamic Instantiation with Fetched Data*: Sveltos dynamically instantiates the template content using information retrieved from the resources referenced within the TemplateResourceRefs section (previously fetched resources).

By combining these steps, the ClusterProfile can generate and deploy customized policies based on relevant event data and other resources within the management cluster.

Imagine a production cluster named __workload__ residing in the __default__ namespace. Within this cluster, two namespaces, __eng__ and __hr__ are labeled __secret: required__. 
Sveltos, upon detecting this, generates a ConfigMap in the "projectsveltos" namespace. This ConfigMap, named <cluster namespace>-<cluster name>-namespaces (in this case, "default-workload-namespaces"), stores the identified namespaces as follows:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  ...
  name: default-workload-namespaces
  namespace: projectsveltos
data:
  namespaces: |
    eng: "ok"
    hr: "ok"
```

The secret is replicated to the `env` and `hr` namespaces.

```bash
$ sveltosctl show addons
+-----------------------------+---------------+-----------+-------------------+---------+-------------------------------+---------------------------------------------+
|           CLUSTER           | RESOURCE TYPE | NAMESPACE |       NAME        | VERSION |             TIME              |                  PROFILES                   |
+-----------------------------+---------------+-----------+-------------------+---------+-------------------------------+---------------------------------------------+
| default/workload            | :Secret       | eng       | login-credentials | N/A     | 2025-02-28 14:23:08 +0100 CET | ClusterProfile/sveltos-lbh9me2lr77gokea2u5u |
| default/workload            | :Secret       | hr        | login-credentials | N/A     | 2025-02-28 14:23:08 +0100 CET | ClusterProfile/sveltos-lbh9me2lr77gokea2u5u |
+-----------------------------+---------------+-----------+-------------------+---------+-------------------------------+---------------------------------------------+
```