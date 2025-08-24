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
    - Eleni Grosdouli
---

## Use Case Description

There are a number of cases where platform administrators or operators want to discover and iterate through multiple clusters to deploy specific Kubernetes resources dynamically. One example is the formation of a NATS supercluster that requires each NATS instance provisioned by Sveltos to be aware of other clusters.

The use case can be easily achieved by Sveltos with the use of the [templating](../template/template_generic_examples.md) functionality and [Sveltos Event Franmework](../events/addon_event_deployment.md).

## Identify Sveltos Managed Clusters

Sveltos `Event Framework` will be used to dynamically detect all **managed** clusters (of type SveltosCluster) that are different from the management cluster. The management cluster has the Sveltos cluster label set to `type:mgmt`.

!!! example "Example - EventSource and EventTrigger Definition"
    ```yaml
    cat > eventsource_eventtrigger.yaml <<EOF
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: EventSource
    metadata:
    name: detect-clusters
    spec:
    collectResources: false
    resourceSelectors:
    - group: "lib.projectsveltos.io"
      version: "v1beta1"
      kind: "SveltosCluster"
      labelFilters:
      - key: sveltos-agent
        operation: Equal
        value: present
      - key: type
        operation: Different
        value: mgmt
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: EventTrigger
    metadata:
      name: detect-cluster
    spec:
      sourceClusterSelector:
        matchLabels:
          type: mgmt
      eventSourceName: detect-clusters
      oneForEvent: false
    EOF
    ```

Once the above YAML definition file is applied to the **management** cluster, an `EventReport` resource named `detect-clusters` will be created within the `projectsveltos` namespace.

The report stores the information about all discovered managed clusters. Sveltos templating feature can reference the resource to retrieve a **list** of managed clusters. This allows a dynamic configuration based on the cluster environment.

### EventReport Output

```yaml
apiVersion: lib.projectsveltos.io/v1beta1
kind: EventReport
...
spec:
  eventSourceName: detect-clusters
  matchingResources:
  - apiVersion: lib.projectsveltos.io/v1beta1
    kind: SveltosCluster
    name: cluster-1
    namespace: civo
  - apiVersion: lib.projectsveltos.io/v1beta1
    kind: SveltosCluster
    name: cluster-2
    namespace: civo
```

## Automatic Service Creation

Lets assume the clusters where the service should get deployed has the cluster label set to `type:nats`. The below YAML defintion will create a Sveltos `ClusterProfile` resource that points to the `EventReport` mentioned above and deploy a `ConfigMap` defined as a template.

### ClusterProfile

!!! example "Example - ClusterProfile Definition"
    ```yaml
    cat > clusterprofile_nats.yaml <<EOF
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: deploy-resources
    spec:
      clusterSelector:
        matchLabels:
          type: nats
      templateResourceRefs:
      - resource:
          apiVersion: lib.projectsveltos.io/v1beta1
          kind: EventReport
          name: detect-clusters
          namespace: projectsveltos
        identifier: ClusterData
      policyRefs:
      - kind: ConfigMap
        name: nats-services
        namespace: default
    EOF
    ```

### ConfigMap

!!! example "Example - ConfigMap Definition"
    ```yaml
    cat > cm_nats_services.yaml <<EOF
    ---
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: nats-services
      namespace: default
      annotations:
          projectsveltos.io/template: "true"
    data:
      services.yaml: |
        {{ range $cluster := (getResource "ClusterData").spec.matchingResources }}
          apiVersion: v1
          kind: Service
          metadata:
            labels:
              app: nats
              tailscale.com/proxy-class: default
            annotations:
              tailscale.com/tailnet-fqdn: nats-{{ $cluster.name }}
            name: nats-{{ $cluster.name }}
          spec:
            externalName: placeholder
            type: ExternalName
        ---
        {{ end }}
    EOF
    ```

!!!note
    The ConfigMap resource will create the `nats-{{ $cluster.name }}` services in the `default` namespace on every cluster with the cluster label set to `type:nats`.

## Results

Once the `ClusterProfile` resource gets deployed on the management cluster, all the clusters with the label set to `type:nats` should get the Kubernetes service with the name `nats-{{ $cluster.name }}`.

### Sveltos Clusters

```bash
$ kubectl get sveltoscluster -A --show-labels

NAMESPACE  NAME    READY  VERSION    LABELS
civo    cluster-1  true  v1.29.2+k3s1  sveltos-agent=present
civo    cluster-2  true  v1.28.7+k3s1  sveltos-agent=present
mgmt    mgmt       true  v1.30.0       sveltos-agent=present,type=mgmt
nats    cluster-3  true  v1.28.7+k3s1  type=nats
```

### Kubernetes Services

```bash
$ kubectl get service
NAME       TYPE      CLUSTER-IP  EXTERNAL-IP  PORT(S)  AGE
...
nats-cluster-1  ExternalName  <none>    placeholder  <none>  68s
nats-cluster-2  ExternalName  <none>    placeholder  <none>  68s
```

!!!note
    The output above is from the `cluster-3`.

## Automatic Updates Advantages
The beauty of Sveltos is its automatic reaction to changes. If we create or destroy managed clusters, Sveltos will automatically:

1. Detect the change through the detect-clusters `EventSource`
2. Re-evaluate the nats-services template with updated data
3. Add or remove Service instances in the mentioned clusters as needed

This ensures the clusters remain **dynamically updated** based on the managed cluster configuration.
