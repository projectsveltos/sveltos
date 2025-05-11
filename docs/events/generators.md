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

# Templating

**EventTrigger**  is a Kubernetes resource that enables dynamic, event-driven configuration management across clusters by automatically creating ClusterProfiles in response to specific events.

When an event matches the conditions defined in an EventTrigger, it generates a tailored ClusterProfile—automating the application of add-ons, policies, or configurations based on real-time changes in your environment. The resulting ClusterProfile can include:

1. **TemplateResourceRefs**
2. **PolicyRefs**
3. **HelmCharts**
4. **KustomizationRefs**

## Instantiation Flow: TemplateResourceRefs

EventTrigger uses its own __spec.templateResourceRefs__ to generate the spec.templateResourceRefs field in the resulting ClusterProfile.

The namespace and name fields within each reference can be either constants or templates. When templates are used, they are dynamically evaluated using data from the triggering cluster or resource—allowing the generated ClusterProfile to be context-aware and tailored to the specific event.

Examples include:

- `{{ .Cluster.metadata.name }}`
- `{{ .Resource.metadata.annotations.env }}`
- `{{ printf "%s-%s" .Cluster.metadata.labels.region .Resource.metadata.name }}`

These templates are resolved at runtime, enabling the system to generate tailored ClusterProfiles based on the specific context of each event.

For instance, if the EventTrigger.spec.templateResourceRefs is defined as:

```yaml
templateResourceRefs:
  - kind: ConfigMap
    namespace: "platform-config"
    name: "{{ .Cluster.metadata.labels.region }}-{{ .Resource.metadata.annotations.env }}"
```

And the triggering cluster has the following metadata:

```yaml
metadata:
  name: cluster-west-1
  labels:
    region: us-west
```

And the resource that generated the event has this metadata:

```yaml
metadata:
  name: nginx-addon
  annotations:
    env: prod
```

Then the resulting ClusterProfile.spec.templateResourceRefs will be:

```yaml
templateResourceRefs:
  - kind: ConfigMap
    namespace: "platform-config"
    name: "us-west-prod"
```

## Instantiation Flow: PolicyRefs

EventTrigger can reference ConfigMaps and Secrets in its **policyRefs** section, with two different behaviors depending on the presence of specific annotations on the referenced resources. The process follows this flow:

**Dynamic Namespaces and Names**: The namespace and name fields in the referenced ConfigMaps or Secrets can be expressed as templates, just like in templateResourceRefs. These templates are dynamically evaluated using the data from the triggering cluster and event resource.

For example, the namespace and name can be defined as:

```yaml
policyRefs:
  - kind: ConfigMap
    namespace: "{{ .Cluster.metadata.labels.region }}"
    name: "{{ .Resource.metadata.name }}-config"
```

The namespace and name templates are first instantiated based on the data from the triggering cluster and resource. This means any field from the cluster or resource (e.g., metadata.labels, metadata.name, metadata.annotations, etc.) can be used to dynamically define the namespace/name of the target resource.
For instance, with a triggering cluster having a label `region=eu-central` and a resource named `ingress-addon`, the final namespace and name would be:

```yaml
policyRefs:
  - kind: ConfigMap
    namespace: eu-central
    name: ingress-addon-config
```

After instantiation, EventTrigger fetches the corresponding ConfigMap or Secret based on the dynamically instantiated namespace and name.

The next step depends on the annotations present on the ConfigMap or Secret:
1. Without the __projectsveltos.io/instantiate__ annotation: The ClusterProfile will directly reference the fetched ConfigMap or Secret. If the resource has the __projectsveltos.io/template__ annotation, it will be instantiated by the addon-controller at deployment time using the cluster’s context.
2. With the __projectsveltos.io/instantiate__ annotation: EventTrigger will instantiate the ConfigMap or Secret using the cluster and event data. The ClusterProfile will reference this newly created, context-aware resource, rather than the original one.

For instance, EventTrigger.spec.policyRefs references a ConfigMap with templated namespace and name:

