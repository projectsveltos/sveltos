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

!!!video
    To learn more about the **Sveltos Dashboard**, check out the [Sveltos Dashboard Introduction Youtube Video](https://www.youtube.com/embed/FjFtvrG8LWQ?si=mS8Yt2pleGsl33fK) and [Features and Debugging with Sveltos](https://www.youtube.com/embed/rN8gqsghev0?si=Q5xUVIW13rKOJ2mo). If you find this valuable, we would be thrilled if you shared it! 😊


## Introduction to Sveltos Dashboard

The Sveltos Dashboard is not part of the generic Sveltos installation. It is a manifest file that will get deployed on top. If you have not installed Sveltos, check out the documentation [here](../install/install.md).

### Manifest Installation

To deploy the Sveltos Dashboard, run the below command using the `kubectl` utility.

```
$ kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/dashboard-manifest.yaml

```

### Helm Installation

```bash
$ helm repo add projectsveltos https://projectsveltos.github.io/helm-charts

$ helm repo update
```

```bash
$ helm install sveltos-dashboard projectsveltos/sveltos-dashboard -n projectsveltos

$ helm list -n projectsveltos
```

!!! warning
    **_v0.38.4_** is the first Sveltos release that includes the dashboard and it is compatible with Kubernetes **_v1.28.0_** and higher.

To access the dashboard, expose the `dashboard` service in the `projectsveltos` namespace. The deployment, by default, is configured as a _ClusterIP_ service. To expose the service externally, we can edit it to either a _LoadBalancer_ service or use an Ingress/Gateway API.

## Authentication

The Sveltos Dashboard supports two authentication methods: **manual token authentication** (default) and **OIDC authentication**. The active method is determined at deploy time by the Helm values provided.

### Manual Token Authentication

To authenticate with the Sveltos Dashboard, we will utilise a `serviceAccount`, a `ClusterRoleBinding`/`RoleBinding` and a `token`.

Let's create a `service account` in the desired namespace.

```
$ kubectl create sa <user> -n <namespace>
```

Let's provide the service account permissions to access the **managed** clusters in the **management** cluster.


```
$ kubectl create clusterrolebinding <binding_name> --clusterrole <role_name> --serviceaccount <namespace>:<service_account>
```

| Argument         | Description                                                                                                                                            |
|------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------|
| `binding_name`   | It is a descriptive name for the rolebinding.                                                                                                          |
| `role_name`      | It is one of the default cluster roles (or a custom cluster role) specifying permissions (i.e., which managed clusters this serviceAccount can see). |
| `namespace`      | It is the service account's namespace.                                                                                                                 |
| `service_account`| It is the service account that the permissions are being associated with.                                                                             |

#### Platform Administrator Example

```
$ kubectl create sa platform-admin -n default
$ kubectl create clusterrolebinding platform-admin-access --clusterrole cluster-admin --serviceaccount default:platform-admin
```

Create a login token for the service account with the name `platform-admin` in the `default` namespace. The token will be valid for **24 hours**.[^1]

```
$ kubectl create token platform-admin --duration=24h
```

Copy the token generated, login to the Sveltos Dashboard and submit it.

[^1]: While the example uses __cluster-admin__ for simplicity, the dashboard only requires read access to Sveltos CRs and Cluster API cluster instances.

### OIDC Authentication

The dashboard supports OIDC authentication using the **Authorization Code Flow with PKCE** (public client). When enabled, the login page will show the OIDC login option instead of the manual token form.

Setting up OIDC requires three steps: configuring the dashboard, configuring the Kubernetes API server, and setting up RBAC for your dashboard users.

#### 1. Configure the Dashboard

OIDC is enabled by providing the following Helm values at install time:

| Helm Value | Description | Default |
|---|---|---|
| `auth.oidc.issuer` | Issuer URL of your OIDC provider | — |
| `auth.oidc.clientId` | Client ID registered with your OIDC provider | — |
| `auth.oidc.redirectUri` | Full redirect URI after OIDC login | `<origin>/oidc-callback` |

```bash
$ helm install sveltos-dashboard projectsveltos/sveltos-dashboard -n projectsveltos \
  --set auth.oidc.issuer=https://k8s-oidc-domain.example.com/auth/realms/k8s-oidc \
  --set auth.oidc.clientId=k8s-oidc-client \
  --set auth.oidc.redirectUri=https://dashboard.example.com/oidc-callback
```

Make sure that the client exists, it is configured as a **public client** (no client secret), and the redirect URI is registered in the OIDC provider.

If `auth.oidc.issuer` and `auth.oidc.clientId` are not set, the dashboard falls back to manual token authentication.

#### 2. Configure the Kubernetes API Server

The Kubernetes API server must be configured to accept and validate OIDC tokens. The required and optional flags are documented [here](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#openid-connect-tokens).

#### 3. Configure RBAC for OIDC Users

The API server maps the username claim from the OIDC token to RBAC subjects. The subject name may include the issuer URL to avoid name clashes, based on the API server OIDC configuration. Refer to the [Kubernetes documentation](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#openid-connect-tokens) for details on prefixing behaviour.

The following example grants `cluster-admin` to the OIDC user `test`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: k8s-oidc-dashboard-admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: User
  name: https://k8s-oidc-domain.example.com/auth/realms/k8s-oidc#test
```

Note that `subjects.name` includes the OIDC issuer URL prefix followed by the username claim value.

In production, avoid granting admin level grants to the dashboard users.

#### 4. Logging In

Once all three steps are complete, the dashboard login page will display the OIDC login option. Clicking it redirects the user to the OIDC provider. After a successful sign-in, the provider redirects back to the configured redirect URI, and the user is taken to the dashboard.
