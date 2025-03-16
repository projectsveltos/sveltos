---
title: Sveltos - Kubernetes Add-on Controller | Manage Kubernetes Add-ons with Ease | Multi-tenancy
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative APIs to deploy Kubernetes add-ons across multiple clusters.
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

## What is Multi-tenancy?

Multi-tenancy in cloud computing is the concept of multiple clients sharing the same computing resources. Multi-tenancy in Kubernetes can appear in two forms, either share a cluster between multiple tenants within an organisation or have more than one clusters reserved by an organisation.

## Common Challenges

1. How can platform admins grant permissions to tenant admins programmatically?
2. How to control tenant admins' deployment actions based on their permissions?

We mentioned two terms in the challenges above: `platform admins` and `tenant admins`.

- **Platform admin:** Manages the infrastructure of Kubernetes clusters, including tasks like creating clusters, managing nodes, and ensuring cluster health.

- **Tenant admin:** Has admin access to clusters or namespaces where applications run, with permissions assigned by the platform admin.

## Sveltos Multi-tenancy: Full Isolation

In a multi-tenant setup, each tenant is assigned a **dedicated namespace** within the **management cluster**. Tenant admins can create and manage clusters in their namespace, using `Profile` instances to define the add-ons and apps to deploy. Like `ClusterProfiles`, `Profiles` use a cluster selector and a list of add-ons and apps, but they operate within a specific namespace, matching only clusters created in that namespace.

![Profile vs ClusterProfile](../assets/Sveltos_Profile_ClusterProfile.jpg)

## Sveltos Multi-tenancy: Cluster Sharing Between Tenants

Sveltos allows platform admins to utilise the Custom Resource Definition `RoleRequest` that will grant permissions to a number of tenant admins. More information can be found [here](../features/multi-tenancy-sharing-cluster.md).

!!! example "Example - RoleRequest"
    ```yaml
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: RoleRequest
    metadata:
      name: full-access
    spec:
      serviceAccountName: "eng"
      serviceAccountNamespace: "default"
      clusterSelector:
        matchLabels:
          env: prod
      roleRefs:
      - name: full-access
        namespace: default
        kind: ConfigMap
    ```
Based on the YAML definition above, the following fields are defined:

- `serviceAccountName`: The service account to which the permission will be applied.
- `serviceAccountNamespace`: The namespace where the service account is deployed in the **management cluster**.
- `clusterSelector`: A Kubernetes `label selector` used by Sveltos to identify clusters where permissions should be granted.
- `roleRefs`: References to ConfigMaps/Secrets, each containing Kubernetes [ClusterRoles or Roles](https://kubernetes.io/docs/reference/access-authn-authz/rbac/) that define the permissions to be granted.

The `configMap` in the example above might look like the YAML definition below.

!!! example "Example - ConfigMap"
    ```yaml
    ---
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: full-access
      namespace: default
    data:
      role.yaml: |
        apiVersion: rbac.authorization.k8s.io/v1
        kind: ClusterRole
        metadata:
          name: eng-full-access
        rules:
        - apiGroups: ["*"]
          resources: ["*"]
          verbs: ["*"]
    ```

Based on the YAML definitions above, here is what happens from a Sveltos perspective:

By referencing the ConfigMap `default/full-access`, the `RoleRequest` named `full-access` will reserve a cluster matching the `clusterSelector` *env=prod* to the service account `eng`.

## More Resources

For more information about the Sveltos multi-tenancy capabilities, have a look [here](../features/multi-tenancy-sharing-cluster.md).
