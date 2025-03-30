---
title: How to install Sveltos dashboard
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative cluster APIs. Learn here how to install Sveltos.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
authors:
    - Gianluca Mardente
---

# Introduction to Sveltos Dashboard

The Sveltos Dashboard is not part of the generic Sveltos installation. It is a manifest file that will get deployed on top. If you have not installed Sveltos, check out the documentation [here](../install/install.md).

To deploy the Sveltos Dashboard, run the below command using the `kubectl` utility.

```
$ kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/dashboard-manifest.yaml

```

### Helm Installation

```
$ helm repo add projectsveltos https://projectsveltos.github.io/helm-charts

$ helm repo update

$ helm install sveltos-projectsveltos projectsveltos/sveltos-dashboard -n projectsveltos

$ helm list -n projectsveltos
```

!!! warning
    **_v0.38.4_** is the first Sveltos release that includes the dashboard and it is compatible with Kubernetes **_v1.28.0_** and higher.

To access the dashboard, expose the `dashboard` service in the `projectsveltos` namespace. The deployment, by default, is configured as a _ClusterIP_ service. To expose the service externally, we can edit it to either a _LoadBalancer_ service or use an Ingress/Gateway API.

## Authentication

To authenticate with the Sveltos Dashboard, we will utilise a `serviceAccount`, a `ClusterRoleBinding`/`RoleBinding` and a `token`.

Let's create a `service account` in the desired namespace.

```
$ kubectl create sa <user> -n <namespace>
```

Let's provide the service account permissions to access the **managed** clusters in the **management** cluster.

```
$ kubectl create clusterrolebinding <binding_name> --clusterrole <role_name> --serviceaccount <namespace>:<service_account>
```

**Command Details**:

- **binding_name**: It is a descriptive name for the rolebinding.
- **role_name**: It is one of the default cluster roles (or a custom cluster role) specifying permissions (i.e, which managed clusters this serviceAccount can see)
- **namespace**: It is the service account's namespace.
- **service_account**: It is the service account that the permissions are being associated with.

### Platform Administrator Example

```
$ kubectl create sa platform-admin
$ kubectl create clusterrolebinding platform-admin-access --clusterrole cluster-admin --serviceaccount default:platform-admin
```

Create a login token for the service account with the name `platform-admin` in the `default` namespace.[^1]

```
$ kubectl create token platform-admin --duration=24h
```

!!! note
    The token created above will expire after 24 hours.

Copy the token generated, login to the Sveltos Dashboard and submit it.

<iframe width="560" height="315" src="https://www.youtube.com/embed/FjFtvrG8LWQ?si=mS8Yt2pleGsl33fK" title="Sveltos Dashboard" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>

[^1]: While the example uses __cluster-admin__ for simplicity, the dashboard only requires read access to Sveltos CRs and Cluster API cluster instances.