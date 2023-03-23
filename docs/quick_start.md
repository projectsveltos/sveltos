---
title: Kubernetes add-ons management for tens of clusters
description: Projectsveltos extends the functionality of Cluster API with a solution for managing the installation, configuration & deletion of kubernetes cluster add-ons.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
authors:
    - Gianluca Mardente
---

# Deploy add-ons

The main goal of Sveltos is to deploy add-ons in managed Kubernetes clusters. So let's see that in action (see [install](install.md) section first).

## Deploy Helm charts

To deploy Kyverno in any Kubernetes cluster with labels _env: fv_ create this ClusterProfile instance in the management cluster:

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
    chartVersion:     v2.6.0
    releaseName:      kyverno-latest
    releaseNamespace: kyverno
    helmChartAction:  Install
```

## Deploy Kubernetes resources

Download this file

```bash
wget https://raw.githubusercontent.com/projectsveltos/demos/main/httproute/gateway-class.yaml
```

which contains:

- Namespace projectcontour to run the Gateway provisioner
- Contour CRDs
- Gateway API CRDs
- Gateway provisioner RBAC resources
- Gateway provisioner Deployment

and create a Secret in the management cluster containing content of that file.

```bash
kubectl create secret generic contour-gateway-provisioner-secret --from-file=contour-gateway-provisioner.yaml --type=addons.projectsveltos.io/cluster-profile
```

To deploy all those resources in any cluster with labels _env: fv_ create this ClusterProfile instance in the management cluster:

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

## Express your add-ons as template

Helm chart values and resources contained in referenced ConfigMaps/Secrets can be defined as template. Such templates instantiation happens at time of deployment reading values from managament cluster.

Templates have access to the following variables:

1. CAPI Cluster instance. Keyword is `Cluster`
2. CAPI Cluster infrastructure provider. Keyword is `InfrastructureProvider`
3. CAPI Cluster kubeadm provider. Keyword is `KubeadmControlPlane` 
4. For cluster registered with Sveltos, the SveltosCluster instance. Keyword is `SveltosCluster` 

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: deploy-calico
spec:
  clusterSelector: env=fv
  helmCharts:
  - repositoryURL:    https://projectcalico.docs.tigera.io/charts
    repositoryName:   projectcalico
    chartName:        projectcalico/tigera-operator
    chartVersion:     v3.24.5
    releaseName:      calico
    releaseNamespace: tigera-operator
    helmChartAction:  Install
    values: |
      installation:
        calicoNetwork:
          ipPools:
          {{ range $cidr := .Cluster.Spec.ClusterNetwork.Pods.CIDRBlocks }}
            - cidr: {{ $cidr }}
              encapsulation: VXLAN
          {{ end }}
```

## Much more

Deploying add-on is just one of the many features Sveltos offers. Please consider reading following section to understand how to cover more complex scenarios with Sveltos.

- Using [event driven framework](addon_event_deployment.md), you can instruct Sveltos to deploy new add-ons when certain events happen in a managed cluster;
- Using [classifier](labels_management.md), you can have Sveltos manage clusters's label based on cluster runtime state;
- Using Sveltos [multi-tenancy](multi-tenancy.md) platform admin can securely delegate add-on deployments to tenant admins;
- and more.
