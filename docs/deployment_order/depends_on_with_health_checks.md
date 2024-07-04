---
title: Resource Deployment Order - depends-on
description: Describe how Sveltos can be instructed to follow an order when deploying resources
tags:
    - Kubernetes
    - Sveltos
    - add-ons
    - order
authors:
    - Gianluca Mardente
---

Managing multiple applications across different teams, each of them requiring the presence of the __cert-manager__, consider utilizing a ClusterProfile to deploy cert-manager **centrally**.

This approach enables other ClusterProfiles, responsible for deploying applications that depend on cert-manager, to leverage the `dependsOn` field to ensure the cert-manager is present prior to application deployment.

To guarantee that cert-manager is not only deployed but also functional, employ the __validateHealths__ flag. The below ClusterProfile will deploy cert-manager in any cluster matching the label selector `env=fv` and subsequently wait for all deployments in the cert-manager namespace to reach a healthy state (active replicas matching requested replicas) before setting the ClusterProfile as `provisioned`.

!!! example ""
    ```yaml
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: cert-manager
    spec:
      clusterSelector:
        matchLabels: 
          env: fv
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
            local hs = {healthy = false, message = "available replicas not matching requested replicas"}
            if obj.status and obj.status.availableReplicas ~= nil and obj.status.availableReplicas == obj.spec.replicas then
              hs.healthy = true
            end
            return hs
          end
    ```

### Example: Nginx and Cert Manager

In the below example, the ClusterPofile to deploy the __nginx ingress__ depends on the __cert-manager__ ClusterProfile defined above.

!!! example ""
    ```yaml
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: ingress-nginx
    spec:
      clusterSelector:
        matchLabels:
          env: fv
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

