---
title: Example Service Event Trigger - Project Sveltos
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

## Example: Service Event Trigger

In this example, we want to create an Ingress in the namespace `eng` as soon as at least one Service is created exposing the HTTPS port.

The below EventSource instance will match any Service in namespace *eng* exposing either port 443 or port 8443.

```yaml
apiVersion: lib.projectsveltos.io/v1alpha1
kind: EventSource
metadata:
 name: https-service
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
           if p.port == 443 or p.port == 8443 then
             hs.matching = true
           end
         end
       end
       return hs
     end
```

The below EventTrigger instance is referencing the EventSource instance defined above, and it is referencing a ConfigMap containing a template for an Ingress resource.

!!! note
    The *oneForEvent* field is set to `false` and instructs Sveltos to create a single Ingress for all Service instances in the managed cluster matching the EventSource.

When *oneForEvent* is set to `false`, when instantiating the Ingress template, *Resources* is an array containing all Services in the managed cluster matching the EventSource. Any field can be accessed.

```yaml
apiVersion: lib.projectsveltos.io/v1alpha1
kind: EventTrigger
metadata:
 name: ingress-configuration
 namespace: default
spec:
 sourceClusterSelector: env=fv
 eventSourceName: https-service
 oneForEvent: false
 policyRefs:
 - name: ingress
   namespace: default
   kind: ConfigMap
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress
  namespace: default
  annotations:
    projectsveltos.io/template: ok
data:
  ingress.yaml: |
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: ingress
      namespace: default
      annotations:
        nginx.ingress.kubernetes.io/rewrite-target: /
    spec:
      ingressClassName: http-ingress
      rules:
        - http:
            paths:
            {{ range $resource := .Resources }}
            - path: /{{ .metadata.name }}
              pathType: Prefix
              backend:
                service:
                  name: {{ .metadata.name }}
                  port:
                    {{ range .spec.ports }}
                    {{ if or (eq .port 443 ) (eq .port 8443 ) }}
                    number: {{ .port }}
                    {{ end }}
                    {{ end }}
            {{ end }}
```

If we have two Service instance in the managed cluster in the namespace `eng`

```bash
kubectl get service -n eng
NAME           TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)           AGE
my-service     ClusterIP   10.225.83.46   <none>        80/TCP,443/TCP    15m
my-service-2   ClusterIP   10.225.108.8   <none>        80/TCP,8443/TCP   14m
```

Sveltos will create below Ingress instance.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    projectsveltos.io/hash: sha256:bc1e74450d20acedefca38f20cb998b7b24c12ac34e4b501d19b617568926140
  creationTimestamp: "2023-03-16T16:35:11Z"
  generation: 1
  labels:
    projectsveltos.io/reference-kind: ConfigMap
    projectsveltos.io/reference-name: sveltos-l6hldpydjngao4r23evm
    projectsveltos.io/reference-namespace: projectsveltos
  name: ingress
  namespace: default
  ownerReferences:
  - apiVersion: config.projectsveltos.io/v1alpha1
    kind: ClusterProfile
    name: sveltos-rgdn6jsy9zivek7e9mtz
    uid: 29f3552b-be4b-447f-bfc0-aedbad5b21db
  resourceVersion: "6186"
  uid: 080a6713-4da1-45a4-b189-2ded216fc688
spec:
  ingressClassName: http-ingress
  rules:
  - http:
      paths:
      - backend:
          service:
            name: my-service
            port:
              number: 443
        path: /my-service
        pathType: Prefix
      - backend:
          service:
            name: my-service-2
            port:
              number: 8443
        path: /my-service-2
        pathType: Prefix
status:
  loadBalancer: {}
```
