---
title: Register Cluster Pull Mode
description: Sveltos can register clusters that are behind a firewall, in air-gapped or edge environments, and in highly regulated setups using Pull Mode.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
authors:
    - Eleni Grosdouli
---

!!!video
    To learn more about the Sveltos **Pull Mode**, check out the [Youtube Video](https://www.youtube.com/watch?v=Y3dW5XYjg5I&amp;feature=youtu.be). If you find this valuable, we would be thrilled if you shared it! 😊


## Sveltos Cluster Registration Pull Mode

Sveltos supports managed cluster registration in **Pull Mode**. In this model, **managed** clusters actively **pull** configuration and add-ons from a central source, rather than having the management cluster push them directly to the managed clusters.

The **Pull Mode** is ideal for managed clusters behind a firewall, in air-gapped environments, edge deployments with limited bandwidth or highly regulated and secure setups.

If Sveltos is not already installed, have a look at the installation details located [here](../getting_started/install/install.md).

## How does it work?

While the core Sveltos controllers run in a **management** cluster and orchestrate deployments, the concept of **Pull Mode** becomes relevant when managing clusters in challenging network environments such as firewalled, air-gapped, or edge deployments, where direct inbound access from the management cluster to the managed clusters is either not possible or not desired.

This is how the **Pull Mode** flow works:

1. **Management Cluster**: It defines the desired state. We define our `ClusterProfile`/`Profile` resources in the management cluster, specifying which add-ons and configurations should be applied to which managed clusters by utilising the Kubernetes labels selection concept.
1. **Managed Cluster**: Rather than the management cluster initiating all deployments, a component on the managed cluster initiates a connection to the management cluster.
1. **Configuration Fetching**: The managed cluster pulls the relevant configuration, manifest, or Helm chart **from** the **management** cluster. The **management** cluster prepares the relevant configuration bundle for the managed clusters in Pull Mode.
1. **Apply**: The managed cluster's local agent applies the pulled configurations to the cluster.

![Sveltos Pull Mode](../assets/sveltos_pull_mode.png)

### Advantages

The following items are some of the benefits of utilising Sveltos in **Pull Mode**.

- **Firewalled and Air-Gapped Environments**: This is the primary driver. When managed clusters are behind firewalls or in air-gapped networks, direct inbound connections from a central management cluster are not possible. Sveltos in **Pull Mode** allows the managed clusters to reach out to the management cluster or a Git repository to obtain deployment instructions.
- **Edge Deployments**: For edge locations with intermittent connectivity or limited network bandwidth, the Sveltos **Pull Mode** offers resilience.
- **Security**: Reducing the need for inbound ports to managed clusters enhances the security posture of an environment by minimising the attack surface.

## Register Cluster

To register a cluster in Pull mode, we use the [sveltosctl](https://github.com/projectsveltos/sveltosctl "Sveltos CLI").

### Management Cluster

Pointing the KUBECONFIG to the **management** cluster where Sveltos is installed, perform the following `sveltosctl register` command.

```bash
$ export KUBECONFIG=</path/to/kubeconfig/management/cluster>

$ sveltosctl register cluster \
    --namespace=monitoring \
    --cluster=prod-cluster \
    --pullmode \
    --labels=environment=production,tier=backend \
    > sveltoscluster_registration.yaml
```

| Parameter        |    Description                                                                                                   |
|------------------|------------------------------------------------------------------------------------------------------------------|
| `--namespace`    |    The namespace in the **management** cluster where Sveltos stores information about the registered cluster.    |
| `--cluster`      |    The name of the cluster to identify the registered cluster within Sveltos.                                               |
| `--pullmode`     |    Enables the Sveltos **Pull Mode** registration.                                                                   |
| `--labels`       |    (Optional) Comma-separated key-value pairs to define labels for the registered cluster.                       |

When the command is executed, looking at the `sveltosclusters` resource, we do see a new instance called `prod-cluster` in a not "Ready" state. This is the expected behaviour as we register the cluster in **Pull Mode**. Feel free to look at the generated file and identify what resources will be created for the **managed** cluster.

```bash
$ kubectl get sveltoscluster -n monitoring
NAMESPACE   NAME           READY   VERSION   AGE
monitoring  prod-cluster                     1m7s
```

### Managed Cluster

Apply the generated file to the **managed** cluster.

```bash
$ export KUBECONFIG=</path/to/kubeconfig/managed/cluster>

$ kubectl apply -f sveltoscluster_registration.yaml
namespace/projectsveltos created
serviceaccount/sveltos-applier-manager created
clusterrole.rbac.authorization.k8s.io/sveltos-applier-manager-role created
clusterrolebinding.rbac.authorization.k8s.io/sveltos-applier-manager-rolebinding created
service/sveltos-applier-metrics-service created
deployment.apps/sveltos-applier-manager created
secret/pcluster01-sveltos-kubeconfig created
```

!!!note
    Test the **Pull Mode** with up to **two** managed clusters for free. Need more than two clusters? Contact us at `support@projectsveltos.io` to explore license options based on your needs!

### Validation

```bash
$ export KUBECONFIG=</path/to/kubeconfig/management/cluster>

$ kubectl get sveltoscluster -n monitoring
NAMESPACE   NAME           READY   VERSION    AGE
monitoring  prod-cluster   true    v1.30.5    9m15s
```
