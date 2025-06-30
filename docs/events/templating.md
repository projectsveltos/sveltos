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

The resulting Sveltos ClusterProfile can include:

1. **TemplateResourceRefs**
1. **PolicyRefs**
1. **HelmCharts**
1. **KustomizationRefs**

### Instantiation Flow: TemplateResourceRefs

The EventTrigger __TemplateResourceRefs__ is instantiated using resource data and set to __ClusterProfile.Spec.TemplateResourceRefs__.

The `namespace` and `name` fields within each reference can be **constants** or **templates**. The templates are dynamically evaluated using data from the **triggering cluster** or **resource**, allowing the generated ClusterProfile to be context-aware and tailored to a specific event.

Usage Example:

- `{{ .Cluster.metadata.name }}`
- `{{ .Resource.metadata.annotations.env }}`
- `{{ printf "%s-%s" .Cluster.metadata.labels.region .Resource.metadata.name }}`

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

The above logic can change based on specific annotations of the referenced resources.

1. If the resource does not have the annotation __projectsveltos.io/instantiate__ set, the generated Sveltos ClusterProfile will directly reference the same `ConfigMap/Secret` resource. If the annotation __projectsveltos.io/template__ is set, the Sveltos addon controller will instantiate the resource using the cluster's context before deploying it to any matching cluster.
1. If the resource has the annotation __projectsveltos.io/instantiate__ set, the EventTrigger will instantiate the `ConfigMap/Secret` using the resource data. The generated Sveltos ClusterProfile will reference the `ConfigMap/Secret` resource created by the EventTrigger.


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

## Benefits

The EvenTrigger has access to the resource data and can use them to instantiate `namespace/name` of the `TemplateResourceRefs` field and the `ConfigMap/Secret` of the `policyRefs` field. This is possible only if the resources have the annotation set to __projectsveltos.io/instantiate__.

Once the EventTrigger is done creating the Sveltos ClusterProfile, the **addon controller** will take over and deploy it to the matching cluster(s). The **addon controller** does not have any access to the resource (only the EventTrigger has access to the resource). However, it can fetch any resource present in the **management cluster** which is defined in the `TemplateResourceRefs` field.

## Next Steps

Continue with the Event Generators section located [here](./generators.md).
