---
title: How to install Sveltos in an Air-Gapped Environment
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative cluster APIs. Learn here how to install Sveltos.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
authors:
    - Eleni Grosdouli
    - Robin Afflerbach
---

## What is Sveltos?

Sveltos is a set of Kubernetes controllers deployed in the management cluster. From the management cluster, it can manage add-ons and applications to multiple clusters.

## Air-Gapped Installation

!!! note
    This documentation assumes that Sveltos is installed using `Helm`.

Sveltos can be installed in an **air-gapped** environment. An air-gapped environment is a **highly secure** environment completely **cut off** from the **Internet** and any other external networks. That implies, getting the required Sveltos images from the `Docker Hub` is not possible. This method can also be useful if the cluster runs in an environment where access to certain image registries is restricted and a custom registry or registry cache needs to be used (e.g. in large enterprises).

When installing Sveltos using the official `Helm chart`, the *drift-detection-manager* and the *sveltos-agent* will be deployed in each managed cluster or on the management cluster when `agent.managementCluster=true` is set. However, in restricted environments, additional values are required for the installation. The *drift-detection-manager* and the *sveltos-agent* deployments will be dynamically deployed instead of from the Sveltos installation directly. This means that the patches to these deployments are done during runtime instead of upfront.

There are two types of patches that can be applied:

