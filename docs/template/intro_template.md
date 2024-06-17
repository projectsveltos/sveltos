---
title: Templates
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

## Introduction to Templates

Sveltos lets you define add-ons and applications using templates. Before deploying any resource down the **managed** clusters, Sveltos instantiates the templates using information gathered from the **management** cluster.

## Template Functions

Sveltos supports the template functions included from the [Sprig](https://masterminds.github.io/sprig/) open source project. The Sprig library provides over **70 template functions** for Go’s template language. Some of the functions are listed below. For the full list, please refer to [Sprig repo]([Sprig](https://masterminds.github.io/sprig/).

1. **String Functions**: trim, wrap, randAlpha, plural, etc.
1. **String List Functions**: splitList, sortAlpha, etc.
1. **Integer Math Functions**: add, max, mul, etc.
1. **Integer Slice Functions**: until, untilStep
1. **Float Math Functions**: addf, maxf, mulf, etc.
1. **Date Functions**: now, date, etc.
1. **Defaults Functions**: default, empty, coalesce, fromJson, toJson, toPrettyJson, toRawJson, ternary
1. **Encoding Functions**: b64enc, b64dec, etc.
1. **Lists and List Functions**: list, first, uniq, etc.
1. **Dictionaries and Dict Functions**: get, set, dict, hasKey, pluck, dig, deepCopy, etc.
1. **Type Conversion Functions**: atoi, int64, toString, etc.
1. **Path and Filepath Functions**: base, dir, ext, clean, isAbs, osBase, osDir, osExt, osClean, osIsAbs
1. **Flow Control Functions**: fail

## Extra Template Functions

1. **toToml**: It an interface, marshals it to **toml**, and returns a string. It will always return a string, even on marshal error (empty string)
1. **toYaml**: It takesn an interface, marshals it to **yaml**, and returns a string. It will always return a string, even on marshal error (empty string)
1. **toJson**: It an interface, marshals it to **json**, and returns a string. It will always return a string, even on marshal error (empty string)
1. **fromToml**: It converts a **TOML** document into a map[string]interface{}
1. **fromYaml**: It converts a **YAML** document into a map[string]interface{}
1. **fromYamlArray**: It converts a **YAML array** into a []interface{}
1. **fromJson**: It converts a **YAML** document into a map[string]interface{}
1. **fromJsonArray**: It converts a **JSON array** into a []interface{}

## Variables

By default, the templates have access to the below managment cluster resources.

1. CAPI Cluster instance. The keyword is `Cluster`
2. CAPI Cluster infrastructure provider. The keyword is `InfrastructureProvider`
3. CAPI Cluster kubeadm provider. The keyword is `KubeadmControlPlane` 
4. For cluster registered with Sveltos, the SveltosCluster instance. The keyword is `Cluster` 

Sveltos can fetch any resource from the management cluster. We just need to include the **templateResourceRefs** in the ClusterProfile/Profile Spec section.

## RBAC

Sveltos adheres to the least privilege principle concept. That means Sveltos **does not** have all the necessary permissions to fetch resources from the management cluster by **default**. Therefore, when using `templateResourceRefs`, we need to provide Sveltos with the correct RBAC definition.

Providing the necessary RBACs to Sveltos is a straightforward process. The Sveltos `ServiceAccount` is tied to the **addon-controller-role-extra** ClusterRole. To grant Sveltos the necessary permissions, simply edit the role.

If the `ClusterProfile` is created by a tenant administrator as part of a [multi-tenant setup](../features/multi-tenancy-sharing-cluster.md), Sveltos will act on behalf of (impersonate) the ServiceAccount that represents the tenant. This ensures that Kubernetes RBACs are enforced, which restricts the tenant's access to only authorized resources.

### templateResourceRefs: Namespace and Name

When using `templateResourceRefs` to find resources in the management cluster, the namespace field is optional. 

1. If you provide a namespace (like _default_), Sveltos will look for the resource in that specific namespace.
1. Leaving the namespace field blank tells Sveltos to search for the resource in the same namespace as the cluster during deployment.

The name field in `templateResourceRefs` can also be a template. This allows users to dynamically generate names based on information available during deployment.

We can use special keywords like _.ClusterNamespace_ and _.ClusterName_ within the name template to reference the namespace and name of the cluster where the resource is about to be deployed.

For example, the below template will create a name by combining the cluster's namespace and name:

```yaml
name: "{{ .ClusterNamespace }}-{{ .ClusterName }}"
```

## Continue Reading

1. **Helm Chart and Resources as Templates - Examples**: Checkout the template examples [here](../template/template_generic_examples.md)
1. **Helm Charts**: See the "Example: Express Helm Values as Templates" section in [here](../addons/helm_charts.md#example-express-helm-values-as-templates)
1. **YAML & JSON**: refer to the "Example Template with Git Repository/Bucket Content" section in [here](../addons/example_flux_sources.md#example-template-with-git-repositorybucket-content)
1. **Kustomize**: Substitution and templating are explained [here](../addons/kustomize.md#substitution-and-templating)