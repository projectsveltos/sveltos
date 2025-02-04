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
---

## What is Sveltos?

Sveltos is a set of Kubernetes controllers deployed in the management cluster. From the management cluster, it can manage add-ons and applications to multiple clusters.

## Air-Gapped Installation

Sveltos can be installed in an **air-gapped** environment. An air-gapped environment is a **highly secure** environment completely **cut off** from the **Internet** and any other external networks. That implies, getting the required Sveltos images from the `Docker Hub` is not possible.

When installing Sveltos using the official `Helm chart`, the *drift-detection-manager* and the *sveltos-agent* will be deployed in each managed cluster. However, in an air-gapped environment, additional steps are required before installation.

## drift-detection-manager Configuration

Before installing Sveltos in a Kubernetes **management** cluster, **create** and **apply** the below `ConfigMap` resource. The `ConfigMap` will get deployed in the `projectsveltos` namespace and holds the information that gets applied to the *drift-detection-manager* before deployment to the Kubernetes **managed** cluster.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: drift-detection
  namespace: projectsveltos
data:
  patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: drift-detection-manager
    spec:
      template:
        spec:
          containers:
            - name: manager
              image: registry.company.io/projectsveltos/drift-detection-manager:dev
              resources:
                requests:
                  memory: 256Mi
```

The *drift-detection-manager* image is located [here](https://hubgw.docker.com/layers/projectsveltos/drift-detection-manager/dev/images/sha256-d31b3d57ee446ab216d7b925f35ef3da50de5161dff17ce2ef7c35f5bdd9c539).

!!! tip
    Replace the `image: registry.company.io/projectsveltos/drift-detection-manager:dev` argument with your private registry details.

Apart from deploying the `ConfigMap` resource in the **management** cluster, the argument `--drift-detection-config=drift-detection` needs to be included in the `addon-controller` of the ProjectSveltos `Helm chart`. The official `Helm chart` values are located [here](https://github.com/projectsveltos/helm-charts/blob/main/charts/projectsveltos/values.yaml).

```yaml hl_lines="9"
addonController:
  controller:
    args:
    - --diagnostics-address=:8443
    - --report-mode=0
    - --shard-key=
    - --v=5
    - --version=v0.46.1
    - --drift-detection-config=drift-detection
```

or, if running in agentless mode:

```yaml hl_lines="10"
addonController:
  controller:
    argsAgentMgmtCluster:
    - --diagnostics-address=:8443
    - --report-mode=0
    - --agent-in-mgmt-cluster
    - --shard-key=
    - --v=5
    - --version=v0.46.1
    - --drift-detection-config=drift-detection
```

!!! note
    `drift-detection` is the name of the `ConfigMap` resource applied in an earlier section.

## sveltos-agent Configuration

We will follow the same approach described above for the *sveltos-agent*. **Create** and **apply** the below `ConfigMap` resource in the Kubernetes **management** cluster and update the ProjectSveltos `Helm chart` values.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: sveltos-agent-config
  namespace: projectsveltos
data:
  patch: |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: sveltos-agent-manager
    spec:
      template:
        spec:
          imagePullSecrets:
            - name: my-registry-secret
          containers:
            - name: manager
              image: registry.company.io/projectsveltos/sveltos-agent:dev
```

The *sveltos-agent* **image** is located [here](https://hubgw.docker.com/layers/projectsveltos/sveltos-agent/dev/images/sha256-d2c23f55e4585e9cfd103547bd238aef42f8cedb1d8ca23600bd393710669b37).

The *sveltos-agent* will be deployed in the **management** cluster with the bellow settings.

- **Custom image from private registry**: registry.company.io/projectsveltos/sveltos-agent:dev
- **Private registry credentials**: my-registry-secret (the secret must be present in the **projectsveltos** namespace)
- **Proxy settings**: HTTP_PROXY, HTTPS_PROXY, and NO_PROXY defined.

!!! tip
    Replace the `image: registry.company.io/projectsveltos/sveltos-agent:dev` argument with your private registry details.

    To create the `my-registry-secret` Secret, provide your credentials directly using the command: ```kubectl create secret docker-registry my-registry-secret -n projectsveltos --docker-server=<your-registry-server> --docker-username=<your-name> --docker-password=<your-pword> --docker-email=<your-email>```

Include the argument `--sveltos-agent-config=sveltos-agent-config` to the `classifer-manager` deployment within the Helm chart values.

```yaml hl_lines="8"
classifierManager:
  manager:
    args:
    - --diagnostics-address=:8443
    - --report-mode=0
    - --shard-key=
    - --v=5
    - --version=v0.46.1
```

or, if running in agentless mode:

```yaml hl_lines="10"
classifierManager:
  manager:
    argsAgentMgmtCluster:
    - --diagnostics-address=:8443
    - --report-mode=0
    - --agent-in-mgmt-cluster
    - --shard-key=
    - --v=5
    - --version=v0.46.1    
    - --sveltos-agent-config=sveltos-agent-config
```

## Helm Installation

On the Kubernetes **management** cluster, install ProjectSveltos!

```
$ helm repo add projectsveltos  <private-repo-url>

$ helm repo update

$ helm install projectsveltos projectsveltos/projectsveltos -n projectsveltos --create-namespace -f custom_values.yaml

$ helm list -n projectsveltos
```

!!! note
    The `custom_values.yaml` file holds all the changes performed on the Helm chart above.

## Next Steps

Continue with the **Sveltoctl** command-line interface (CLI) definition and installation [here](../sveltosctl/sveltosctl.md).
