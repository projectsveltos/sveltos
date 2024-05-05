---
title: Sveltos - Troubleshooting Section
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative cluster APIs. Learn here how to install Sveltos.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
    - troubleshooting
authors:
    - Eleni Grosdouli
---

## Introduction
In this section, we will help Sveltos users identify ways to troubleshoot the Sveltos installation alongside deployed add-ons down the different clusters. In general, it is a good practice to get the Sveltos version alongside the `sveltosctl` version (if used) as it is helpful for the team to provide better assistance and recommendations.

### Sveltos Version
```bash
$ kubectl get job register-mgmt-cluster-job -n projectsveltos -o=jsonpath='{.spec.template.spec.containers[0].image}'
```

### sveltosctl Version
```bash
$ sveltosctl version
I0428 09:05:01.496691 2181388 version.go:64] "Client Version:   v0.27.0-17-2fb25f7e7a15a3"
I0428 09:05:01.496715 2181388 version.go:65] "Git commit:       2fb25f7e7a15a3adc351e569f79ec1f80ae1ac7e" 
```

## Common Issues

## Sveltos ClusterProfile, Profile is not applied to the cluster/s
This is a very common case scenario where the deployed Sveltos `ClusterProfile`, and `Profile` resources are deployed to the targeted cluster/s. This might be due to an issue with the Sveltos installation, incorrect Sveltos namespace installation, incorrect `cluster-label` set to the cluster or something else that might be disallowing the deployment.

### Sveltos Installation Namespace
It is a **requirement** for Sveltos to get installed in the `projectsveltos` namespace. If Sveltos is installed in a different namespace, issues with the Kubernetes resources deployment will arise.

### Check the Overall Sveltos Installation (Management Cluster)
```bash
$ kubectl get pods -n projectsveltos
```

All the pods need to be in a `Running` state. If a pod is in a different state, perform the below commands to get a better understanding. The Events section or the logs provided by the pod will be sufficient to get an understanding of what might be failing.

```bash
$ kubectl describe pod <pod-name> -n projectsveltos

$ kubectl logs <pod-name> -n projectsveltos -f
```

### Check Sveltos Registered Clusters
```bash
$ kubectl get sveltosclusters -A
```

Ensure the Sveltos clusters are in a `READY=true` state. If Sveltos is unable to communicate with a cluster, we will see spot it directly from the output above.

#### Healthy Cluster State
```bash
$ kubectl get sveltoscluster -A
NAMESPACE        NAME            READY   VERSION
projectsveltos   vcluster-dev    true    v1.29.0+k3s1
projectsveltos   vcluster-prod   true    v1.29.0+k3s1
mgmt             mgmt            true    v1.28.7+k3s1
```

#### Unhealthy Cluster State
```bash
$ kubectl get sveltoscluster -A
NAMESPACE        NAME            READY   VERSION
projectsveltos   vcluster-dev
mgmt             mgmt            true    v1.28.7+k3s1
```

In the output above, we can spot that the `vcluster-dev` cluster in the `projectsveltos` namespace is not in a `READY` state. That could mean network issues disallowing communication with the cluster or something is wrong with the cluster itself.

### How to work with an Unhealthy Cluster?

#### Step 1: Ensure the correct kubeconfig provided
This would mean that during the registration of the cluster, the provided kubeconfig is sufficient to authenticate with the clusters.

On a new terminal, perform the below.

```bash
$ export KUBECONFIG=<directory of the provided cluster kubeconfig>
$ kubectl get nodes
$ kubectl get pods -A
```

If you are not able to reach the cluster via the specified kubeconfig file, it could be an invalid kubeconfig. Doublecheck the file generated and ensure is the correct one.

#### Step 2: Network Connectivity
If `Step 1` is fine and we can access the cluster resources with the `kubeconfig`, continue the investigation with the network and firewall setup in the environment. Ensure nothing is blocking the traffic from the management cluster to the managed cluster.

**Note:** In specific Operating Systems (Suse Enterprise Linux), the security hardening disallowed the `sveltosctl` to validate and register the cluster due to the certificate issue. In this case, we have to import the cluster certificate to the trusted store.

### Check Labels set to Registered Clusters

```bash
$ kubectl get sveltosclusters -A --show-labels
```
Ensure the labels set to the Sveltos clusters do match the labels defined in the Sveltos `ClusterProfile`, `Profile`.

If the cluster labels are incorrect, we can overwrite them with the below command.

```bash
$ kubectl label sveltoscluster <cluster-name> -n <cluster namespace> env=dev --overwrite
```
- `env=dev` is the new label set to the cluster

### Check ClusterSummary, ClusterProfile, Profile Kubernetes Resources
Every time Sveltos deploys a `Profile` or a `ClusterProfile`, a `clustersummary`,  a `clusterprofile` or a `profile` Kubernetes resources are created. We can check the status of the resources and try to understand what is failing.

#### Validate 
```bash
$ sveltosctl show addons
```

We assume the output above is empty. This implies that Sveltos was not able to deploy an add-on to a cluster or a set of clusters. Continue with the `clusterprofiles` and `clustersummary` resource investigation.

```bash
$ kubectl get clustersummary,clusterprofile -A
```

Even if the Kubernetes add-ons are not deployed, both resources will be available to the management cluster.

```bash
$ k get clusterprofile <clusterprofile name> -n <clusterprofile namespace> -o jsonpath='{.status}'
```

```bash
$ k get clustersummary <clustersummary name> -n <clustersummary namespace> -o jsonpath='{.status}'
```

We are here to help! Whether you have questions, or issues or need assistance, our Slack channel is the perfect place for you. Click [here](https://app.slack.com/client/T0471SNT5CZ/C06UZCXQLGP) to join us.
