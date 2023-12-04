---
title: Resource Deployment Order
description: Describe how Sveltos can be instructed to follow an order when deploying resources
tags:
    - Kubernetes
    - Sveltos
    - add-ons
    - order
authors:
    - Gianluca Mardente
---

When managing multiple applications across different teams, each requiring the presence of __cert-manager__ within the cluster, consider utilizing a ClusterProfile to deploy cert-manager centrally. 
This approach enables other ClusterProfiles, responsible for deploying applications that depend on cert-manager, to leverage the dependsOn field to ensure cert-manager is present prior to application deployment.

To guarantee that cert-manager is not only deployed but also functioning correctly, employ the __validateHealths__ flag. The following ClusterProfile will deploy cert-manager in any cluster matching the label selector env=fv and subsequently wait for all deployments in the cert-manager namespace to reach a healthy state (active replicas matching requested replicas) before marking this ClusterProfile as provisioned in the matching cluster.

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: cert-manager
spec:
  clusterSelector: env=fv
  syncMode: Continuous
  helmCharts:
  - repositoryURL:    https://charts.jetstack.io
    repositoryName:   jetstack
    chartName:        jetstack/cert-manager
    chartVersion:     v1.13.2
    releaseName:      cert-manager
    releaseNamespace: cert-manager
    helmChartAction:  Install
    values: |
      installCRDs: true
  validateHealths:
  - name: deployment-health
    featureID: Helm
    group: "apps"
    version: "v1"
    kind: "Deployment"
    namespace: cert-manager
    script: |
      function evaluate()
        hs = {}
        hs.healthy = false
        hs.message = "available replicas not matching requested replicas"
        if obj.status ~= nil then
          if obj.status.availableReplicas ~= nil
           then
            if obj.status.availableReplicas == obj.spec.replicas then
              hs.healthy = true
            end
          end
        end
        return hs
      end
```

Now the ClusterPofile to deploy __nginx ingress__ can specify it depends on __cert-manager__ ClusterProfile:

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: ingress-nginx
spec:
  clusterSelector: env=fv
  syncMode: Continuous
  helmCharts:
  - repositoryURL:    https://kubernetes.github.io/ingress-nginx
    repositoryName:   ingress-nginx
    chartName:        ingress-nginx/ingress-nginx
    chartVersion:     "4.8.4"
    releaseName:      ingress-nginx
    releaseNamespace: ingress-nginx
    helmChartAction:  Install
  dependsOn:
  - cert-manager
```
