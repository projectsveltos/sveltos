---
title: Example - Create Secret on demand using EventTrigger
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative APIs to deploy Kubernetes add-ons across multiple clusters.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
    - Sveltos
    - Event Driven
    - Generators
    - Secrets Example
authors:
    - Gianluca Mardente
---

## Introduction

The example demonstrates a dynamic replication of a Kubernetes `Secret` to any __production__ cluster in a defined namespace. If you are not familiar with the [EventTrigger](./templating.md) feature or the [Sveltos Generators](./generators.md), check out the mentioned guides before proceeding.

### Example: Replicate a Secret on Demand

For a dynamic `Secret` replication, we will establish a system that reacts to newly created namespaces requiring credentials. Initially, an `EventSource` will monitor for namespaces labeled `secret: required` within the production Kubernetes clusters. Upon detection, the system will retrieve its **name** and create a corresponding **resource** in the Kubernetes **management** cluster, storing the information using a `ConfigMapGenerator`.

The `EventTrigger` will then generate a Sveltos `ClusterProfile`. The ClusterProfile will **reference** the **newly created resource** containing the namespace information and the **login-credentials** Secret from the default namespace of the Kubernetes **management** cluster. Finally, the ClusterProfile will dynamically fetch the referenced resources, **extract** the necessary data, and **replicate** the **login-credentials** Secret into the identified namespace within the production clusters.

!!! Example "EventSource"
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

!!! Example "EventTrigger"

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

!!! Example "Referenced ConfigMaps"

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

Imagine we have a production cluster named __workload__ residing in the __default__ namespace. Within this cluster, two namespaces, __eng__ and __hr__, are labeled __secret: required__.

Sveltos will detect that and generate a `ConfigMap` in the `projectsveltos` namespace. The ConfigMap, named `<cluster namespace>-<cluster name>-namespaces` (in this case, _default-workload-namespaces_), stores the identified namespaces as follows.

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

 Outcome: The `Secret` is replicated to the `env` and `hr` namespaces.

 ```bash
 $ sveltosctl show addons
 +-----------------------------+---------------+-----------+-------------------+---------+-------------------------------+---------------------------------------------+
 |           CLUSTER           | RESOURCE TYPE | NAMESPACE |       NAME        | VERSION |             TIME              |                  PROFILES                   |
 +-----------------------------+---------------+-----------+-------------------+---------+-------------------------------+---------------------------------------------+
 | default/workload            | :Secret       | eng       | login-credentials | N/A     | 2025-02-28 14:23:08 +0100 CET | ClusterProfile/sveltos-lbh9me2lr77gokea2u5u |
 | default/workload            | :Secret       | hr        | login-credentials | N/A     | 2025-02-28 14:23:08 +0100 CET | ClusterProfile/sveltos-lbh9me2lr77gokea2u5u |
 +-----------------------------+---------------+-----------+-------------------+---------+-------------------------------+---------------------------------------------+
 ```