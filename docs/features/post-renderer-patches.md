---
title: Post Renderer Patches
description: Post renderer patches can be applied to Helm Chart, Kustomize and YAML/JSON.
tags:
    - Kubernetes
    - add-ons
    - rolling upgrades
authors:
    - Gianluca Mardente
---

Sveltos offers a powerful capability called post-rendering. This allows you to make adjustments to generated manifests before deploying them to your managed clusters.

Imagine you're installing a Helm chart that lacks built-in label configuration. You want to add a `enviroment: production` label to all deployed instances. Here's where post-rendering shines! By using a post-render patch, you can achieve this without modifying the original chart.

The provided YAML snippet demonstrates this concept. It defines a ClusterProfile that targets deployments and injects a `enviroment: production` label using a strategic merge patch. This ensures all deployments receive the label during installation.


```yaml hl_lines="21-30"
kind: ClusterProfile
metadata:
  name: deploy-kyverno
spec:
  clusterSelector:
    matchLabels:
      env: fv
  syncMode: Continuous
  helmCharts:
  - repositoryURL:    https://kyverno.github.io/kyverno/
    repositoryName:   kyverno
    chartName:        kyverno/kyverno
    chartVersion:     v3.3.3
    releaseName:      kyverno-latest
    releaseNamespace: kyverno
    helmChartAction:  Install
  policyRefs:
  - name: disallow-latest
    namespace: default
    kind: ConfigMap
  patches:
  - target:
      group: apps
      version: v1
      kind: Deployment
      name: ".*"
    patch: |
      - op: add
        path: /metadata/labels/environment
        value: production
```

This is yet another example

```yaml hl_lines="17-34"
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: nginx
spec:
  clusterSelector:
    matchLabels:
      env: fv
  helmCharts:
  - chartName: nginx-stable/nginx-ingress
    chartVersion: 1.1.3
    helmChartAction: Install
    releaseName: nginx-latest
    releaseNamespace: nginx
    repositoryName: nginx-stable
    repositoryURL: https://helm.nginx.com/stable/
  patches:
  - patch: |-
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name:  nginx-latest-nginx-ingress-controller
      spec:
        template:
          spec:
            containers:
            - name: nginx-ingress
              imagePullPolicy: Always
              securityContext:
                readOnlyRootFilesystem: true
    target:
      group: apps
      kind: Deployment
      version: v1
```

# Dynamic Post-Render Patches

Sveltos allows you to decouple your patches from the `ClusterProfile` definition. By using `patchesFrom`, you can reference ConfigMaps or Secrets that contain specific patch definitions.

This is particularly useful when:

1. **Security**: Patches contain sensitive information (use a Secret).
2. **Scalability**: You want to use one ClusterProfile for hundreds of clusters but need each cluster to have slightly different configurations (e.g., different replica counts or specialized node selectors).

The `name` and `namespace` fields in `patchesFrom` support Go templating. Sveltos resolves these templates at runtime using the target cluster's information.

## Configuration Example

```yaml
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: dynamic-nginx-deployment
spec:
  # Sveltos will look for a ConfigMap named after the cluster itself
  patchesFrom:
  - kind: ConfigMap
    name: "{{ .Cluster.metadata.name }}-overrides"
    namespace: "default"
    optional: true
  clusterSelector:
    matchLabels:
      tier: production
  policyRefs:
  - name: nginx-base-config
    namespace: default
    kind: ConfigMap
```

In this example, we deploy a standard Nginx agent to all production clusters, but we use `patchesFrom` to ensure that specific clusters get higher CPU/Memory limits and specialized node affinity without changing the base manifest.

If you have a cluster named cluster-high-perf, you would create the following ConfigMap. Sveltos will fetch this automatically because of the {{ .Cluster.metadata.name }}-overrides template.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cluster-high-perf-overrides
  namespace: default
data:
  # This patch increases replicas and adds resource constraints
  patches-nginx-deployment: |2
      patch: |
        - op: replace
          path: /spec/replicas
          value: 5
        - op: add
          path: /spec/template/spec/containers/0/resources
          value:
            limits:
              cpu: "1"
              memory: "1Gi"
            requests:
              cpu: "500m"
              memory: "512Mi"
      target:
        kind: Deployment
        name: nginx-deployment
```

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-base-config
  namespace: default
data:
  nginx.yaml: |
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: nginx-deployment
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
            image: nginx:latest
            ports:
            - containerPort: 80
```

## How it works

1. **The Match**: Sveltos identifies a cluster matching the selector.
1. **The Lookup**: It evaluates the template. For cluster-high-perf, it looks for a ConfigMap with that specific name.
1. **The Merge**:
  * If found: Sveltos applies the replicas and resource patches to the base Nginx deployment.
  * If not found: Since optional: true, Sveltos simply deploys the base Nginx deployment with 1 replica and no resource limits.

## Key Benefits of this Approach

1. **No Manual Updates**: Updating the ClusterProfile is not required every time a new cluster is added. A ConfigMap can be created by following the naming convention.
1. **Dry Principle**: Duplicating the entire Deployment manifest just to change a few fields for specific environments is avoided.
1. **Graceful Degradation**: The `optional: true` flag acts as a safety net, ensuring a "sane default" configuration is deployed even if a specific patch does not exist yet.

## Strategic Merge Patch Example: Environment Hardening

In this scenario, we use a single `ClusterProfile` to deploy a the same nginx deployment. We use `patchesFrom` to pull in environment-specific security settings (like `securityContext` and `nodeSelector`) based on the cluster's name.

```yaml
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: nginx-deploy
spec:
  patchesFrom:
  - kind: ConfigMap
    # Templates allow per-cluster customization
    name: "{{ .Cluster.metadata.name }}-hardening"
    namespace: "default"
    optional: true
  clusterSelector:
    matchLabels:
      tier: production
  policyRefs:
  - name: nginx-base-config
    namespace: default
    kind: ConfigMap
```

For a cluster named `edge-node-01`, you create this ConfigMap. Instead of using `op: replace` (JSON Patch syntax), we simply provide the partial YAML we want to merge into the original.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: edge-node-01-hardening
  namespace: default
data:
  nginx-deployment-patch: |-
    patch: |
      apiVersion: apps/v1
      kind: Deployment
      metadata:
        name: not-important
      spec:
        template:
          spec:
            # Strategic Merge adds/overwrites these specific sections
            securityContext:
              runAsNonRoot: true
              runAsUser: 1000
            nodeSelector:
              location: edge-facility
    target:
      kind: Deployment
      name: nginx-deployment
```