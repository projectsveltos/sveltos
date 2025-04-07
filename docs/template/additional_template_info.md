---
title: Additional Templates Information
description: Helm chart values and resources contained in referenced ConfigMaps/Secrets can be defined as template. 
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
    - template
authors:
    - Gianluca Mardente
---
!!! note
    Make sure to read the ["Introduction to Templates"](../template/intro_template.md) section before continuing. It provides important context for the information that follows.


## Variables

By default, the Sveltos Templates can access to the mentioned **management** cluster resources.

1. **CAPI Cluster instance**: `Cluster`
1. **CAPI Cluster infrastructure provider**: `InfrastructureProvider`
1. **CAPI Cluster kubeadm provider**:`KubeadmControlPlane`
1. Sveltos registered clusters, the **SveltosCluster** instance: `Cluster`

Sveltos can retrieve any resource from the **management** cluster. To do this, include the `templateResourceRefs` in the `Spec` section of the [ClusterProfile/Profile ](../addons/addons.md) resource.

## Role Based Access Control (RBAC)

Sveltos adheres to the [least privilege principle](https://csrc.nist.gov/glossary/term/least_privilege) concept. That means, by default, Sveltos **does not** have all the necessary permissions to fetch resources from the management cluster. Therefore, when using `templateResourceRefs`, we need to provide Sveltos with the correct RBAC definition.

Granting the necessary RBAC permissions to Sveltos is a simple process. The Sveltos `ServiceAccount` is tied to the **addon-controller-role-extra** ClusterRole. To grant Sveltos the necessary permissions, simply **edit** the role.

If the `ClusterProfile` is created by a tenant administrator as part of a [multi-tenant setup](../features/multi-tenancy-sharing-cluster.md), Sveltos acts on behalf of (impersonate) the ServiceAccount that represents the tenant. This ensures the Kubernetes RBACs are enforced, which restricts the tenant's access to only authorised resources.

### templateResourceRefs: Namespace and Name

When using the `templateResourceRefs` field to locate resources in the **management** cluster, the `namespace` field is **optional**. 

1. If a namespace is **provided** (like _default_), Sveltos will look for the resource in the specified namespace
1. If the namespace field is **blank**, Sveltos will search for the resource in the same namespace as the management cluster

The `name` field in `templateResourceRefs` can be expressed as a template. It allows users to dynamically generate names based on the information available during the deployment.

Available cluster information:

- **cluster namespace**: `.Cluster.metadata.namespace`
- **cluster name**: `.Cluster.metadata.name` 
- **cluster type**: `.Cluster.kind` 

For example, the below template creates a name by combining the cluster's `namespace` and `name`.

```yaml
name: "{{ .Cluster.metadata.namespace }}-{{ .Cluster.metadata.name }}"
```

## Embedding Go Templates in Sveltos
 
When incorporating Go template logic into Sveltos templates, utilise the **escape syntax** ```'{{`<YOUR GO TEMPLATE>`}}'```. This ensures that the code is treated as a Go template rather than a Sveltos template.

!!! example "Embedding Go Templates in Sveltos"
    ```yaml hl_lines="29"
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: meilisearch-proxy-secrets
      namespace: default
      annotations:
        projectsveltos.io/template: "true"
    data:
      secrets.yaml: |
        {{ $cluster := .Cluster.metadata.name }}
        {{- range $env := (list "production" "staging") }}
        ---
        apiVersion: external-secrets.io/v1beta1
        kind: ExternalSecret
        metadata:
          name: meilisearch-proxy
          namespace: {{ $env }}
        spec:
          refreshInterval: 1h
          secretStoreRef:
            kind: ClusterSecretStore
            name: vault-backend
          target:
            name: meilisearch-proxy
            template:
              engineVersion: v2
              data:
                MEILISEARCH_HOST: https://meilisearch.{{ $cluster }}
                MEILISEARCH_MASTER_KEY: '{{`{{ .master_key }}`}}'
                PROXY_MASTER_KEY_OVERRIDE: "false"
                CACHE_ENGINE: "redis"
                CACHE_TTL: "300"
                CACHE_URL: "redis://meilisearch-proxy-redis:6379"
                PORT: "80"
                LOG_LEVEL: "info"
          data:
            - secretKey: 'master_key'
              remoteRef:
                key: 'search'
                property: '{{ $env }}.master_key'
        {{- end }}
    ```

## Learn More

1. **Example - Helm Chart and Resources as Templates**: Checkout the template examples [here](../template/template_generic_examples.md)
1. **Helm Charts**: See the "Example: Express Helm Values as Templates" section in [here](../addons/helm_charts.md#example-express-helm-values-as-templates)
1. **YAML & JSON**: Refer to the "Example Template with Git Repository/Bucket Content" section in [here](../addons/example_flux_sources.md#example-template-with-git-repositorybucket-content)
1. **Kustomize**: Substitution and templating are explained [here](../addons/kustomize.md#substitution-and-templating)