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
[Lua](lua.md) can also be used.

![Sveltos Templates](../assets/templates.png)

In this example, Sveltos retrieves the Secret **imported-secret** from the **default** namespace. This Secret is assigned the alias **ExternalSecret**. The template can subsequently refer to this Secret by employing the alias **ExternalSecret**. It can also be used with [Helm Charts](./examples/template_generic.md).

!!!note
    All resources listed in the `TemplateResourceRefs` section can be accessed within the template using `getResource "<alias>"`. For instance, we could access the Secret in an example with `getResource "ExternalSecret"`.

## Template Functions

Sveltos supports the template functions included from the [Sprig](https://masterminds.github.io/sprig/) open source project. The Sprig library provides over **70 template functions** for Go’s template language. Some of the functions are listed below. For the full list, have a look at the Spring Github page.

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

## Resource Manipulation Functions

Sveltos provides a set of functions specifically designed for manipulating resources within your templates.

1. **getResource**: Takes the identifier of a resource and returns a map[string]interface{} allowing to access any field of the resource.
1. **copy**: Takes the identifier of a resource and returns a copy of that resource.
1. **setField**: Takes the identifier of a resource, the field name, and a new value. Returns a modified copy of the resource with the specified field updated.
1. **removeField**: Takes the identifier of a resource and the field name. Returns a modified copy of the resource with the specified field removed.
1. **getField**: Takes the identifier of a resource and the field name. Returns the field value
1. **chainSetField**: This function acts as an extension of setField. It allows for chaining multiple field updates.
1. **chainRemoveField**: Similar to chainSetField, this function allows for chaining multiple field removals.

!!! note
    These functions operate on copies of the original resource, ensuring the original data remains untouched.

For practical examples, take a look [here](./resource_manipulation_functions.md).

Consider combining those methods with the [post render patches](../features/post-renderer-patches.md) approach.

## Extra Template Functions

1. **toToml**: It takes an interface, marshals it to **toml**, and returns a string. It will always return a string, even on marshal error (empty string)
1. **toYaml**: It takes an interface, marshals it to **yaml**, and returns a string. It will always return a string, even on marshal error (empty string)
1. **toJson**: It takes an interface, marshals it to **json**, and returns a string. It will always return a string, even on marshal error (empty string)
1. **fromToml**: It converts a **TOML** document into a map[string]interface{}
1. **fromYaml**: It converts a **YAML** document into a map[string]interface{}
1. **fromYamlArray**: It converts a **YAML array** into a []interface{}
1. **fromJson**: It converts a **YAML** document into a map[string]interface{}
1. **fromJsonArray**: It converts a **JSON array** into a []interface{}
