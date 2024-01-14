---
title: Kubernetes add-ons management for tens of clusters quick start
description: Projectsveltos extends the functionality of Cluster API with a solution for managing the installation, configuration & deletion of Kubernetes cluster add-ons.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
authors:
    - Gianluca Mardente
---

# Deploy Kubernetes Add-ons

The main goal of Sveltos is to deploy add-ons in managed Kubernetes clusters. So let's see that in action.

Before you begin, please ensure you already have a management cluster with projectsveltos installed. If this is the case, go through the [install](install.md) section to deploy projectsveltos.

If you want to try the projectsveltos with a **test cluster**, follow the steps below:

``` bash
$ git clone https://github.com/projectsveltos/addon-controller

$ make quickstart
```

The above will create a management cluster using [Kind](https://kind.sigs.k8s.io), deploy clusterAPI and projectsveltos, 
create a workload cluster powered by clusterAPI using Docker as infrastructure provider.

## Deploy Helm Charts

To deploy the Kyverno Helm chart in any Kubernetes cluster with labels _env: fv_ create this ClusterProfile instance in the management cluster:

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: deploy-kyverno
spec:
  clusterSelector: env=fv
  syncMode: Continuous
  helmCharts:
  - repositoryURL:    https://kyverno.github.io/kyverno/
    repositoryName:   kyverno
    chartName:        kyverno/kyverno
    chartVersion:     v3.1.0
    releaseName:      kyverno-latest
    releaseNamespace: kyverno
    helmChartAction:  Install
```

## Deploy Raw YAMl/JSON

Download this file

```bash
$ wget https://raw.githubusercontent.com/projectsveltos/demos/main/httproute/gateway-class.yaml
```

which contains:

- Namespace projectcontour to run the Gateway provisioner
- Contour CRDs
- Gateway API CRDs
- Gateway provisioner RBAC resources
- Gateway provisioner Deployment

and create a Secret in the management cluster containing the contents of the downloaded file:

```bash
$ kubectl create secret generic contour-gateway-provisioner-secret --from-file=contour-gateway-provisioner.yaml --type=addons.projectsveltos.io/cluster-profile
```

To deploy all these resources in any cluster with labels *env: fv*, create a ClusterProfile instance in the management cluster referencing the Secret created above:

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
 name: gateway-configuration
spec:
 clusterSelector: env=fv
 syncMode: Continuous
 policyRefs:
 - name: contour-gateway-provisioner-secret
   namespace: default
   kind: Secret
```

## Deploy Resources Assembled with Kustomize

Sveltos can work along with Flux to deploy content of Kustomize directories.

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: flux-system
spec:
  clusterSelector: env=fv
  syncMode: Continuous
  kustomizationRefs:
  - namespace: flux-system
    name: flux-system
    kind: GitRepository
    path: ./helloWorld/
    targetNamespace: eng
```

Full examples can be found [here](../addons/kustomize.md).

ClusterProfile can reference:

1. GitRepository (synced with flux);
2. OCIRepository (synced with flux);
3. Bucket (synced with flux);
4. ConfigMap whose BinaryData section contains __kustomize.tar.gz__ entry with tar.gz of kustomize directory;
5. Secret (type addons.projectsveltos.io/cluster-profile) whose Data section contains __kustomize.tar.gz__ entry with tar.gz of kustomize directory;

## Carvel ytt and Jsonnet
Sveltos offers support for Carvel ytt and Jsonnet as tools to define add-ons that can be deployed in a managed cluster. For additional information, please consult the [Carvel ytt](../template/ytt_extension.md) and [Jsonnet](../template/jsonnet_extension.md) sections.
