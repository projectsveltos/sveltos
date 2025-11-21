---
title: Sveltos - Kubernetes Add-on Controller | Manage Kubernetes Add-ons with Ease | Cluster API clusters on Azure cloud
description: Sveltos allows you to use Cluster API resources and automated the deployment of customised Kubernetes clusters on Azure cloud.
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

We showed [before](use_case_eks.md) how Sveltos works with any [GitOps controller](https://glossary.cncf.io/gitops/) and [Cluster API (CAPI)](https://cluster-api.sigs.k8s.io/) to automate Kubernetes cluster lifecycles. In this demonstration, we will focus on the Azure cloud.

## Github Resources

The code example is located in the [GitHub repository](https://github.com/egrosdou01/blog-post-resources/tree/main/capi-azure-sveltos/pt3).

## Diagram

![ArgoCD, Sveltos and Cluster API on EKS](../../assets/capi_sveltos_azure.jpg)

## Prerequisites
- A Kubernetes management cluster
- Familiarity with ArgoCD and CAPI
- kubectl installed
- clusterctl installed
- argoctl installed

## Step 1: Install CAPI on the Management Cluster

For this demonstration, a Kind cluster is used. Let us begin by deploying CAPI using the AWS Infrastructure Provider.

### Azure Cloud credentials

```bash
$ export AZURE_SUBSCRIPTION_ID="<your azure subscription ID>"

$ export AZURE_TENANT_ID="<your azure tenant ID>"
$ export AZURE_CLIENT_ID="<the client ID generated with the creation of the app in the previous step>"
$ export AZURE_CLIENT_ID_USER_ASSIGNED_IDENTITY=$AZURE_CLIENT_ID
$ export AZURE_CLIENT_SECRET="<the client Secret generated with the creation of the app in the previous step>"
```

### Azure Secret

```bash
$ export AZURE_CLUSTER_IDENTITY_SECRET_NAME="cluster-identity-secret"
$ export CLUSTER_IDENTITY_NAME="cluster-identity"
$ export AZURE_CLUSTER_IDENTITY_SECRET_NAMESPACE="default"

$ kubectl create secret generic "${AZURE_CLUSTER_IDENTITY_SECRET_NAME}" --from-literal=clientSecret="${AZURE_CLIENT_SECRET}" --namespace "${AZURE_CLUSTER_IDENTITY_SECRET_NAMESPACE}"
```

### Initialise CAPI

```bash
$ export CLUSTER_TOPOLOGY=true # Optional used to enable support for managed topologies and ClusterClass
$ clusterctl init --infrastructure azure
```

## Step 2: Install ArgoCD on the Management Cluster

There are different ways to install ArgoCD on a Kubernetes cluster. For this demonstration, we will use the simplest option, the manifest installation. For more information about the different ArgoCD installation options, have a look [here](https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/).


```bash
$ kubectl create namespace argocd
$ kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
$ kubectl config set-context --current --namespace=argocd
$ kubectl port-forward svc/argocd-server -n argocd 8080:443 # Optional to get a glimpse of the ArgoCD UI
```

!!!note
    The admin password for the ArgoCD dashboard is in the Secret called `argocd-initial-admin-secret` in the argocd namespace.

## Step 3: Deploy Sveltos

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

## Step 4: Push a PR to add a new user

To add a new user and trigger the creation of a corresponding Azure cluster, we will implement a straightforward GitOps workflow. We will submit a Pull Request (PR)/Merge Request that modifies the `existing-users` ConfigMap within the previously defined repository. The PR will introduce a new user entry, `user01: production`, within the data section of the ConfigMap, as shown in the provided diff.

```bash
$ diff --git a/capi-azure-sveltos/pt3/kubernetes_resources/cm_users.yaml b/capi-azure-sveltos/pt3/kubernetes_resources/cm_users.yaml
index ab0d862..10987b3 100644
--- a/capi-azure-sveltos/pt3/kubernetes_resources/cm_users.yaml
+++ b/capi-azure-sveltos/pt3/kubernetes_resources/cm_users.yaml
@@ -7,7 +7,7 @@ data:
-  #user01: |
-  # env: staging
-  # version: "1.34.1"
+  user01: |
+    env: staging
+    version: "1.34.1"
   #user02: |
   # env: staging
   # version: "1.34.0"
```

Once the PR is merged, ArgoCD will synchronise the changes to the Kubernetes management cluster. The synchronisation updates the ConfigMap. This signals Sveltos to start provisioning a new production Azure cluster for `user01` using CAPI.

## Step 5: Install Cilium as Container Network Interface (CNI)

By the time one of the controller nodes is available and the kube-api is reachable, Sveltos installs [Cilium](https://docs.cilium.io/en/stable/index.html) as our CNI alongside the `cloud-provider-azure` required by the CAPI setup. Everything is controlled by Sveltos using the below ClusterProfile, and there is no need for manual interventions.

```yaml
---
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: deploy-capi-azure-managed
spec:
  clusterSelector:
    matchExpressions:
    - { key: env, operator: In, values: [ staging, prod ] }
  syncMode: Continuous
  helmCharts:
  - chartName: cloud-provider-azure/cloud-provider-azure
    chartVersion: 1.34.1
    helmChartAction: Install
    releaseName: cloud-provider-azure
    releaseNamespace: kube-system
    repositoryName: cloud-provider-azure
    repositoryURL: https://raw.githubusercontent.com/kubernetes-sigs/cloud-provider-azure/master/helm/repo
    values: |
      infra:
        clusterName: "{{ .Cluster.metadata.name }}"
      cloudControllerManager:
        clusterCIDR: "192.168.0.0/16"
  - chartName: cilium/cilium
    chartVersion: 1.17.7
    helmChartAction: Install
    releaseName: cilium
    releaseNamespace: kube-system
    repositoryName: cilium
    repositoryURL: https://helm.cilium.io/
    values: |
      ipam:
        mode: "cluster-pool"
        operator:
          clusterPoolIPv4PodCIDRList:
            - "192.168.0.0/16"
          clusterPoolIPv4MaskSize: 24
      kubeProxyReplacement: true
      bpf:
        masquerade: true
      hubble:
        enabled: true
        relay:
          enabled: true
        ui:
          enabled: true
```

## Step 6: Remove a User

To remove a user, update the `existing-users` ConfigMap. Then, submit a PR and merge the code. After that, let ArgoCD sync the change to the management cluster. Sveltos' will handle the rest! Again, no magic, only Sveltos goodness!

## Conclusion

In a few steps, we demonstrated how Platform teams can use Sveltos with CAPI on Azure and a GitOps approach to create scalable, maintainable, and easily managed Kubernetes clusters with versioned, auditable deployments.