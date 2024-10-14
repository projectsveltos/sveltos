---
title: Register Cluster
description: Sveltos comes with support to automatically discover ClusterAPI powered clusters. Any other cluster (GKE for instance) can easily be registered with Sveltos.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
authors:
    - Gianluca Mardente
---

# Automatically Token Renewal

To register a managed cluster (e.g., GKE, AKS, EKS) with Sveltos, a temporary Kubeconfig file is generated using sveltosctl. 
However, due to potential expiration limits imposed by cloud providers, this can disrupt Sveltos' management of the cluster.

To prevent this, configure automatic renewal: edit the SveltosCluster resource. Add or modify the tokenRequestRenewalOption section to include:

```yaml
tokenRequestRenewalOption:
  renewTokenRequestInterval: 1h0m0s
  saName: cluster-admin
  saNamespace: projectsveltos
```

Ensure that the specified ServiceAccount has the necessary permissions.

## Example: GKE

To connect a Google Kubernetes Engine (GKE) cluster to Sveltos, first use `sveltosctl` to create a temporary Kubeconfig file for the GKE cluster:

```
sveltosctl  generate kubeconfig --create --expirationSeconds=86400 >  /tmp/GKE/kubeconfig
```

Remember that GKE's maximum expiration time for Kubeconfig files is 48 hours (172800 seconds).

Next, point sveltosctl to your Sveltos management cluster and register the GKE cluster:

```
sveltosctl register cluster --namespace=gke --cluster=cluster --kubeconfig=/tmp/GKE/kubeconfig --labels=env=production
```

If we leave as it is, in 48 hours the Kubeconfig will expire. 
To prevent the Kubeconfig from expiring and disrupting Sveltos' management of the GKE cluster, you can configure Sveltos to automatically renew the Kubeconfig.

Edit the SveltosCluster __cluster__ in the __gke__ namespace:

```
kubectl edit sveltoscluster -n gke cluster
```

Add or modify the `tokenRequestRenewalOption` section to include:

```yaml
  tokenRequestRenewalOption:
    renewTokenRequestInterval: 1h0m0s
    saName: cluster-admin
    saNamespace: projectsveltos
```

This assumes that the ServiceAccount __cluster-admin__ exists in the __projectsveltos__ namespace  on the GKE cluster and has the necessary permissions for Sveltos to deploy applications and add-ons to the cluster.

With this configuration, Sveltos will generate a new token tied to the ServiceAccount and use it to create a new Kubeconfig every hour, ensuring continuous cluster management.

The `SveltosCluster.Status` field provides information about the last time the token was renewed:

```yaml
 status:
    connectionStatus: Healthy
    lastReconciledTokenRequestAt: "2024-10-08T07:36:42Z"
```