```yaml
policyRefs:
  - kind: ConfigMap
    namespace: "{{ .Cluster.metadata.labels.region }}"
    name: "{{ .Resource.metadata.name }}-config"
```

with triggering cluster metadata:

```yaml
metadata:
  labels:
    region: eu-central
```

and triggering resource metadata:

```yaml
metadata:
  name: ingress-addon
```

the instantiated namespace and name become:

```yaml
namespace: eu-central
name: ingress-addon-config
```

Sveltos fetches the ConfigMap at `eu-central/ingress-addon-config` and processes it based on its annotations:

- If `projectsveltos.io/instantiate` is not present, ClusterProfile spec.profileRefs will reference this one.
- If `projectsveltos.io/instantiate` is present, the ConfigMap is instantiated by EventTrigger using the cluster/event data, and the ClusterProfile references this new resource.

```yaml hl_lines="6-7 10-29"
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: network-policy
      namespace: default
      annotations:
        projectsveltos.io/instantiate: ok # this annotation is what tells Sveltos to instantiate this ConfigMap in the event context
    data:
      networkpolicy.yaml: |
        kind: NetworkPolicy
        apiVersion: networking.k8s.io/v1
        metadata:
          name: front-{{ .Resource.metadata.name }}
          namespace: {{ .Cluster.metadata.namespace }}
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

This approach enables context-aware policy injection based on dynamically generated resource names, enhancing automation and flexibility in multi-cluster operations.

![projectsveltos.io/instantiate annotation](../assets/instantiate_annotation.png)

## Instantiation Flow: Helm Charts

In EventTrigger, the `spec.helmCharts` field defines which Helm charts should be applied when an event occurs. Each Helm chart entry can be specified in two ways:

1. Constant – A fixed chart definition (e.g., chart name, repo, values, version).
2. Template – A dynamic chart definition using Go templates, which are instantiated using data from the triggering cluster and/or event resource.

When Helm chart fields (such as name, version, or values) are defined as templates, EventTrigger evaluates them at runtime using the cluster and resource metadata that triggered the event. The resulting chart specification is then included in the generated ClusterProfile, which uses these instantiated Helm chart definitions.

Let’s say your EventTrigger.spec.helmCharts is defined as:

```yaml
helmCharts:
  - releaseName: my-namespace
    chartName: example
    repositoryURL: https://charts.example.com
    version: "1.0.0"
    values: |
      env: "{{ .Resource.metadata.annotations.env }}"
      region: "{{ .Cluster.metadata.labels.region }}"
```

And the triggering context is cluster:

```yaml
metadata:
  name: cluster-east
  labels:
    region: us-east
```

and a resource:

```yaml
metadata:
  name: nginx-deployment
  annotations:
    env: staging
```

so EventTrigger will instantiate it using the provided cluster and resource data:

```yaml
helmCharts:
  - releaseName: my-namespace
    chartName: example
    repositoryURL: https://charts.example.com
    version: "1.0.0"
    values: |
      env: staging
      region: us-east
```


The generated ClusterProfile will then include this instantiated Helm chart under its own spec.helmCharts, ensuring that a region- and environment-specific configuration is deployed.

This templating capability makes Helm chart deployments flexible and context-aware, enabling dynamic customization for different clusters or triggering resources—all managed declaratively.

In addition to inline values, each Helm chart defined in EventTrigger.spec.helmCharts can use the **valuesFrom** field to reference external ConfigMaps or Secrets that contain Helm values.
These references support templated namespace and name fields, just like in policyRefs. This allows the source of values to be determined dynamically based on the triggering cluster and resource.
The namespace and name of the referenced ConfigMap/Secret in valuesFrom are first instantiated using templates. These templates can access any field from the triggering cluster or resource.

```yaml
valuesFrom:
  kind: ConfigMap
  namespace: "{{ .Cluster.metadata.labels.region }}"
  name: "{{ .Resource.metadata.annotations.env }}-helm-values"
