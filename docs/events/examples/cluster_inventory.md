---
title: Example - Cluster Inventory via ClusterProfile API (Revised)
description: Use Sveltos Event Framework to support KEP-4322 ClusterProfile API by converting ClusterProfile CRs into SveltosCluster resources and mirroring kubeconfig Secrets.
tags:
    - Kubernetes
    - Sveltos
    - event driven
    - multi-cluster
    - ClusterProfile
    - KEP-4322
authors:
    - kahirokunn
    - Gianluca Mardente
---

## Overview

KEP-4322 (Cluster Inventory / ClusterProfile API) from SIG Multi-Cluster proposes a `ClusterProfile` API to represent a standard inventory of clusters. See the proposal: [KEP-4322: Cluster Inventory](https://github.com/kubernetes/enhancements/tree/master/keps/sig-multicluster/4322-cluster-inventory).

- **Cluster Inventory**: API-driven list of clusters that tools can discover and act on.
- **ClusterProfile**: A CRD that represents a single cluster (namespaced, identity, properties, status).

### Problem

Sveltos does not natively support SIG Multi-Cluster ClusterProfile.

### Solution

Use Sveltos’ **Event Framework** to:

1. Watch `ClusterProfile` objects (`multicluster.x-k8s.io/v1alpha1`) via `EventSource detect-cluster-inventory-api-cluster-profiles`.
2. For each, trigger `EventTrigger register-cluster` to create a matching `SveltosCluster`.
3. Watch kubeconfig Secrets labeled with `x-k8s.io/cluster-profile` via `EventSource detect-config-secret`.
4. For each, trigger `EventTrigger update-sveltoscluster` to create the Secret layout expected by `SveltosCluster`.

---

## Prerequisites

- Sveltos (including the Event Framework) installed on the management cluster.
- The management cluster labeled so Sveltos can target it (examples use `env: management`).
- ClusterProfile CRDs present (`apiVersion: multicluster.x-k8s.io/v1alpha1`).

---

## Architecture

In the **management cluster**, Sveltos and its Event Framework run the following components:

- **EventSource: `detect-cluster-inventory-api-cluster-profiles`**
  Watches all `ClusterProfile` objects.
- **EventTrigger: `register-cluster`**
  Instantiates a `SveltosCluster` resource from each `ClusterProfile` (same name/namespace, labels copied).
- **EventSource: `detect-config-secret`**
  Watches kubeconfig `Secret` objects that carry the label `x-k8s.io/cluster-profile`.
- **EventTrigger: `update-sveltoscluster`**
  Creates the Secret in the format expected by the corresponding `SveltosCluster`.

---

## Step 1: Detect ClusterProfiles and create SveltosClusters

Define `EventSource detect-cluster-inventory-api-cluster-profiles` to select every `ClusterProfile`. Then define `EventTrigger register-cluster` that instantiates a `SveltosCluster` with matching metadata.

!!! example "EventSource (detect ClusterProfiles)"
    ```yaml
    cat > eventsource-clusterprofiles.yaml <<EOF
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: EventSource
    metadata:
      name: detect-cluster-inventory-api-cluster-profiles
    spec:
      collectResources: true
      resourceSelectors:
      - group: "multicluster.x-k8s.io"
        version: "v1alpha1"
        kind: "ClusterProfile"
    EOF
    ```

!!! example "EventTrigger (create SveltosClusters)"
    ```yaml
    cat > eventtrigger-create-sveltosclusters.yaml <<EOF
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: EventTrigger
    metadata:
      name: register-cluster
    spec:
      sourceClusterSelector:
        matchLabels:
          env: management
      eventSourceName: detect-cluster-inventory-api-cluster-profiles
      oneForEvent: true
      policyRefs:
      - name: sveltoscluster-metadata
        namespace: default
        kind: ConfigMap
    ---
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: sveltoscluster-metadata
      namespace: default
      annotations:
        projectsveltos.io/instantiate: ok
    data:
      sveltos-cluster.yaml: |
        apiVersion: lib.projectsveltos.io/v1beta1
        kind: SveltosCluster
        metadata:
          name: {{ .Resource.metadata.name }}
          namespace: {{ .Resource.metadata.namespace }}
          {{- with .Resource.metadata.labels }}
          labels:
            {{- range $key, $value := . }}
            {{ $key }}: {{ $value }}
            {{- end }}
          {{- end }}
        spec:
          kubeconfigKeyName: config
    EOF
    ```

---

## Step 2: Detect kubeconfig Secrets and create expected Secret

Define `EventSource detect-config-secret` to detect `Secret` objects labeled with `x-k8s.io/cluster-profile`. Then define `EventTrigger update-sveltoscluster` to generate the Secret consumed by the corresponding `SveltosCluster`.

!!! example "EventSource (detect kubeconfig Secrets)"
    ```yaml
    cat > eventsource-kubeconfig-secrets.yaml <<EOF
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: EventSource
    metadata:
      name: detect-config-secret
    spec:
      collectResources: true
      resourceSelectors:
      - group: ""
        version: "v1"
        kind: "Secret"
        labelFilters:
        - key: "x-k8s.io/cluster-profile"
          operation: Has
    EOF
    ```

!!! example "EventTrigger (create kubeconfig Secret)"
    ```yaml
    cat > eventtrigger-create-kubeconfig-secret.yaml <<EOF
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: EventTrigger
    metadata:
      name: update-sveltoscluster
    spec:
      sourceClusterSelector:
        matchLabels:
          env: management
      eventSourceName: detect-config-secret
      oneForEvent: true
      policyRefs:
      - name: sveltoscluster-spec
        namespace: default
        kind: ConfigMap
    ---
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: sveltoscluster-spec
      namespace: default
      annotations:
        projectsveltos.io/instantiate: ok
    data:
      sveltos-cluster.yaml: |
        {{ $value := (index .Resource.metadata.labels `x-k8s.io/cluster-profile`) }}
        apiVersion: v1
        kind: Secret
        metadata:
          name: {{ $value }}-sveltos-kubeconfig
          namespace: {{ .Resource.metadata.namespace }}
        data:
          {{ range $key, $value := .Resource.data }}
            {{ $key }}: {{ $value }}
          {{end}}
    EOF
    ```

---

## Result

- `ClusterProfile` resources become discoverable inventory items, materialized as `SveltosCluster` resources with copied labels.
- Kubeconfig Secrets labeled for a `ClusterProfile` are mirrored into the format expected by `SveltosCluster`.

This bridges KEP-4322’s `ClusterProfile` API with Sveltos’ native model using the event-driven framework—no changes required in Sveltos core.
