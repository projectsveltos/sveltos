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
Sveltos comes with support to automatically discover [ClusterAPI](https://github.com/kubernetes-sigs/cluster-api) powered clusters. If Sveltos is deployed in a management cluster with ClusterAPI (CAPI), no further action is required for Sveltos to manage add-ons on CAPI-powered clusters. Sveltos will watch for *clusters.cluster.x-k8s.io"* instances and program those accordingly.

Other clusters (on-prem, Cloud) can registered with Sveltos easily. Afterwards, Sveltos can [manage Kubernetes add-ons](../addons/addons.md) on all the clusters seamlessly.

## Register Cluster

If you already have an existing cluster and you want Sveltos to manage it, three simple steps are required:

1. In the cluster to be managed by Sveltos, generate a *ServiceAccount* for Sveltos and generate a kubeconfig associated with that account. Store the kubeconfig in a file locally;
2. In the management cluster, create, if not existing, the namespace where you want to register your external cluster;
3. Point sveltosctl to the management cluster, use *sveltosctl register cluster* command passing the file containing the kubeconfig generated in the step above. Sveltoctl will generate all necessary Kubernetes resources (SveltosCluster and Secret) in the management cluster. For instance:

```
$ sveltosctl register cluster --namespace=<namespace> --cluster=<cluster name> \
    --kubeconfig=<path to file with Kubeconfig>
``` 

It is recommended, but not required, to use the [sveltosctl](https://github.com/projectsveltos/sveltosctl "Sveltos CLI") to register a cluster.

**Please note:** If you are unsure how to generate a Kubernetes ServiceAccount and a kubeconfig associated with it, have a look at the [script: get-kubeconfig.sh](https://raw.githubusercontent.com/gianlucam76/scripts/master/get-kubeconfig.sh) [^1]. Read the script comments to get more clarity on the use and expected outcomes.

An alternative is to manually create:

1. Secret with name ```<cluster-name>-sveltos-kubeconfig``` with Data section containing the Kubeconfig
2. SveltosCluster instance (only name needs to be set)

## Register Civo Cluster
If you use [Civo Cloud](https://www.civo.com), simply download the cluster Kubeconfig and perform the below.

```
$ sveltosctl register cluster --namespace=<namespace> --cluster=<cluster name> \
    --kubeconfig=<path to file with Kubeconfig>
```

## Register GKE Cluster

Follow the below steps to register a GKE cluster with Sveltos.

1. gcloud auth login
2. gcloud container clusters get-credentials <CLUSTER NAME\> --region=<REGION\> --project=<PROJECT NAME\>
3. kubectl cluster-info
4. Copy [https://raw.githubusercontent.com/gianlucam76/scripts/master/get-kubeconfig.sh](https://raw.githubusercontent.com/gianlucam76/scripts/master/get-kubeconfig.sh) [^1] locally. The steps above ensure your local kubectl is pointing to the GKE cluster. Run the script. It will generate the `projectsveltos` namespace, the `projectsveltos-sa` ServiceAccount and the ClusterRoleBinding `sveltos-crb` that binds ServiceAccount to the `cluster-admin` ClusterRole. Then it generates the kubeconfig associated with such ServiceAccount and stores it locally;
5. Run *sveltosctl register cluster* command pointing it to the kubeconfig file generated by the step above.

**Please note:** The script is giving Sveltos cluster-admin privileges (that is done because we do not know in advance which add-ons you want Sveltos to deploy). You might choose to give Sveltos fewer privileges. Just keep in mind that it needs enough privileges to deploy the add-ons you request to deploy.

## Register RKE2 Cluster
If you use Rancher's next-generation Kubernetes distribution [RKE2](https://docs.rke2.io/), you will only need to download the kubeconfig either from the Rancher UI under the Cluster Management section or via SSH into the RKE2 Cluster and under the */etc/rancher/rke2/rke2.yaml* directory. Run the below command.

```
$ sveltosctl register cluster --namespace=<namespace> --cluster=<cluster name> \
    --kubeconfig=<path to file with Kubeconfig>
```

[^1]: This script was developed by [Gravitational Teleport](https://github.com/gravitational/teleport/blob/master/examples/k8s-auth/get-kubeconfig.sh). We simply slightly modified to fit Sveltos use case.
