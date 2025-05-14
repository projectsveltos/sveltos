---
title: Event Driven Generators - Project Sveltos
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
authors:
    - Gianluca Mardente
---

## Introduction to Generators

There are times when the EventTrigger has to pass resource data to the addon controller. For that reason, the **ConfigMapGenerator** and **SecretGenerator** resources let us capture data from the resource which triggered an event (only the EventTrigger has access to it), package it into a new `ConfigMap/Secret`, and pass that resource downstream to the addon controller with the use of a predictable reference.

This mechanism bridges the gap between the event context and the addon deployment, enabling event-aware configurations even after the EventTrigger hands off to the addon controller.

### Why This Matters

The EventTrigger can access the triggering resource (e.g. a `custom resource` or a `namespace`) while the addon controller does not have access to the event or the resource which caused the EventTrigger to fire.

If we want to use data from this resource (e.g. `labels`, `annotations`, `spec` fields), we need to make the data available in a Kubernetes resource that the addon controller can read. That is where the `ConfigMapGenerator` and `SecretGenerator` come into play. They materialise resource data into real Kubernetes resources that the ClusterProfile can reference.

### How It Works: Step-by-Step Guide

Let's assume the EventTrigger detects an event, like the creation of a custom Kubernetes resource. The EventTrigger uses a `ConfigMapGenerator/SecretGenerator` to create a new `ConfigMap/Secret`, embedding selected fields from the triggering resource using templates.


!!! Example "Example: Fetch Source ConfigMap"

    First, Sveltos evaluates the `name` and `namespace` fields to locate the template `ConfigMap`.

    **Template**

    ```yaml
    configMapGenerator:
      - name: "{{ .Resource.metadata.name }}-source-config" # name can also use cluster data
        namespace: "{{ .Resource.metadata.namespace }}" # namespace can also use cluster data
        nameFormat: "{{ .Cluster.metadata.namespace }}-{{ .Cluster.metadata.name }}-{{ .Resource.metadata.name }}-generated"
    ```

    **Event Resource**

    ```yaml
    metadata:
      name: workload
      namespace: apps
    ```

    **Retrieved ConfigMap**

    ```yaml
    name: workload-source-config
    namespace: apps
    ```

    **Resolve nameFormat for Output**

    Sveltos computes the final name for the new `ConfigMap` using both **Cluster** and **resource** fields. If the cluster details are like the example below, then the generated name is `prod-team-a-workload-generated`.

    ```yaml
    metadata:
      name: team-a
      namespace: prod
    ```

    **Instantiate Content**

    The data section of the fetched `ConfigMap` (workload-source-config) is treated as a Go template. Sveltos renders it using full access to the information below.

    1. **.Cluster** fields
    2. **.Resource** fields
    3. **.MatchingResources** metadata

    **Final ConfigMap**

    The final `ConfigMap` details are listed below.

    - **Name**: prod-team-a-workload-generated
    - **Namespace**: projectsveltos
    - **Content**: Rendered using live cluster/resource data

    The generated `ConfigMap` will be referenced by the auto-generated ClusterProfile, typically via the __spec.templateResourceRefs__, so its content is consumed during the add-on or policy deployment.

## Next Steps

Continue with an [example](./example_secrets_on_demand.md) of how to create a Kubernetes `Secret` on demand.