- [Strategic Merge Patch](http://kubernetes.io/docs/tasks/manage-kubernetes-objects/update-api-object-kubectl-patch/)
- [JSON Patch (RFC6902)](https://datatracker.ietf.org/doc/html/rfc6902)

Patches of both types can be persisted in a `ConfigMap` and passed to the components that will deploy the *drift-detection-manager* and the *sveltos-agent* respectively.

The `Helm` chart offers a way to only specify the patches and the `ConfigMaps` will be created automatically so that they will be applied to the deployments before applying the *drift-detection-manager* and *sveltos-agent*.

!!! warning "Targeting patches by name in Centralized/Agentless mode"
    Every `target.name` shown in the examples below (`drift-detection-manager`, `sveltos-agent-manager`) assumes **Local Agent mode** — one Deployment per managed cluster, deployed inside that cluster, with a fixed, predictable name.

    In **Centralized Agent mode** (`agent.managementCluster=true`, also called agentless mode), both agents instead run as one Deployment per managed cluster **inside the management cluster**, and each Deployment's name is generated dynamically per cluster (e.g. `sveltos-agent-buogojckqami0wcn90mt`, not `sveltos-agent-manager`) — Sveltos has to hand out a unique name per cluster now that many clusters' agents coexist in the same namespace. A patch `target.name` can't single out "the" Deployment for a given cluster in that mode; `target.name` is matched as a regular expression, not a glob, so even something like `sveltos-agent-*` will not do what it looks like it does (as a regex it just means "zero or more trailing dashes," and matches every agent Deployment's name as a substring, not a useful subset of one).

    Use `target.labelSelector` instead, matching the `feature` label every one of these Deployments carries regardless of its generated name:

    - sveltos-agent: `labelSelector: feature=sveltos-agent`
    - drift-detection-manager: `labelSelector: feature=drift-detection`

    ```yaml
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: sveltos-agent-config
      namespace: projectsveltos
    data:
      deployment-patch: |-
        patch: |-
          - op: replace
            path: /spec/template/spec/containers/0/resources/limits/cpu
            value: 500m
          - op: replace
            path: /spec/template/spec/containers/0/resources/limits/memory
            value: 2048Mi
        target:
          kind: Deployment
          labelSelector: feature=sveltos-agent
          namespace: projectsveltos
    ```

    This applies to every `name`-based patch target on this page — the global Helm-values patches below and the per-cluster override annotations further down — whenever the target cluster runs in Centralized/Agentless mode.

## drift-detection-manager Configuration

To customize the *drift-detection-manager* deployment you can add your patches to the `Helm` values like here:

```yaml
...
addonController:
  driftDetectionManagerPatchConfigMap:
    data:
      deployment-patch: |-
          patch: |-
            apiVersion: apps/v1
            kind: Deployment
            metadata:
              name: drift-detection-manager
            spec:
              template:
                spec:
                  imagePullSecrets:
                    - name: my-registry-secret
                  containers:
                    - name: manager
                      image: registry.company.io/projectsveltos/drift-detection-manager:dev
...
```

This example makes use of the `Strategic Merge Patch`. The key of the `data` in the `ConfigMap` (here `patch`) is arbitrary and can be changed to any other value.

The *drift-detection-manager* image is located [here](https://hubgw.docker.com/layers/projectsveltos/drift-detection-manager/dev/images/sha256-d31b3d57ee446ab216d7b925f35ef3da50de5161dff17ce2ef7c35f5bdd9c539).

## sveltos-agent Configuration

The *sveltos-agent* can be patched in the same way. In order to edit the deployment the following values can be used:

```yaml
classifierManager:
  agentPatchConfigMap:
    data:
      deployment-patch: |-
          patch: |-
            - op: replace
              path: /spec/template/spec/containers/0/resources/requests/cpu
              value: 500m
            - op: replace
              path: /spec/template/spec/containers/0/resources/requests/memory
              value: 512Mi
            - op: replace
              path: /spec/template/spec/containers/0/resources/limits/cpu
              value: 500m
            - op: replace
              path: /spec/template/spec/containers/0/resources/limits/memory
              value: 1024Mi
            - op: replace
              path: /spec/template/spec/containers/0/image
              value: registry.company.io/projectsveltos/sveltos-agent:dev
            - op: add
              path: /spec/template/spec/imagePullSecrets
              value:
                - name: my-registry-secret
          target:
            kind: Deployment
            name: sveltos-agent-manager
            namespace: projectsveltos
```

This example makes use of `JSON Patch (RFC 6902)` to change deployment values. It's not limited to only one item in `data`.

The *sveltos-agent* **image** is located [here](https://hubgw.docker.com/layers/projectsveltos/sveltos-agent/dev/images/sha256-d2c23f55e4585e9cfd103547bd238aef42f8cedb1d8ca23600bd393710669b37).

The *sveltos-agent* will be deployed in the **management** cluster with the bellow settings.

- **Custom image from private registry**: registry.company.io/projectsveltos/sveltos-agent:dev
- **Private registry credentials**: my-registry-secret (the secret must be present in the **projectsveltos** namespace)[^1]

!!! tip
    Replace the `image: registry.company.io/projectsveltos/sveltos-agent:dev` argument with your private registry details.

    To create the `my-registry-secret` Secret, provide your credentials directly using the command: ```kubectl create secret docker-registry my-registry-secret -n projectsveltos --docker-server=<your-registry-server> --docker-username=<your-name> --docker-password=<your-pword> --docker-email=<your-email>```

## sveltos-applier Configuration

Once we have registered a cluster in [pull mode](../../register/register_cluster_pull_mode.md), Sveltos takes over the management of the _sveltos-applier_ agent. On every Sveltos upgrade, it automatically generates the configuration needed to upgrade the applier, ensuring the agent on the managed cluster is always up-to-date.

If we made any custom changes to the _sveltos-applier_ configuration during the initial registration process, Sveltos provides a way to persist those changes during future upgrades. We can use the _agentPatchSveltosApplierConfigMap_ field to provide a patch that will be applied to the applier's configuration, preventing the custom settings from being overwritten by the automatic upgrade process. This allows us to maintain full control while still benefiting from Sveltos's automated lifecycle management.

```yaml
classifierManager:
  agentPatchSveltosApplierConfigMap:
    name: sveltos-applier-config
    data:
      deployment-patch: |-
          patch: |-
            [
              {
                "op": "replace",
                "path": "/spec/template/spec/containers/0/args/4",
                "value": "--secret-with-kubeconfig=pullmode-secret"
              }
            ]
          target:
            kind: Deployment
            name: sveltos-applier-manager
            namespace: projectsveltos
```

## Helm Installation

On the Kubernetes **management** cluster, install ProjectSveltos!

```
$ helm repo add projectsveltos <private-repo-url>

$ helm repo update

$ helm install projectsveltos projectsveltos/projectsveltos -n projectsveltos --create-namespace -f custom_values.yaml

$ helm list -n projectsveltos
```

!!! note
    The `custom_values.yaml` file holds all the changes performed on the Helm chart above.

## Per-Cluster Agent Configuration

While the sections above describe how to apply global patches to the Sveltos agents via Helm values, Sveltos now supports applying **cluster-specific** configuration overrides.

This is useful for complex environments where clusters in different regions, environments, or networks require unique configurations (e.g., using different private registries, specific resource limits, or local proxy settings).

You can reference a _ConfigMap_ or _Secret_ containing deployment patches directly on the target cluster's resource (CAPI Cluster or SveltosCluster) using annotations. The Sveltos controllers will apply this patch before deploying the agent to that specific cluster, overriding any global Helm or default settings.

### Drift Detection Manager Overrides

To provide a cluster-specific override for the drift-detection-manager, use the following annotation on your Cluster or SveltosCluster resource: `driftdetection.projectsveltos.io/config-override-ref``

```yaml
apiVersion: cluster.x-k8s.io/v1beta2
kind: Cluster
metadata:
  name: regional-cluster-1
  annotations:
    # References a ConfigMap named 'east-registry-patch' in a specific namespace (e.g., 'projectsveltos')
    driftdetection.projectsveltos.io/config-override-ref: projectsveltos/east-registry-patch
spec:
  # ...
```

with

```yaml
apiVersion: v1
data:
  deployment-patch: |-
    patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/resources/requests/cpu
        value: 500m
      - op: replace
        path: /spec/template/spec/containers/0/resources/requests/memory
        value: 512Mi
      - op: replace
        path: /spec/template/spec/containers/0/resources/limits/cpu
        value: 500m
      - op: replace
        path: /spec/template/spec/containers/0/resources/limits/memory
        value: 1024Mi
    target:
      kind: Deployment
      name: drift-detection-manager
      namespace: projectsveltos
kind: ConfigMap
metadata:
  name: projectsveltos
  namespace: east-registry-patch
```

### Sveltos Agent Overrides

To provide a cluster-specific override for the sveltos-agent (the agent responsible for classification), use the following annotation: `sveltosagent.projectsveltos.io/config-override-ref`

```yaml
apiVersion: projectsveltos.io/v1beta1
kind: SveltosCluster
metadata:
  name: special-cluster-2
  annotations:
    # References a ConfigMap named 'agent-resource-limits' in a specific namespace (e.g., 'default')
    sveltosagent.projectsveltos.io/config-override-ref: default/agent-resource-limits
spec:
  # ...
```

with

```yaml
apiVersion: v1
data:
  deployment-patch: |-
      patch: |-
        - op: replace
          path: /spec/template/spec/containers/0/resources/requests/cpu
          value: 100m
        - op: replace
          path: /spec/template/spec/containers/0/resources/requests/memory
          value: 256Mi
        - op: replace
          path: /spec/template/spec/containers/0/resources/limits/cpu
          value: 500m
        - op: replace
          path: /spec/template/spec/containers/0/resources/limits/memory
          value: 1024Mi
      target:
        kind: Deployment
        name: sveltos-agent-manager
        namespace: projectsveltos
  clusterrole-patch: |-
      patch: |-
        - op: remove
          path: /rules
      target:
        kind: ClusterRole
        name: sveltos-agent-manager-role
kind: ConfigMap
metadata:
  name: agent-resource-limits
  namespace: default
```

### Sveltos Applier Overrides

To provide a cluster-specific override for the sveltos-agent (the agent responsible for classification), use the following annotation: `sveltosapplier.projectsveltos.io/config-override-ref`

## Next Steps

Continue with the **sveltoctl** command-line interface (CLI) definition and installation [here](../sveltosctl/sveltosctl.md).

[^1]: A Sveltos ClusterProfile can deploy your Secret to managed clusters. Assuming the Secret is named __image-pull-secret__ and resides in the __default__ namespace, it will be deployed to all clusters labeled __environment: air-gapped__
```
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: deploy-resources
    spec:
      clusterSelector:
        matchLabels:
          environment: air-gapped
      templateResourceRefs:
      - resource:
          apiVersion: v1
          kind: Secret
          name: image-pull-secret
          namespace: default
        identifier: ImagePullSecret
      policyRefs:
      - kind: ConfigMap
        name: info
        namespace: default
    ---
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: info
      namespace: default
      annotations:
        projectsveltos.io/template: ok  # add annotation to indicate Sveltos content is a template
    data:
      secret.yaml: |
        {{ copy "ImagePullSecret" }}
```

