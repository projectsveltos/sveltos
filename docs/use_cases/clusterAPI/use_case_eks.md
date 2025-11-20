---
title: Sveltos - Kubernetes Add-on Controller | Manage Kubernetes Add-ons with Ease | Cluster API clusters on EKS
description: Sveltos allows you to use Cluster API resources and automated the deployment of customised Kubernetes clusters on Elastic Kubernetes Service (EKS).
tags:
    - Kubernetes
    - add-ons
    - helm
    - kustomize
    - clusterapi
    - multi-tenancy
    - Sveltos
authors:
    - Gianluca Mardente
    - Eleni Grosdouli
---

## Scenario

Imagine a scenario where we need to provide dedicated Kubernetes environments to individual users or teams on demand. Manually creating and managing these clusters can be time-consuming and error-prone. We will demonstrate how to automate this process using a powerful combination of [**ArgoCD**](https://argo-cd.readthedocs.io/en/stable/), **Sveltos**, and [**Cluster API**](https://cluster-api.sigs.k8s.io/).

The goal is to set up a GitOps workflow where adding a new user via a Pull/Merge request triggers the automatic provisioning of a dedicated [Elastic Kubernetes Service (EKS)](https://aws.amazon.com/eks/) cluster. ArgoCD will keep the management cluster in the right state. Sveltos will spot changes and manage cluster creation. Meanwhile, Cluster API will take care of setting up the EKS clusters. This is a hands-on turotial building a robust and scalable cluster provisioning pipeline. 

## Github Resources

The code examples are located in the [GitHub repository](https://github.com/gianlucam76/devops-tutorial/tree/main/argocd-sveltos-clusterapi-eks).

## Diagram

![ArgoCD, Sveltos and Cluster API on EKS](../../assets/argocd-sveltos-clusterapi-eks.png)

## Prerequisites
- A Kubernetes management cluster
- Familiarity with ArgoCD and the Cluster API
- kubectl installed
- clusterctl installed
- argocd installed
- sveltosctl installed (optional)

## Step 1: Install Cluster API on the Management Cluster

For this demonstration, a Kind cluster will be used as our management cluster. Let's begin by deploying Cluster API using the AWS Infrastructure Provider.

### AWS credentials

```bash
$ export AWS_ACCESS_KEY_ID=<YOUR ACCESS KEY>
$ export AWS_SECRET_ACCESS_KEY=<YOUR SECRET ACCESS KEY>
$ export AWS_B64ENCODED_CREDENTIALS=$(clusterawsadm bootstrap credentials encode-as-profile)
```

### Initialise Cluster API

```bash
$ export AWS_REGION=us-east-1
$ export EKS=true
$ export EXP_MACHINE_POOL=true
$ export CAPA_EKS_IAM=true
$ export AWS_CONTROL_PLANE_MACHINE_TYPE=t3.large
$ export AWS_NODE_MACHINE_TYPE=t3.large
$ export AWS_REGION=us-east-1
$ export AWS_SSH_KEY_NAME=capi-eks

$ clusterctl init --infrastructure aws
```

## Step 2: Install ArgoCD on the Management Cluster

There are many options available to install ArgoCD on a cluster. For this demonstration, we will use the simplest possible option, the manifest approach. For more information about the different ArgoCD installation details, have a look [here](https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/).


```bash
$ kubectl create namespace argocd
$ kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
$ kubectl config set-context --current --namespace=argocd
$ kubectl port-forward svc/argocd-server -n argocd 8080:443
```

!!!note
    The admin password to connect to ArgoCD dashboard is in the Secret named `argocd-initial-admin-secret` in the argocd namespace.

## Step 3: Deploy Sveltos

We will leverage ArgoCD to automate the deployment of Sveltos to our management Kubernetes cluster.

```bash
$ argocd app create sveltos --repo https://github.com/projectsveltos/helm-charts.git --path charts/projectsveltos --dest-server https://kubernetes.default.svc --dest-namespace projectsveltos
```

This tells ArgoCD to create an application called sveltos. It will get the Sveltos Helm chart from the specified GitHub repository and deploy it to the projectsveltos namespace in the management cluster. Next, we will deploy the Sveltos configurations using ArgoCD.

```bash
$ argocd app create sveltos-configuration --repo https://github.com/gianlucam76/devops-tutorial.git --path argocd-sveltos-clusterapi-eks --dest-server https://kubernetes.default.svc
```

The Sveltos configuration establishes a dynamic cluster creation process. First, it monitors a ConfigMap named `existing-users` within the default namespace. The ConfigMap maintains a list of users, each entry formatted as user-id: cluster-type, where cluster-type designates either production or staging. When Sveltos spots a new user entry in this ConfigMap, it triggers the deployment of a Cluster API configuration. This then starts the creation of a new EKS cluster. Each newly created cluster will be labeled as `type:cluster-type`, allowing Sveltos to immediately apply the appropriate configuration, whether for **production** or **staging** environments, based on the cluster's label.

Before we proceed further, let us label the management cluster with `type: mgmt`.

```bash
$ kubectl label sveltoscluster -n mgmt mgmt type=mgmt
```

## Step 4: Push a PR to add a new user

To add a new user and trigger the creation of a corresponding EKS cluster, we will implement a straightforward GitOps workflow. First, we will submit a pull request (PR)/Merge Request that modifies the existing-users.yaml ConfigMap within our repository. Specifically, this PR will introduce a new user entry, `user1: production`, within the data section of the ConfigMap, as shown in the provided diff.

```bash
$ diff --git a/argocd-sveltos-clusterapi-eks/existing-users.yaml b/argocd-sveltos-clusterapi-eks/existing-users.yaml
index ab0d862..10987b3 100644
--- a/argocd-sveltos-clusterapi-eks/existing-users.yaml
+++ b/argocd-sveltos-clusterapi-eks/existing-users.yaml
@@ -3,3 +3,5 @@ kind: ConfigMap
 metadata:
   name: existing-users
   namespace: default
+data:
+  user1: production
```

Once the PR is merged, we will instruct ArgoCD to synchronise these changes to the management cluster. The synchronisation will update the ConfigMap. This signals Sveltos to start provisioning a new production EKS cluster for `user1` using Cluster API.

![ArgoCD, Sveltos and Cluster API on EKS](../../assets/capi_eks_gitops.gif)

## Step 5: Sveltos triggers creation of a new EKS cluster

Sveltos will immediately detect the new user entry, `user1: production`. This detection triggers Sveltos to deploy all the necessary Cluster API resources to the management cluster, effectively orchestrating the creation of a new EKS cluster. Executing the ```sveltosctl show addons``` command, we will get a list of deployed resources.

```bash
$ sveltosctl show addons --namespace=user1
+----------------------+--------------------------+--------------+---------------------+---------+-------------------------------+------------------------------------------+
|       CLUSTER        |      RESOURCE TYPE       |  NAMESPACE   |        NAME         | VERSION |             TIME              |                 PROFILES                 |
+----------------------+--------------------------+--------------+---------------------+---------+-------------------------------+------------------------------------------+
| user1/capi-eks-user1 | helm chart               | cert-manager | cert-manager        | v1.16.3 | 2025-03-04 12:28:00 +0100 CET | ClusterProfile/deploy-cert-manager       |
| user1/capi-eks-user1 | helm chart               | prometheus   | prometheus          | 26.0.0  | 2025-03-04 12:29:20 +0100 CET | ClusterProfile/prometheus-grafana        |
| user1/capi-eks-user1 | helm chart               | grafana      | grafana             | 8.6.4   | 2025-03-04 12:29:29 +0100 CET | ClusterProfile/prometheus-grafana        |
| user1/capi-eks-user1 | helm chart               | kyverno      | kyverno-latest      | 3.3.4   | 2025-03-04 12:28:50 +0100 CET | ClusterProfile/deploy-kyverno-production |
| user1/capi-eks-user1 | kyverno.io:ClusterPolicy |              | disallow-latest-tag | N/A     | 2025-03-04 12:29:19 +0100 CET | ClusterProfile/deploy-kyverno-resources  |
+----------------------+--------------------------+--------------+---------------------+---------+-------------------------------+------------------------------------------+
```

### Sveltos Dashboard View

![ArgoCD, Sveltos and Cluster API on EKS](../../assets/sveltos_dashboard_eks_cluster.png)

## Step 6: Sveltos deploys production policies

Once Cluster API completes the provisioning of the new EKS cluster, Sveltos will automatically deploy the add-ons configured for a production environment. The deploy deployments are included.

1. `cert-manager` Helm chart, to manage and issue TLS certificates.
1. `kyverno` Helm chart, for policy-based control of Kubernetes resources.
1. `Prometheus` and `Grafana` Helm charts, to provide monitoring and visualization capabilities.
1. A kyverno admission policy specifically configured to disallow-latest-tag, enforcing the use of explicit image tags for container deployments.

```bash
$ sveltosctl show addons --namespace=user1
+----------------------+--------------------------+--------------+---------------------+---------+-------------------------------+------------------------------------------+
|       CLUSTER        |      RESOURCE TYPE       |  NAMESPACE   |        NAME         | VERSION |             TIME              |                 PROFILES                 |
+----------------------+--------------------------+--------------+---------------------+---------+-------------------------------+------------------------------------------+
| user1/capi-eks-user1 | helm chart               | cert-manager | cert-manager        | v1.16.3 | 2025-03-04 12:28:00 +0100 CET | ClusterProfile/deploy-cert-manager       |
| user1/capi-eks-user1 | helm chart               | prometheus   | prometheus          | 26.0.0  | 2025-03-04 12:29:20 +0100 CET | ClusterProfile/prometheus-grafana        |
| user1/capi-eks-user1 | helm chart               | grafana      | grafana             | 8.6.4   | 2025-03-04 12:29:29 +0100 CET | ClusterProfile/prometheus-grafana        |
| user1/capi-eks-user1 | helm chart               | kyverno      | kyverno-latest      | 3.3.4   | 2025-03-04 12:28:50 +0100 CET | ClusterProfile/deploy-kyverno-production |
| user1/capi-eks-user1 | kyverno.io:ClusterPolicy |              | disallow-latest-tag | N/A     | 2025-03-04 12:29:19 +0100 CET | ClusterProfile/deploy-kyverno-resources  |
+----------------------+--------------------------+--------------+---------------------+---------+-------------------------------+------------------------------------------+
```

### Sveltos Dashboard View

![ArgoCD, Sveltos and Cluster API on EKS](../../assets/sveltos_dashboard_eks_cluster_dep_helm.png)

## Step 7: Removing user

Just as easily as we created a cluster by adding a user, we can remove a user and, consequently, delete their associated EKS cluster. This is achieved through the same GitOps workflow, but in reverse.

To remove a user, we simply submit a pull request (PR)/Merge Request that removes the user's entry from the existing-users.yaml ConfigMap. For example, to remove user1, we would revert the changes we made in Step 4. Once this PR is merged and Argo CD synchronizes the changes to the management cluster, Sveltos detects the removal of the user from the ConfigMap.

Sveltos, upon detecting this change, proceeds to delete all the Cluster API resources it previously deployed for that user. This includes the `Cluster`, `AWSManagedCluster`, `AWSManagedControlPlane`, `MachinePool`, and `AWSManagedMachinePool` resources within the user's namespace (in this case, "user1").

Because Cluster API operates declaratively, deleting these resources triggers the deletion of the underlying EKS cluster. ClusterAPI's AWS infrastructure provider interprets the removal of these resources as a request to terminate the corresponding cloud resources.

Therefore, by simply removing the user entry from the existing-users.yaml ConfigMap and allowing ArgoCD and Sveltos to synchronise the changes, we effectively automate the entire lifecycle of the EKS cluster, from creation to deletion. This ensures that resources are efficiently managed and that orphaned clusters are avoided, maintaining a clean and cost-effective environment.

## Conclusion

In this tutorial, we demonstrated how to build a fully automated, GitOps-driven pipeline for provisioning dedicated EKS clusters on demand. We used ArgoCD, Sveltos, and Cluster API to create a strong, scalable solution. This approach removes the manual work and reduces errors linked to traditional cluster management.

ArgoCD maintains the desired state of our management cluster, ensuring that all configurations are synchronized with our Git repository.
Sveltos acts as a dynamic orchestrator, detecting changes in our user configuration and triggering the creation of new EKS clusters.
Cluster API handles the heavy lifting of provisioning and managing the EKS clusters themselves, providing a consistent and declarative approach.
