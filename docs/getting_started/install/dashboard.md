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

# Dashboard

Run the following command to deploy the Sveltos dashboard using kubectl:

```
$ kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/dashboard-manifest.yaml
```

To access the dashboard, you'll need to expose the `dashboard` service in the `projectsveltos` namespace. 
Currently, it's configured as a _ClusterIP_ service, which limits access to within the cluster. To expose it externally, you can either change the service type to LoadBalancer or utilize an Ingress/Gateway API.

!!! note
    _v0.38.4_ is the first Sveltos release that includes dashboard.

## Authentication

First, create a `service account` in the desired namespace:

```
kubectl create sa <user> -n <namespace>
```

Give the service account permissions to access managed clusters in the management clusters:

```
kubectl create clusterrolebinding <binding_name> --clusterrole <role_name> --serviceaccount <namespace>:<service_account>
```

where:

- **binding_name** is a descriptive name for the rolebinding.
- **role_name** is one of the default cluster roles (or a custom cluster role) specifying permissions (i.e, which managed clusters this serviceAccount can see)
- **namespace** is the service account's namespace.
- **service_account** is the service account that the permissions are being associated with.

For example, if you are a plaform admin, 

```
kubectl create sa platform-admin
kubectl create clusterrolebinding platform-admin-access --clusterrole cluster-admin --serviceaccount default:platform-admin
```

Next, create a login token for the service account.

Using the running example of a service account named, platform-admin in the default namespace:

```
kubectl create token platform-admin --duration=24h
```

!!! note
    The token created above will expire after 24 hours.

Now that you have the token, log in to the Sveltos Dashboard and submit the token.


<iframe width="560" height="315" src="https://www.youtube.com/embed/Pz6iIrjpo2Q?si=-6O7HSXvjlH3DcyB" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>