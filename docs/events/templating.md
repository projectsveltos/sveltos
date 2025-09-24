---
title: Events Templating - Project Sveltos
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative APIs to deploy Kubernetes add-ons across multiple clusters.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
    - Sveltos
    - Events
    - Templating
authors:
    - Gianluca Mardente
---

## Introduction to Events and Templating

**EventTrigger** is a Kubernetes resource that enables **dynamic**, **event-driven** configuration management across clusters by automatically creating Sveltos ClusterProfiles in response to specific events.

When an event matches all conditions defined in an EventTrigger, it generates a tailored Sveltos ClusterProfile, automating the application of add-ons, policies, or configurations based on real-time changes in an environment.

The resulting ClusterProfile can include the following fields, all of which can be expresssed as templates within the EventTrigger and instantiated by Sveltos during the generation process:

1. **TemplateResourceRefs**
1. **PolicyRefs**
1. **HelmCharts**
1. **KustomizationRefs**

!!! note
    This [template functions](../template/intro_template.md#template-functions) are available.

The following resources are available for instantiation if the `EventTrigger` has `oneForEvent` set to `true`.

| Name | Meaning | Availability |
| :--- | :--- | :--- |
| **MatchingResource** | A reference to the resource that triggered the event, including its **apiVersion**, **kind**, **name**, and **namespace**. | Always available |
| **Resource** | The full Kubernetes resource that triggered the event. All of its fields, including `.spec` and `.status`, are available for templating. | Only if `collectResource` is set to `true` in the `EventSource`. |
| **CloudEvent** | The raw CloudEvent that triggered the `EventTrigger`. |  Only if the event was a NATS.io event. |
| **Cluster** | The `SveltosCluster` or CAPI Cluster instance where the event occurred. | Always available |

### Instantiation Flow: TemplateResourceRefs

The EventTrigger __TemplateResourceRefs__ is instantiated using resource data and set to __ClusterProfile.Spec.TemplateResourceRefs__.

The `namespace` and `name` fields within each reference can be **constants** or **templates**. The templates are dynamically evaluated using data from the **triggering cluster** or **resource**, allowing the generated ClusterProfile to be context-aware and tailored to a specific event.

Usage Example:

- `{{ .Cluster.metadata.name }}`
- `{{ .Resource.metadata.annotations.env }}`
- `{{ printf "%s-%s" .Cluster.metadata.labels.region .Resource.metadata.name }}`
- `{{ .MatchingResource.Name }}`

!!! note
    The templates are resolved at **runtime**. It allows systems to generate tailored Sveltos ClusterProfiles based on the specific context of each event.

!!! example "Example: EventTrigger.spec.templateResourceRefs"

    **EventTrigger.spec.templateResourceRefs Details**

    ```yaml
    templateResourceRefs:
      - kind: ConfigMap
        namespace: "platform-config"
        name: "{{ .Cluster.metadata.labels.region }}-{{ .Resource.metadata.annotations.env }}"
    ```

    **Triggering Cluster Details**

    ```yaml
    metadata:
      name: cluster-west-1
      labels:
        region: us-west
    ```

    **Resource that Generated Event Details**

    ```yaml
    metadata:
      name: nginx-addon
      annotations:
        env: prod
    ```

    **Resulting ClusterProfile.spec.templateResourceRefs Details**

    ```yaml
    templateResourceRefs:
      - kind: ConfigMap
        namespace: "platform-config"
        name: "us-west-prod"
    ```

### Instantiation Flow: PolicyRefs

EventTrigger can reference `ConfigMaps` and `Secrets` in the __policyRefs__ section.

Users can express `ConfigMaps/Secret` resources as templates. These are dynamically evaluated using the data from the triggering cluster and event resource.

!!! Example "Example: Dynamic policyRefs"

    We can express the `policyRefs` section as a template like the example below.

    ```yaml
    policyRefs:
      - kind: ConfigMap
        namespace: "{{ .Cluster.metadata.labels.region }}"
        name: "{{ .Resource.metadata.name }}-config"
    ```

    The template values will be first instantiated based on the data from the triggering cluster and resource. For example, if the triggering cluster contains the label `region=eu-central` and a resource is named `ingress-addon`, the final `policyRefs` section will look like the below.

    ```yaml
    policyRefs:
      - kind: ConfigMap
        namespace: eu-central
        name: ingress-addon-config
    ```

After instantiation, EventTrigger fetches the corresponding `ConfigMap/Secret` based on the dynamically instantiated `namespace` and `name`.

Once fetched, Sveltos handles ConfigMap and Secret resources in two distinct ways, depending on specific annotations:

1. If the resource does not have the annotation __projectsveltos.io/instantiate__ set, the generated Sveltos ClusterProfile will directly reference the same fetched `ConfigMap/Secret` resource. If the annotation __projectsveltos.io/template__ is set, the Sveltos addon controller will first instantiate the resource (meaning it will process any templates within it) before deploying it to any matching clusters.
1. If a resource has the __projectsveltos.io/instantiate__ annotation, the EventTrigger component will be responsible for creating a new ConfigMap or Secret. It will use the event resource's data along with information from the managed cluster where the event occurred. The resulting Sveltos ClusterProfile will then reference this newly instantiated `ConfigMap/ Secret`.


!!! Example "Example: EventTrigger.spec.policyRefs"

    **EventTrigger.spec.policyRefs Template Details**

    ```yaml
    policyRefs:
      - kind: ConfigMap
        namespace: "{{ .Cluster.metadata.labels.region }}"
        name: "{{ .Resource.metadata.name }}-config"
    ```

    **Triggering Cluster Details**

    ```yaml
    metadata:
      labels:
        region: eu-central
    ```

    **Resource that Generated Event Details**

    ```yaml
    metadata:
      name: ingress-addon
    ```

    **Instantiated Namespace and Name Details**

    ```yaml
    namespace: eu-central
    name: ingress-addon-config
    ```

    Sveltos fetches the ConfigMap at `eu-central/ingress-addon-config` and processes it based on its annotations.

    - If `projectsveltos.io/instantiate` is absent, the Sveltos ClusterProfile __spec.profileRefs__ will reference this one.
    - If `projectsveltos.io/instantiate` is present, the `ConfigMap` is instantiated by the EventTrigger using the cluster/event data, and the Sveltos ClusterProfile references this new resource.

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

The approach enables context-aware policy injection based on dynamically generated resource names, enhancing automation and flexibility in multi-cluster operations.

![projectsveltos.io/instantiate annotation](../assets/instantiate_annotation.png)

### Instantiation Flow: Helm Charts

In EventTrigger, the `spec.helmCharts` field defines which Helm charts should be applied when an event occurs. Each Helm chart entry can be defined in two ways.

1. **Constant**: A fixed chart definition (e.g., chart name, repo, values, version).
1. **Template**: A dynamic chart definition using Go templates, which are instantiated using data from the triggering cluster and/or event resource.

When Helm chart fields (such as name, version, or values) are defined as templates, EventTrigger evaluates them at runtime using the cluster and resource metadata that triggered the event. The resulting Helm chart specification is included in the generated Sveltos ClusterProfile, which uses these instantiated Helm chart definitions.

!!! Example "Example: EventTrigger.spec.helmCharts"

    **EventTrigger.spec.helmCharts Details**

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

    **Triggering Cluster Details**

    ```yaml
    metadata:
      name: cluster-east
      labels:
        region: us-east
    ```

    **Resource that Generated Event Details**

    ```yaml
    metadata:
      name: nginx-deployment
      annotations:
        env: staging
    ```

    **Resulting ClusterProfile.spec.helmCharts Details**

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

The templating capability makes Helm chart deployments **flexible** and **context-aware**, enabling dynamic customisation for different clusters or triggering resources, all managed declaratively.

Additionally, each Helm chart defined in __EventTrigger.spec.helmCharts__ can use the **valuesFrom** field to reference external `ConfigMaps/Secrets` that contain Helm values. These references support templated namespace and name fields, just like in `policyRefs`.

!!! Example "Example: Dynamic EventTrigger.spec.helmCharts.valuesFrom"

    The `namespace` and `name` of the referenced `ConfigMap/Secret` in __valuesFrom__ are first instantiated using templates. These templates can access any field from the triggering cluster or resource.

    ```yaml
    valuesFrom:
      kind: ConfigMap
      namespace: "{{ .Cluster.metadata.labels.region }}"
      name: "{{ .Resource.metadata.annotations.env }}-helm-values"
    ```

    After instantiation, the referenced `ConfigMap/Secret` is fetched.

- If the resource does not have the `projectsveltos.io/instantiate` annotation, the generated `ClusterProfile.spec.helmCharts.valuesFrom` will reference the same `ConfigMap/Secret`.
- If the resource has the `projectsveltos.io/instantiate` annotation, Sveltos instantiates the content of the `ConfigMap/Secret` using the **cluster** and **event data**. A new `ConfigMap/Secret` is generated with the instantiated value. The generated `ClusterProfile.spec.helmCharts.valuesFrom` will reference the newly created `ConfigMap/Secret`.

The same logic applies to __EventTrigger.spec.kustomizationRefs—fields__.

### Instantiation Flow: ClusterProfile Name

By default, the _ClusterProfile_ instances created by the event framework are assigned random names. While this is acceptable for most use cases, a predictable name is required in scenarios where other resources must be set as dependent on the instantiated ClusterProfile. The random naming convention makes it impossible to reference these instances programmatically.

To address this challenge, the EventTrigger _spec_ includes an optional field: `InstantiatedProfileNameFormat`. This field allows for the definition of a naming template that ensures a predictable name is generated for the ClusterProfile instance. The name is consistently formatted based on a Go template and can leverage data from the cluster and the specific event that triggered the creation.

 In the example below, the template uses the cluster name and the name of the resource that triggered the event.

`{{ .Cluster.metadata.name }}-{{ .Resource.metadata.name }}-test`

When an event is triggered, Sveltos will automatically apply this template. For example, if the event occurs in a cluster named _cluster-alpha_ and is triggered by a resource named _pod-nginx_, the resulting ClusterProfile will be named: _cluster-alpha-pod-nginx-test_.

### Template Functions

Sveltos supports the template functions included from the [Sprig](https://masterminds.github.io/sprig/) open source project. The Sprig library provides over **70 template functions** for Go’s template language. Some of the functions are listed below. For the full list, have a look at the Spring Github page.

1. **String Functions**: trim, wrap, randAlpha, plural, etc.
1. **String List Functions**: splitList, sortAlpha, etc.
1. **Integer Math Functions**: add, max, mul, etc.
1. **Integer Slice Functions**: until, untilStep
1. **Float Math Functions**: addf, maxf, mulf, etc.
1. **Date Functions**: now, date, etc.
1. **Defaults Functions**: default, empty, coalesce, fromJson, toJson, toPrettyJson, toRawJson, ternary
1. **Encoding Functions**: b64enc, b64dec, etc.
1. **Lists and List Functions**: list, first, uniq, etc.
1. **Dictionaries and Dict Functions**: get, set, dict, hasKey, pluck, dig, deepCopy, etc.
1. **Type Conversion Functions**: atoi, int64, toString, etc.
1. **Path and Filepath Functions**: base, dir, ext, clean, isAbs, osBase, osDir, osExt, osClean, osIsAbs
1. **Flow Control Functions**: fail

Sveltos includes a dedicated set of functions for manipulating the resources that trigger events. These functions are designed to make it easy to work with Kubernetes resource data directly within your templates.

1. **getResource**: Takes the resource that generated the event and returns a map[string]interface{} allowing to access any field of the resource. Following fields are automatically cleared: __managedFields__, __resourceVersion__ and __uid__.
1. **copy**: Creates a copy of the resource that generated the event.
1. **setField**: Takes the resource that generated the event, the field name, and a new value. It returns a modified copy of the resource with the specified field updated.
1. **removeField**: Takes the resource that generated the event and the field name. Returns a modified copy of the resource with the specified field removed.
1. **getField**: Takes the resource that generated the event and the field name. Returns the field value
1. **chainSetField**: This function acts as an extension of setField. It allows for chaining multiple field updates.
1. **chainRemoveField**: Similar to chainSetField, this function allows for chaining multiple field removals.

!!! note
    These functions operate on copies of the original resource, ensuring the original data remains untouched.

Here are some examples:

```yaml
  # Use getResource to retrieve the triggering resource and store it in a temporary variable.
  # This variable will be used as the starting point for all subsequent modifications.
  # Fields managedFields, resourceVersion and uid are automatically cleared
  {{ $resource := getResource .Resource }}

  # Use chainSetField to modify the 'metadata.name' field.
  # This function returns the modified resource, allowing it to be chained with the next function.
  {{ $resource := chainSetField $resource "metadata.name" "new-name" }}

  # Use chainRemoveField to remove the 'data' field.
  # The previous changes are preserved as the function operates on the modified resource.
  {{ $resource := chainRemoveField $resource "data" }}

  # Finally, use the toYaml function to output the final, modified resource.
  # This will be the resource that is applied to the managed cluster.
  {{ toYaml $resource }}
```

### Patch Resources

The EventSource acts as a listener. It continuously monitors the managed cluster for any Service resource.
The `evaluateCEL` rule is used to filter these Services. When a Service is created, updated, or deleted with the _sveltos: fv_ label, it generates an event.
The `collectResources: true` setting ensures that the full YAML of the Service resource is included in the event, which is essential for the copy template function used later.

The `EventTrigger` defines a chain of actions in response to this event:

- It creates a **ConfigMap** containing a copy of the Service that triggered the event.
- It creates a **ClusterProfile** that references this new ConfigMap. The ClusterProfile then applies the Service from the ConfigMap, patching it to add two labels, before deploying the modified Service back to the same cluster where the event originated.

```yaml
apiVersion: lib.projectsveltos.io/v1beta1
kind: EventSource
metadata:
  name: detect-service
spec:
  collectResources: true
  resourceSelectors:
  - group: ""
    version: "v1"
    kind: "Service"
    evaluateCEL:
    - name: service_with_label_sveltos_fv
      rule: has(resource.metadata.labels) && has(resource.metadata.labels.sveltos) && resource.metadata.labels.sveltos == "fv"
---
apiVersion: lib.projectsveltos.io/v1beta1
kind: EventTrigger
metadata:
  name: patch-service
spec:
  sourceClusterSelector:
    matchLabels:
      env: fv
  eventSourceName: detect-service
  oneForEvent: true
  policyRefs:
  - name: copy-service
    namespace: default
    kind: ConfigMap
  patches:
  - target:
      group: ""
      version: v1
      kind: Service
      name: ".*"
    patch: |
            - op: add
              path: /metadata/labels/mirror.linkerd.io~1exported
              value: "true"
            - op: add
              path: /metadata/labels/mirror.linkerd.io~1federated
              value: member
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: copy-service
  namespace: default
  annotations:
    projectsveltos.io/instantiate: ok
data:
  copy.yaml: |
    {{ copy .Resource }}
```


## Benefits

The EvenTrigger has access to the resource data and can use them to instantiate `namespace/name` of the `TemplateResourceRefs` field and the `ConfigMap/Secret` of the `policyRefs` field.

Once the EventTrigger is done creating the Sveltos ClusterProfile, the **addon controller** will take over and deploy it to the matching cluster(s). The **addon controller** does not have any access to the resource (only the EventTrigger has access to the resource). However, it can fetch any resource present in the **management cluster** which is defined in the `TemplateResourceRefs` field.

## Next Steps

Continue with the Event Generators section located [here](./generators.md).
