---
title: Example Dynamic Nginx Deploymemt based on Namespace Annotation
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
    - Eleni Grosdouli
---

## Scenario Description

In a fast-changing and often complex Kubernetes environment, it is important for Platform teams and engineers to automate application deployments using unique identifiers. For instance, actions or deployments can be triggered only when a Kubernetes resource has a specific annotation.

This example demonstrates how namespace annotations can be used as key identifiers. By using these annotations, Sveltos can automatically deploy different versions of the Nginx server to different namespaces based on the annotations set.

### Namespace EventSource

!!! example "Example - EventSource Definition"
    ```yaml
    cat > eventsource.yaml <<EOF
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: EventSource
    metadata:
      name: find-all-namespaces
    spec:
      collectResources: true
      resourceSelectors:
      - group: ""
        version: "v1"
        kind: "Namespace"
    ```

The `EventSource` described above will trigger the following `EventTrigger` action for each namespace in the Kubernetes cluster.

### EventTrigger Defintion

!!! example "Example - EventTrigger Definition"
    ```yaml
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: EventTrigger
    metadata:
      name: deploy-nginx
    spec:
      sourceClusterSelector:
        matchLabels:
          env: fv
      eventSourceName: find-all-namespaces
      oneForEvent: true
      policyRefs:
      - name: deploy-nginx
        namespace: default
        kind: ConfigMap
    ```

!!! example "Example - ConfigMap deploy-nginx"
    ```yaml
    ---
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: deploy-nginx
      namespace: default
      annotations:
        projectsveltos.io/instantiate: ok # this annotation is what tells Sveltos to instantiate this ConfigMap
    data:
      networkpolicy.yaml: |
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: nginx-deployment
          namespace: {{ .Resource.metadata.name }}
          labels:
            app: nginx
        spec:
          replicas: 1
          selector:
            matchLabels:
              app: nginx
          template:
            metadata:
              labels:
                app: nginx
            spec:
              containers:
              - name: nginx
                {{- if (index .Resource.metadata `annotations`) -}}
                {{- if (index .Resource.metadata.annotations `nginx`) }}
                image: nginx:{{ .Resource.metadata.annotations.nginx }}
                {{- else }} # nginx key does NOT exist within annotations
                image: nginx:1.14.2
                {{- end }}
                {{- else }} # annotations not present
                image: nginx:1.14.2
                {{- end }}
                ports:
                - containerPort: 80
    ```

When the `EventTrigger` resource is activated, Sveltos is instructed to deploy the `ConfigMap` named `deploy-nginx` only to **managed** clusters labeled with _env:fv_.

The `ConfigMap` is expressed as a Sveltos Template, which allows simple conditions to determine which Nginx version should be deployed based on the namespace annotation.

```yaml
{{- if (index .Resource.metadata `annotations`) -}}
{{- if (index .Resource.metadata.annotations `nginx`) }}
image: nginx:{{ .Resource.metadata.annotations.nginx }}
{{- else }} # nginx key does NOT exist within annotations
image: nginx:1.14.2
{{- end }}
{{- else }} # annotations not present
image: nginx:1.14.2
{{- end }}
```

If the annotation `nginx` is present in a namespace, Nginx with the specified version (image: nginx:<defined Nginx Version>) will be installed. If the nginx annotation is missing or no annotations are set, Nginx version 1.14.2 will be installed by default.

## Next Steps

To explore more about the powerful features of Sveltos Templates, have a look [here](../templating.md).
