---
title: Secret Distribution Across Kubernetes Clusters - Project Sveltos
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative APIs to deploy Kubernetes add-ons across multiple clusters.
tags:
    - Kubernetes
    - managed services
    - Sveltos
    - event driven
authors:
    - Gianluca Mardente
---

This guide demonstrated how Sveltos simplifies the process of propagating secrets to all your production clusters.

This guide requires a pre-existing Secret named `regcred` of type `dockerconfigjson` in the `default` namespace on the management cluster.

Here is an example of such Secret:

```yaml
apiVersion: v1
data:
  .dockerconfigjson: ewogICAgImF1dGhzIjogewogICAgICAgICJodHRwczovL2luZGV4LmRvY2tlci5pby92MS8iOiB7CiAgICAgICAgICAgICJhdXRoIjogIkxXWWdjR0Z6YzNkdmNtUUsiCiAgICAgICAgfQogICAgfQp9Cg==
kind: Secret
metadata:
  name: regcred
  namespace: default
type: kubernetes.io/dockerconfigjson
```

We'll set up Sveltos to propagate the `regcred` Secret to namespaces with the __imagepullsecret: required__ label, targeting clusters with the __env: production__ label:

![Sveltos: Distribute Secret](../assets/distribute_secret.gif)

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: namespaces-requiring-imagepullsecret
  namespace: default
data:
  namespaces: |
    {{- range $v := .MatchingResources }}
       {{ $v.Name }}: "ok"
    {{- end }}
---
apiVersion: lib.projectsveltos.io/v1beta1
kind: EventSource
metadata:
  name: new-namespace
spec:
  collectResources: false
  resourceSelectors:
  - group: ""
    version: "v1"
    kind: "Namespace"
    labelFilters:
    - key: imagepullsecret
      operation: Equal
      value: required
---
apiVersion: lib.projectsveltos.io/v1beta1
kind: EventTrigger
metadata:
  name: deploy-imagepullsecret
spec:
  sourceClusterSelector:
    matchLabels:
      env: production
  eventSourceName: new-namespace
  configMapGenerator:
  - name: namespaces-requiring-imagepullsecret
    namespace: default
    nameFormat: "{{ .Cluster.metadata.name }}-imagepullsecret"
  oneForEvent: false
  templateResourceRefs:
  - resource: # This refers to the resource that Sveltos dynamically generates using ConfigMapGenerator.
      apiVersion: v1
      kind: ConfigMap
      name: "{{ .Cluster.metadata.name }}-imagepullsecret"
      namespace: projectsveltos
    identifier: Namespaces
  - resource: # This is the ConfigMap containing the credentials to authenticate with private registry
      apiVersion: v1
      kind: Secret
      name: regcred
      namespace: default
    identifier: ImagePullSecret
  policyRefs:
  - name: deploy-imagepullsecret
    namespace: default
    kind: ConfigMap
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: deploy-imagepullsecret
  namespace: default
  annotations:
    projectsveltos.io/template: "ok"
data: 
  content: |
    {{ $namespaces := ( ( index (getResource "Namespaces").data "namespaces" ) | fromYaml ) }} 
    {{- range $key, $value := $namespaces }}
        apiVersion: v1
        kind: Secret
        metadata:
          namespace: {{ $key }}
          name: {{ (getResource "ImagePullSecret").metadata.name }}
        type: kubernetes.io/dockerconfigjson
        data:
          {{- range $secretKey, $secretValue := (getResource "ImagePullSecret").data }}
            {{ $secretKey }} : {{ $secretValue }}
          {{- end }}
    ---
    {{- end }}
```

