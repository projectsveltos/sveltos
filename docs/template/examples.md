---
title: Templates
description: Examples using copy, setField, removeField, getField and chain methods
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

# Introduction to Template Examples with copy, setField, removeField and chain methods

## Copy Example

This example demonstrates how to copy a Secret from the management cluster to matching managed clusters using Sveltos.

Create a Secret named __imported-secret__ in the __default__ namespace of your management cluster. This Secret should contain Docker registry credentials encoded in base64 format. 

```
kubectl apply -f - <<EOF
apiVersion: v1
data:
  .dockerconfigjson: ewogICAgImF1dGhzIjogewogICAgICAgICJodHRwczovL2luZGV4LmRvY2tlci5pby92MS8iOiB7CiAgICAgICAgICAgICJhdXRoIjogIkxXWWdjR0Z6YzNkdmNtUUsiCiAgICAgICAgfQogICAgfQp9Cg==
kind: Secret
metadata:
  name: imported-secret
  namespace: default
type: kubernetes.io/dockerconfigjson
EOF
```

and a ClusterProfile fetching this resource

```yaml hl_lines="9-15"
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: deploy-resources
spec:
  clusterSelector:
    matchLabels:
      env: production
  templateResourceRefs:
  - resource:
      apiVersion: v1
      kind: Secret
      name: imported-secret
      namespace: default
    identifier: ExternalSecret
  policyRefs:
  - kind: ConfigMap
    name: info
    namespace: default
```

To simply copy the Secret grabbed from the management cluster to any matching managed cluster

```yaml hl_lines="10"
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: info
      namespace: default
      annotations:
        projectsveltos.io/template: "true"  # add annotation to indicate Sveltos content is a template
    data:
      secret.yaml: |
        {{ copy "ExternalSecret" }}
```

!!! note
     we can define any resource contained in a referenced ConfigMap/Secret as a template by adding the `projectsveltos.io/template` annotation. This ensures that the template is instantiated at the deployment time, making the deployments faster and more efficient.

This template simply references the ExternalSecret identifier (defined in the ClusterProfile) using the copy function. 
Consequently, the Secret from the management cluster will be copied to any matching managed clusters.

## SetField/RemoveField Example

This section demonstrates how to leverage Sveltos's __setField__ and __removeField__ functions within templates to manipulate deployments across managed clusters.

Let's create a Deployment in the management cluster

```
kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
  namespace: default
  labels:
    apps: nginx
spec:
  replicas: 3
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
        image: nginx:latest
        ports:
        - containerPort: 1
EOF
```

and a ClusterProfile fetching this resource

```yaml hl_lines="9-15"
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: deploy-resources
spec:
  clusterSelector:
    matchLabels:
      env: production
  templateResourceRefs:
  - resource:
      apiVersion: apps/v1
      kind: Deployment
      name: nginx-deployment
      namespace: default
    identifier: NginxDeployment
  policyRefs:
  - kind: ConfigMap
    name: info
    namespace: default
```

```yaml hl_lines="10"
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: info
      namespace: default
      annotations:
        projectsveltos.io/template: "true"  # add annotation to indicate Sveltos content is a template
    data:
      secret.yaml: |
        {{ setField "NginxDeployment" "spec.replicas" (int64 5) }}
```

This template will:

1. Copy the NginxDeployment (referencing the original deployment).
2. Update the spec.replicas field to 5.
3. Deploy the modified deployment to matching managed clusters.

Consequently, each managed cluster will have the deployment running with 5 replicas.

```yaml hl_lines="10"
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: info
      namespace: default
      annotations:
        projectsveltos.io/template: "true"  # add annotation to indicate Sveltos content is a template
    data:
      secret.yaml: |
        {{ removeField "NginxDeployment" "spec.replicas" }}
```

Here, the template:

1. Copies the NginxDeployment.
2. Removes the spec.replicas field.
3. Deploys the modified deployment.

Since the replicas field is missing, Kubernetes will use the default value (typically 1) for replicas in each managed cluster.

## ChainSetField/ChainRemoveField Example

Building upon the previous example, this section explores how to manipulate various fields within the copied Deployment using Sveltos's __chainSetField__ function.

```yaml hl_lines="10-15"
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: info
      namespace: default
      annotations:
        projectsveltos.io/template: "true"  # add annotation to indicate Sveltos content is a template
    data:
      secret.yaml: |
        {{ $depl := (getResource "NginxDeployment") }}
        {{ $depl := (chainSetField $depl "spec.replicas" (int64 1) ) }}
        {{ $depl := (chainSetField $depl "metadata.namespace" .Cluster.metadata.namespace ) }}
        {{ $depl := (chainSetField $depl "spec.template.spec.serviceAccountName" "default" ) }}
        {{ $depl := (chainSetField $depl "spec.paused" true ) }}
        {{ toYaml $depl }}
```

1. Fetch Deployment: __{{ $depl := (getResource "NginxDeployment") }}__ retrieves the deployment referenced by the identifier NginxDeployment (defined in the ClusterProfile).
2. Chain Modifications: The __chainSetField__ function is used repeatedly to modify specific fields:
  - spec.replicas: Sets the number of replicas to 1.
  - metadata.namespace: Sets the namespace to the current cluster's namespace (fetched using .Cluster.metadata.namespace).
  - spec.template.spec.serviceAccountName: Sets the service account name to "default".
  - spec.paused: Sets the deployment to be paused (not running).
3. Convert to YAML: Finally, __{{ toYaml $depl }}__ converts the modified deployment object back into YAML format for deployment on the managed cluster.

## Combing all together

This example demonstrates a more complex scenario where the template modifies the image tag within the copied deployment.

```yaml hl_lines="10-15"
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: info
      namespace: default
      annotations:
        projectsveltos.io/template: "true"  # add annotation to indicate Sveltos content is a template
    data:
      secret.yaml: |
        {{ $currentContainers := (getField "NginxDeployment" "spec.template.spec.containers") }}
        {{ $modifiedContainers := list }}
        {{- range $element := $currentContainers }}
          {{ $modifiedContainers = append $modifiedContainers (chainSetField $element "image" "nginx:1.13" ) }}
        {{- end }}
        {{ setField "NginxDeployment" "spec.template.spec.containers" $modifiedContainers }}
```