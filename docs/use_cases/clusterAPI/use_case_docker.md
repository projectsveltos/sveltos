---
title: Sveltos - Kubernetes Add-on Controller | Manage Kubernetes Add-ons with Ease | Cluster API clusters on Docker
description: Sveltos allows you to use Cluster API resources and automate the deployment of customised Kubernetes clusters on Docker.
tags:
    - Kubernetes
    - add-ons
    - helm
    - kustomize
    - clusterapi
    - multi-tenancy
    - Sveltos
authors:
    - Eleni Grosdouli
---

## Scenario

In previous scenarios, [Cluster API on EKS](./use_case_eks.md) and [Cluster API on Azure](./use_case_azure.md), we demonstrated how easy it is to deploy Kubernetes clusters across different hyperscalers using Sveltos and following a GitOps approach. But there are times when we need a local development environment running on a local machine using [Docker](https://www.docker.com/).

In this post, we will outline how to automate local development environments using Docker, Kind, Cluster API (CAPI), and Sveltos!

If you are not familiar with CAPI, take a look at the [CAPI Github repository](https://github.com/kubernetes-sigs/cluster-api) and the [getting started guide](https://cluster-api.sigs.k8s.io/).

## Github Resources

The full code examples are located in the [GitHub repository](https://github.com/egrosdou01/blog-post-resources/tree/main/capi-docker-sveltos).

## Diagram

![Sveltos and Cluster API on Docker](../../assets/capd.png)

## Prerequisites
- Docker and [Kind](https://kind.sigs.k8s.io/docs/user/quick-start/) are installed
- kubectl installed
- clusterctl installed
- Familiarity with CAPI

## Step 1: Create a Kind Management Cluster

As mentioned in the beginning, we can work on local development environments. For that reason, we will create a Kind cluster that can run on top of Docker.

```yaml
cat > kind-cluster-with-extramounts.yaml <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: mgmt
nodes:
- role: control-plane
  extraMounts:
    - hostPath: /var/run/docker.sock
      containerPath: /var/run/docker.sock
EOF
```

```bash
$ kind create cluster --config kind-cluster-with-extramounts.yaml --kubeconfig=/path/to/store/kubeconfig

$ export KUBECONFIG=/path/to/mgmt/kubeconfig
```

## Step 2: Initialise and Deploy CAPI Management Cluster

Let us begin by deploying CAPI using the Docker Infrastructure Provider.

```bash
$ export CLUSTER_TOPOLOGY=true # Used to enable support for managed topologies and ClusterClass
$ clusterctl init --infrastructure docker
```

## Step 3: Install ArgoCD on the Management Cluster

There are different ways to install ArgoCD on a Kubernetes cluster. For this demonstration, we will use the simplest option, the manifest installation. For more information about the different ArgoCD installation options, have a look [here](https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/).


```bash
$ kubectl create namespace argocd
$ kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
$ kubectl config set-context --current --namespace=argocd
$ kubectl port-forward svc/argocd-server -n argocd 8080:443 # Optional to get a glimpse of the ArgoCD UI
```

!!!note
    The admin password for the ArgoCD dashboard is in the Secret called `argocd-initial-admin-secret` in the argocd namespace.

## Step 4: Deploy Sveltos

We will leverage ArgoCD to automate the deployment of Sveltos to our management Kubernetes cluster.

```bash
$ argocd app create sveltos --repo https://github.com/projectsveltos/helm-charts.git --path charts/projectsveltos --dest-server https://kubernetes.default.svc --dest-namespace projectsveltos
```

Then, we will use the ArgoCD `Application` resource to set the location of our configuration related to CAPI and Sveltos. This will ensure ArgoCD deploys the configuration to the management cluster and keeps any code changes up to date. 

```bash
$ argocd app create sveltos-configuration --repo https://github.com/egrosdou01/blog-post-resources.git --path capi-azure-sveltos/pt3/ --dest-server https://kubernetes.default.svc
```

The Sveltos configuration establishes a dynamic cluster creation process. Sveltos monitors a ConfigMap named `existing-users` in the `default` namespace. The resource keeps a list of users. Each entry shows the user's name, the type of environment, and the CAPI version to be deployed. When Sveltos spots a new user entry, it triggers the deployment of a CAPI configuration and creates a managed Kubernetes cluster in the Azure cloud.

To allow Sveltos to manage resources in the Kubernetes management cluster, we will add the label `type: mgmt` to the cluster.

```bash
$ kubectl label sveltoscluster mgmt -n mgmt type=mgmt
```

## Step 4: Push a PR/Merge Request to add a new user

To add a new user and trigger the creation of a corresponding Kubernetes cluster on Docker, we will implement a straightforward GitOps workflow. We will submit a Pull Request (PR)/Merge Request that modifies the `existing-users` ConfigMap within the previously defined repository. The PR will introduce a new user entry, `user01: test`, within the data section of the ConfigMap.
```yaml
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: existing-users
  namespace: default
data:
  user01: |
    env: test
  # user02: |
  #   env: staging
```

Once the PR is merged, ArgoCD will synchronise the changes to the Kubernetes management cluster. The synchronisation updates the ConfigMap. This signals Sveltos to start provisioning a new Kubernetes cluster for `user01` using CAPI.

## Step 5: Install Cilium as Container Network Interface (CNI)

By the time one of the controller nodes is available and the kube-api is reachable, Sveltos installs [Cilium](https://docs.cilium.io/en/stable/index.html) as our CNI. Everything is controlled by Sveltos using the below `ClusterProfile`, and there is no need for manual interventions.

```yaml
---
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: deploy-capd-managed
spec:
  clusterSelector:
    matchExpressions:
    - { key: env, operator: In, values: [ test, staging ] }
  syncMode: Continuous
  helmCharts:
  - chartName: cilium/cilium
    chartVersion: 1.18.5
    helmChartAction: Install
    releaseName: cilium
    releaseNamespace: kube-system
    repositoryName: cilium
    repositoryURL: https://helm.cilium.io/
    values: |
      kubeProxyReplacement: true
```

## Step 6: Remove a User

To remove a user, update the `existing-users` ConfigMap. Then, submit a PR and merge the code. After that, let ArgoCD sync the change to the management cluster. Sveltos will handle the rest! Again, no magic, only Sveltos goodness!

## Conclusion

In a few steps, we demonstrated how engineers can use Sveltos with CAPI on Docker following a GitOps approach to create scalable, maintainable, and easily managed Kubernetes clusters with versioned, auditable deployments.