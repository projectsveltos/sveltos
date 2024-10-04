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

<iframe width="560" height="315" src="https://www.youtube.com/embed/Pz6iIrjpo2Q?si=-6O7HSXvjlH3DcyB" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share" referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>