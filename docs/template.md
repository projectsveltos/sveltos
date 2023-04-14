---
title: Templates
description: Helm chart values and resources contained in referenced ConfigMaps/Secrets can be defined as template. 
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
authors:
    - Gianluca Mardente
---
Are you tired of manually defining Helm chart values and resources for each deployment? With ClusterProfile, you can define templates that are instantiated at the time of deployment, making your life easier and more efficient.

For example, imagine deploying Calico in multiple CAPI-powered clusters while fetching Pod CIDRs from corresponding CAPI Cluster instance. With ClusterProfile, it's as simple as creating a configuration that specifies these details, and voila! Your deployment is ready to go in all matching clusters.

```yaml
---
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
          {{ range $cidr := .Cluster.spec.clusterNetwork.pods.cidrBlocks }}
            - cidr: {{ $cidr }}
              encapsulation: VXLAN
          {{ end }}
```

Get ready to speed up your deployment time! With Sveltos, you can define any resource contained in a ConfigMap/Secret as a template by adding the `projectsveltos.io/template` annotation. This will ensure that the template is instantiated at the time of deployment, making your deployments faster and more efficient. So go ahead and optimize your deployment time with Sveltos!

## Variables

Templates have access to the following variables:

1. CAPI Cluster instance. Keyword is `Cluster`
2. CAPI Cluster infrastructure provider. Keyword is `InfrastructureProvider`
3. CAPI Cluster kubeadm provider. Keyword is `KubeadmControlPlane` 
4. For cluster registered with Sveltos, the SveltosCluster instance. Keyword is `SveltosCluster` 
