⅕---
title: Kubernetes add-ons management for tens of clusters quick start
description: Projectsveltos extends the functionality of Cluster API with a solution for managing the installation, configuration & deletion of Kubernetes cluster add-ons.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
authors:
    - Gianluca Mardente
---

## What is Sveltos?

Sveltos is a set of **Kubernetes controllers** deployed in a **management** cluster. A management cluster is the Centralized Kubernetes cluster where Sveltos orchestrates and manages the deployments of Kubernetes resources to managed clusters.

## Before you Begin

To continue with the demo setup, ensure the below are satisfied.

- [Docker](https://docs.docker.com/engine/install/)
- [GoLang](https://go.dev/doc/install)
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)

## Deploy Demo Environment

The main goal of Sveltos is to deploy **add-ons** and **applications** in **managed** Kubernetes clusters. To try out Sveltos in a **test cluster**, execute the commands below.

``` bash
$ git clone https://github.com/projectsveltos/addon-controller && cd addon-controller/

$ make quickstart
```

### Demo Outline

1. A **management** cluster using [Kind](https://kind.sigs.k8s.io)
1. clusterAPI Deployment in the **management** cluster
1. Sveltos Deployment in the **management** cluster
1. A **workload cluster** powered by **clusterAPI** using Docker

??? tip "Sveltos Dashboard"
    The Sveltos Dashboard is an optional component of Sveltos. To include it in the deployment, follow the instructions found in the [dashboard](../optional/dashboard.md) section.

    **_v0.38.4_** is the first Sveltos release that includes the dashboard and it is compatible with Kubernetes **_v1.28.0_** and higher.

### Validation

Patience is a virtue ⏳🌟. The demo environment will be ready in just a few minutes – hang tight!

If the execution was successful, you should see a management cluster named `sveltos-management` and a managed cluster named `clusterapi-workload` already set up and ready to go! 🚀

```bash
$ kind get clusters
clusterapi-workload
sveltos-management
```

### Access Management Cluster

```bash
$ kubectl config set-context kind-sveltos-management
$ kind export kubeconfig --name sveltos-management

$ kubectl get nodes
NAME                               STATUS   ROLES           AGE   VERSION
sveltos-management-control-plane   Ready    control-plane   69m   v1.32.2
sveltos-management-worker          Ready    <none>          69m   v1.32.2
sveltos-management-worker2         Ready    <none>          69m   v1.32.2

$ kubectl get clusters --show-labels
NAME                  CLUSTERCLASS   PHASE         AGE   VERSION   LABELS
clusterapi-workload   quick-start    Provisioned   70m   v1.32.0   cluster.x-k8s.io/cluster-name=clusterapi-workload,env=fv,sveltos-agent=present,topology.cluster.x-k8s.io/owned=
```

## Deploy Helm Charts

Sveltos can deploy Helm Charts from **public** and **private** registries **seamlessly**. The `ClusterProfile` resource will match **any** cluster with the label set to _env:fv_. For this demo, the `clusterapi-workload` gets matched.

!!! example "Example - Kyverno Helm Chart"
    ```yaml
    cat > clusterprofile_kyverno.yaml <<EOF
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: deploy-kyverno
    spec:
      clusterSelector:
        matchLabels:
          env: fv
      syncMode: Continuous
      helmCharts:
      - repositoryURL:    https://kyverno.github.io/kyverno/
        repositoryName:   kyverno
        chartName:        kyverno/kyverno
        chartVersion:     v3.3.7
        releaseName:      kyverno-latest
        releaseNamespace: kyverno
        helmChartAction:  Install
    EOF
    ```

```bash
$ kubectl apply -f clusterprofile_kyverno.yaml
```

### Validation

```bash
$ kubectl config set-context kind-clusterapi-workload
$ kind export kubeconfig --name clusterapi-workload

$ kubectl get pods -n kyverno
NAME                                             READY   STATUS    RESTARTS   AGE
kyverno-admission-controller-6f6589ffb7-xh7dq    1/1     Running   0          102s
kyverno-background-controller-6989c5bf45-mbkbh   1/1     Running   0          102s
kyverno-cleanup-controller-788ffb4596-w6t46      1/1     Running   0          102s
kyverno-reports-controller-bfb4856f8-5sd69       1/1     Running   0          102s
```

✅ Success! You have deployed **Kyverno** on your managed cluster! 🚀

## Deploy Raw YAMl/JSON

Sveltos can deploy raw `yaml` and `json` resources. For this example, we will deploy [Nginx](https://projectcontour.io/docs/1.23/guides/gateway-api/) in the `dev` namespace.

1. Connect to the **management** cluster
    ```bash
    $ kubectl config set-context kind-sveltos-management
    $ kind export kubeconfig --name sveltos-management
    ```

1. Specify the Nginx deployment details (namespace, deployment, service)
```yaml
cat > nginx_deploy.yaml <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: dev
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
        - name: nginx
          image: nginx:latest
          ports:
            - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  namespace: dev
spec:
  selector:
    app: nginx
  ports:
    - protocol: TCP
      port: 80
      targetPort: 80
  type: ClusterIP
EOF
```

1. Create a `ConfigMap` resource referencing the `.yaml` file
    ```bash
    $ kubectl create configmap nginx --from-file=nginx_deploy.yaml
    ```
1.  Create and apply the `ClusterProfile` resource referencing the `ConfigMap`

    ```yaml
    cat > clusterprofile_nginx.yaml <<EOF
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: nginx-deploy
    spec:
      clusterSelector:
        matchLabels:
          env: fv
      syncMode: Continuous
      policyRefs:
      - name: nginx
        namespace: default
        kind: ConfigMap
    EOF
    ```

    ```bash
    $ kubectl apply -f clusterprofile_nginx.yaml
    ```

### Validation

```bash
$ kubectl config set-context kind-clusterapi-workload
$ kind export kubeconfig --name clusterapi-workload

$ kubectl get pods,svc -n dev
NAME                       READY   STATUS    RESTARTS   AGE
pod/nginx-96b9d695-tmqgf   1/1     Running   0          46s

NAME                    TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)   AGE
service/nginx-service   ClusterIP   10.225.11.22   <none>        80/TCP    46s
```

✅ Success! As expected, Sveltos deployed all the referenced resources on your managed cluster! 🚀

For **advanced** examples, check out the [Kong Gateway API](https://github.com/projectsveltos/demos/tree/main/kong-apigateway) deployment.

## Deploy Kustomize using GitOps

Sveltos can work alongside [FluxCD](https://fluxcd.io/flux/installation/) to deploy content of Kustomize directories.

!!! example "Example - Kustomize"
    ```yaml
    cat > clusterprofile_flux.yaml <<EOF
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: flux-system
    spec:
      clusterSelector:
        matchLabels:
          env: fv
      syncMode: Continuous
      kustomizationRefs:
      - namespace: flux-system
        name: flux-system
        kind: GitRepository
        path: ./helloWorld/
        targetNamespace: eng
    EOF
    ```

The `ClusterProfile` can reference:

1. GitRepository (synced with FluxCD);
2. OCIRepository (synced with FluxCD);
3. Bucket (synced with FluxCD);
4. ConfigMap whose BinaryData section contains __kustomize.tar.gz__ entry with tar.gz of kustomize directory;
5. Secret (type addons.projectsveltos.io/cluster-profile) whose Data section contains __kustomize.tar.gz__ entry with tar.gz of kustomize directory;

An example list is found [here](../../addons/kustomize.md). For more information about the Sveltos and FluxCD integration, check out the [information](../../use_cases/use_case_gitops.md).

## Carvel ytt and Jsonnet
Sveltos offers support for Carvel ytt and Jsonnet as tools to define add-ons that can be deployed in a managed cluster. For additional information, please consult the [Carvel ytt](../../template/ytt_extension.md) and [Jsonnet](../../template/jsonnet_extension.md) sections.