```

After instantiating the namespace and name, the referenced ConfigMap or Secret is fetched.

- If the resource does not have the `projectsveltos.io/instantiate` annotation: The generated ClusterProfile.spec.helmCharts.valuesFrom will reference the same ConfigMap or Secret.
- If the resource has the `projectsveltos.io/instantiate` annotation: Sveltos instantiates the content of the ConfigMap/Secret using the cluster and event data. A new ConfigMap/Secret is generared with the instantiated value. The generated ClusterProfile.spec.helmCharts.valuesFrom will reference the newly created ConfigMap or Secret.

The same logic applies to EventTrigger.spec.kustomizationRefs—fields can be constant or templated, and when templated, they are instantiated using cluster and resource data. The resulting definitions are then included in the generated ClusterProfile.

## Generators

**ConfigMapGenerator** and **SecretGenerator** let you capture data from the resource that triggered an event (which only the EventTrigger has access to), package it into a new ConfigMap or Secret, and pass that resource downstream to the addon-controller via a predictable reference.

This mechanism bridges the gap between the event context and the addon deployment, enabling event-aware configurations even after the EventTrigger hands off to the addon-controller.

### Why This Matters

The EventTrigger has access to the triggering resource (e.g., a custom resource or namespace).
The addon-controller does not have access to the event or resource that caused the EventTrigger to fire.

If you want to use data from that resource (e.g., labels, annotations, spec fields) during addon deployment, you need to make that data available in a resource the addon-controller can read.
That’s where ConfigMapGenerator and SecretGenerator come in: they materialize resource data into real Kubernetes resources that the ClusterProfile can reference.

### How It Works: Step by Step

EventTrigger detects an event, like the creation of a custom resource.
It uses a ConfigMapGenerator/SecretGenerator to create a new ConfigMap/Secret, embedding selected fields from the triggering resource using templates.

#### Fetch Source ConfigMap
Sveltos first evaluates the name and namespace fields to locate the template ConfigMap.

```yaml
configMapGenerator:
  - name: "{{ .Resource.metadata.name }}-source-config" # name can also use cluster data
    namespace: "{{ .Resource.metadata.namespace }}" # namespace can also use cluster data
    nameFormat: "{{ .Cluster.metadata.namespace }}-{{ .Cluster.metadata.name }}-{{ .Resource.metadata.name }}-generated"
```

For example, suppose the event resource is:

```yaml
metadata:
  name: workload
  namespace: apps
```

Then Sveltos fetches ConfigMap:

```yaml
name: workload-source-config
namespace: apps
```

#### Resolve nameFormat for Output

Sveltos computes the final name for the new ConfigMap using both Cluster and Resource fields.
If the cluster is:

```yaml
metadata:
  name: team-a
  namespace: prod
```

Then the generated name is `prod-team-a-workload-generated`.

#### Instantiate Content

The data section of the fetched ConfigMap (workload-source-config) is treated as a Go template.
Sveltos renders it using full access to:

1. **.Cluster** fields
2. **.Resource** fields
3. **.MatchingResources** metadata

#### Create Final ConfigMap

A new ConfigMap is created with:

- Name: prod-team-a-workload-generated
- Namespace: projectsveltos
- Content: rendered using live cluster/resource data

This generated ConfigMap will be referenced by the auto-generated ClusterProfile—typically via the spec.templateResourceRefs—so that its content can be consumed during add-on or policy deployment.

### Deep Dive into Configuration: Replicate a Secret on demand

The goal is to dynamically replicate a Secret named __login-credentials__, present in the default namespace of the management Kubernetes cluster, to any namespace within any __production__ cluster that requires it. A namespace's need for these credentials is indicated by the presence of the label `secret: required`.

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

Imagine a production cluster named __workload__ residing in the __default__ namespace. Within this cluster, two namespaces, __eng__ and __hr__ are labeled __secret: required__.
 Sveltos, upon detecting this, generates a ConfigMap in the "projectsveltos" namespace. This ConfigMap, named `<cluster namespace>-<cluster name>-namespaces` (in this case, _default-workload-namespaces_), stores the identified namespaces as follows:

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