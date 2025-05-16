---
title: Example API Gateway Contour - Project Sveltos
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative APIs to deploy Kubernetes add-ons across multiple clusters.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
    - Sveltos
    - event driven
authors:
    - Gianluca Mardente
---

## Example: API Gateway with Contour: Create one HTTPRoute instance per event

We already covered [here](https://medium.com/@projectsveltos/how-to-deploy-l4-and-l7-routing-on-multiple-kubernetes-clusters-securely-and-programmatically-930ebe65fa8c) how to deploy L4 and L7 routing on multiple Kubernetes clusters securely and programmatically with Sveltos.

With the event driven framework, we are taking a step forward: programmatically generate/update HTTPRoutes: 

1. Define a Sveltos Event as creation/deletion of specific Service instances (in our example, the Service instances we are interested in are in the namespace *eng* and are exposing port *80*);
1. Define what add-ons to deploy in response to such events: an HTTPRoute instance defined as a template. Sveltos will instantiate this template using information from Services in the managed clusters that are part of the event defined in #1

!!! example "Example - EventSource Definition"
    ```yaml
    cat > eventsource.yaml <<EOF
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: EventSource
    metadata:
      name: eng-http-service
    spec:
      collectResources: true
      resourceSelectors:
      - group: ""
        version: "v1"
        kind: "Service"
        namespace: eng
        evaluate: |
          function evaluate()
            hs = {}
            hs.matching = false
            if obj.spec.ports ~= nil then
              for _,p in pairs(obj.spec.ports) do
                if p.port == 80 then
                  hs.matching = true
                end
              end
            end
            return hs
          end
    EOF
    ```

!!! example "Example - EventTrigger Definition"
    ```yaml
    cat > eventtrigger.yaml <<EOF
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: EventTrigger
    metadata:
      name: service-network-policy
    spec:
      sourceClusterSelector:
        matchLabels:
          env: fv
      eventSourceName: eng-http-service
      oneForEvent: true
      policyRefs:
      ...
      - name: http-routes
        namespace: default
        kind: ConfigMap
    ---
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: http-routes
      namespace: default
      annotations:
        projectsveltos.io/template: ok
    data:
      http-route.yaml: |
        kind: HTTPRoute
        apiVersion: gateway.networking.k8s.io/v1beta1
        metadata:
          name: {{ .Resource.metadata.name }}
          namespace: {{ .Resource.metadata.namespace }}
          labels:
            {{ range $key, $value := .Resource.spec.selector }}
            {{ $key }}: {{ $value }}
            {{ end }}
        spec:
          parentRefs:
          - group: gateway.networking.k8s.io
            kind: Gateway
            name: contour
            namespace: projectcontour
          hostnames:
          - "local.projectcontour.io"
          rules:
          - matches:
            - path:
                type: PathPrefix
                value: /{{ .Resource.metadata.name }}
            backendRefs:
            - kind: Service
              name: {{ .Resource.metadata.name }}
              port: {{ (index .Resource.spec.ports 0).port }}
    EOF
    ```

Anytime a Service exposing port 80 is created in any matching cluster and in the namespace `eng`, an HTTPRoute instance will get deployed.

Full example definitions (with all YAMLs) can be found [here](https://github.com/projectsveltos/demos/blob/main/httproute/README.md).
