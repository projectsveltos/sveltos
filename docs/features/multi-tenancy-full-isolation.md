---
title: Kubernetes multi-tenancy
description: Projectsveltos extends the functionality of Cluster API with a solution for managing the installation, configuration & deletion of kubernetes cluster add-ons.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
authors:
    - Gianluca Mardente
---

A common multi-tenant scenario involves assigning dedicated namespaces within the management cluster for each tenant. 
Tenant admins then create and manage their clusters within their designated namespace and use Profile instances to define list of add-ons and applications to deploy in their managed clusters.

Similar to ClusterProfiles, Profiles utilize a cluster selector and list of add-ons and applications. 
However,  Profiles operate within a specific namespace, matching only clusters created in that namespace. 

![Profile vs ClusterProfile](../assets/Sveltos_Profile_ClusterProfile.jpg)