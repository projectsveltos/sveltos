---
title: Templates
description: Use Lua to generate at run time the resources to deploy
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
    - template
    - lua
authors:
    - Gianluca Mardente
---

# Lua

Sveltos enables the execution of [Lua](https://www.lua.org/) code stored within ConfigMap or Secret Kubernetes resources. To allow Sveltos to identify and reference these resources within the Sveltos profiles, the annotation `projectsveltos.io/lua` annotation needs to be defined within the resources. Check out the example below. The Lua code gets executed, and the resulting output is used to *deploy configurations* to matching clusters.

This will instruct Sveltos to fetch the Secret __imported-secret__ in the __default__ namespace and replicate it to any __env: prod__ cluster:

```yaml hl_lines="4 26-27"
apiVersion: v1
kind: ConfigMap
metadata:
  annotations:
    projectsveltos.io/lua: ok
  name: lua
  namespace: default
data:
  lua.yaml: |-
    function evaluate()
      local secret = getResource(resources, "ExternalSecret")
      print(secret.metadata.name)
      local hs = {}
      local result = [[
    apiVersion: v1
    kind: Secret
    metadata:
      name: ]] .. secret.metadata.name .. [[

      namespace: ]] .. secret.metadata.namespace .. [[

    data:
    ]]
      for k, v in pairs(secret.data) do
        result = result .. "  " .. k .. ": " .. v .. "\n"
      end
      hs.resources = result
      return hs
    end
```

```yaml
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: deploy-resources
spec:
  clusterSelector:
    matchLabels:
      env: prod
  templateResourceRefs:
  - resource:
      apiVersion: v1
      kind: Secret
      name: imported-secret
      namespace: default
    identifier: ExternalSecret
  policyRefs:
  - kind: ConfigMap
    name: lua
    namespace: default
```

## Helper Functions:

Sveltos provides several helper functions to simplify resource manipulation within Lua scripts:

- *getResource(resources, "resource identifier")*:  Retrieves a specific resource by its identifier from the provided resource list. The resources represents all Kubernetes resources defined in the _Spec.TemplateResourceRefs_ section of a Sveltos profile. The identifier must match an identifier previously defined in the same _Spec.TemplateResourceRefs_ section.
- *getLabel(resource, "key")*: Returns the value of the label with the specified key for a given resource.
- *getAnnotation(resource, "key")*: Returns the value of the annotation with the specified key for a given resource.
- *base64Encode* and *base64Decode*: For base64 encoding and decoding.
- *json.encode* and *json.decode*: For JSON encoding and decoding.
- strings functions: Provides a range of string manipulation functions such as *Compare*, *Contains*, *HasPrefix*, *HasSuffix*, *Join*, *Replace*, *Split*, *ToLower*, and *ToUpper*. These functions are based on the this [library](https://github.com/chai2010/glua-strings). To use these methods, call them as strings.ToUpper("mystring").

```lua
  local strings = require("strings")

  function evaluate()
    local secret = getResource(resources, "ExternalSecret") 
    print(strings.ToUpper(secret.metadata.name))
    local splitTable = strings.Split(secret.metadata.name, "-") -- metadata.name in the example imported-secret
    for i, v in ipairs(splitTable) do
      print("Element", i, ":", v)
    end
    local encoded = base64Encode(secret.metadata.name)
```

```lua
  local json = require("json")

  function evaluate()
    local secret = getResource(resources, "ExternalSecret") 
    local encoded = json.encode(secret)
    print(encoded)
```

## Extending Lua Capabilities with Custom Helper Functions:

Sveltos allows users to extend its Lua scripting capabilities by defining custom helper functions. These functions are packaged as Lua code within a ConfigMap residing in the projectsveltos namespace.

To load and utilize the custom functions, the`lua-methods` argument must be provided to the addon-controller  deployment. Once loaded, the custom methods become available whenever Lua code is executed by Sveltos.

!!! note
    The below libraries are used.
    https://github.com/chai2010/glua-strings/ for string manipulation.
    https://github.com/layeh/gopher-json for JSON handling.