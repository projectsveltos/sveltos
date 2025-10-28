---
title: Example - Cluster Inventory Push Model via Sveltos (CAPI-based)
description: Implement KEP-4322 Push Model using Sveltos Event Framework with Cluster API resources and labels to distribute kubeconfig Secrets to consumer namespaces.
tags:
    - Kubernetes
    - Sveltos
    - event driven
    - multi-cluster
    - KEP-4322
    - ClusterProfile
    - Push Model
    - Cluster API
authors:
    - kahirokunn
    - Gianluca Mardente
---

## Overview

This example shows how to implement the KEP-4322 Cluster Inventory Push Model with Sveltos’ Event Framework. The management cluster acts as the Cluster Manager and publishes kubeconfig credentials as Secrets into consumer namespaces.

Throughout this guide, “ClusterProfile” refers to the SIG Multi-Cluster ClusterProfile concept. This walkthrough focuses on generating the Secret (credentials) corresponding to a ClusterProfile. We define a labeling convention on Cluster API `Cluster` resources to indicate the intended ClusterProfile and to locate the corresponding CAPI-derived kubeconfig `Secret` that Sveltos will distribute.

References:

- [KEP-4322](https://github.com/kubernetes/enhancements/tree/master/keps/sig-multicluster/4322-cluster-inventory)
- [Push Model details](https://github.com/kubernetes/enhancements/tree/master/keps/sig-multicluster/4322-cluster-inventory#push-model-via-credentials-in-secret-not-recommended)

---

## Prerequisites

- Sveltos (Event Framework) installed in the management cluster.
- The management cluster labeled so Sveltos can target it, for example: `cluster-api: enabled`. See [Register management cluster](https://projectsveltos.github.io/sveltos/main/register/register-cluster/#register-management-cluster) for label-based management.
- Cluster API `Cluster` resources labeled to declare the intended ClusterProfile (SIG Multi-Cluster): `clusterprofile-name` (required) and optionally:
  - `clusterprofile-namespace`
  - `clusterset.k8s.io`
- Consumer namespaces labeled with `x-k8s.io/cluster-inventory-consumer`.
- Optional: Namespaces labeled with `clusterset.multicluster.x-k8s.io` to group by ClusterSet.

---

## Label Conventions and Namespace Resolution

These labels express which ClusterProfile (SIG Multi-Cluster) a Cluster targets and how to derive the namespace for Secret generation. No ClusterProfile resources are required for this walkthrough.

- Required label on `Cluster`:
  - `clusterprofile-name`: ClusterProfile name.
- Optional labels on `Cluster`:
  - `clusterprofile-namespace`: explicit ClusterProfile namespace (used when naming/labeling generated Secrets).
  - `clusterset.k8s.io`: ClusterSet name (used to map to a namespace labeled `clusterset.multicluster.x-k8s.io`).
- Namespace resolution for ClusterProfile (priority):
  1) `clusterprofile-namespace` on the `Cluster`
  2) A `Namespace` whose label `clusterset.multicluster.x-k8s.io` equals the `Cluster` label `clusterset.k8s.io`
  3) Fallback to `default`

---

## Architecture

In the management cluster, the following Sveltos components operate:

- EventSource: `cluster-inventory-consumer-credentials-from-capi`
  - Collects Cluster API `Cluster` with the required labels, kubeconfig `Secret`s, consumer `Namespace`s, and ClusterSet grouping `Namespace`s.
- Aggregated Selection (Lua):
  - Builds synthetic resources `InventorySecretTarget` by combining Cluster × Consumer Namespace pairs, resolving kubeconfig and ClusterProfile namespace.
- EventTrigger: `cluster-inventory-consumer-credentials-from-capi`
  - Executes a ConfigMap template per synthetic resource (`oneForEvent: true`).
- ConfigMap Template: `cluster-inventory-consumer-credentials-from-capi-template`
  - Creates KEP-4322-compliant Secrets in consumer namespaces.

---

## Step 1: EventSource with Aggregated Selection (Lua)

!!! example "EventSource (collect CAPI resources and synthesize targets)"
    ```yaml
    cat > eventsource-push-model-from-capi.yaml <<EOF
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: EventSource
    metadata:
      name: cluster-inventory-consumer-credentials-from-capi
    spec:
      collectResources: true
      resourceSelectors:
        # Cluster API Cluster with ClusterProfile labels
        - group: cluster.x-k8s.io
          version: v1beta1
          kind: Cluster
          namespace: mgmt
          labelFilters:
            - key: "clusterprofile-name"
              operation: Has
        # kubeconfig Secret from Cluster API
        - group: ""
          version: v1
          kind: Secret
          labelFilters:
            - key: "cluster.x-k8s.io/cluster-name"
              operation: Has
          evaluateCEL:
            - name: secret_name_ends_with_kubeconfig
              rule: resource.metadata.name.endsWith("-kubeconfig")
            - name: secret_type_is_cluster_api
              rule: resource.type == "cluster.x-k8s.io/secret"
        # Consumer Namespaces
        - group: ""
          version: v1
          kind: Namespace
          labelFilters:
            - key: "x-k8s.io/cluster-inventory-consumer"
              operation: Has
        # ClusterSet grouping Namespaces
        - group: ""
          version: v1
          kind: Namespace
          labelFilters:
            - key: "clusterset.multicluster.x-k8s.io"
              operation: Has

      aggregatedSelection: |
        -- Returns synthetic resources, each pairing {cluster, kubeconfigSecret, consumerNamespace}
        -- Emitted schema (kind: InventorySecretTarget):
        --   spec:
        --     clusterName: string
        --     kubeconfigRaw: base64 string
        --     targetNamespace: string  (consumer Namespace.metadata.name)
        --     clusterProfileName: string (Cluster label clusterprofile-name)
        --     clusterProfileNamespace: string
        --       Priority:
        --         1) Cluster label clusterprofile-namespace
        --         2) Namespace whose label clusterset.multicluster.x-k8s.io == Cluster label clusterset.k8s.io
        --         3) "default"

        local function getLabel(obj, key)
          if obj and obj.metadata and obj.metadata.labels then
            return obj.metadata.labels[key]
          end
          return nil
        end

        function evaluate()
          local hs = {}

          local clusters = {}
          local secrets  = {}
          local namespaces = {}

          for _, res in ipairs(resources) do
            if res.kind == "Cluster" then
              table.insert(clusters, res)
            elseif res.kind == "Secret" then
              table.insert(secrets, res)
            elseif res.kind == "Namespace" then
              table.insert(namespaces, res)
            end
          end

          -- index secrets by "cluster.x-k8s.io/cluster-name"
          local secIndex = {}
          for _, s in ipairs(secrets) do
            local lbl = (s.metadata and s.metadata.labels) or {}
            local k = lbl["cluster.x-k8s.io/cluster-name"]
            -- accept .data.value or .data.kubeconfig
            if k and s.data and (s.data["value"] or s.data["kubeconfig"]) then
              secIndex[k] = s
            end
          end

          -- split namespaces:
          --  - consumerNamespaces: have x-k8s.io/cluster-inventory-consumer
          --  - clustersetNamespaces: map from clustersetName -> namespaceName (first wins)
          local consumerNamespaces = {}
          local clustersetNsByName = {}
          for _, ns in ipairs(namespaces) do
            local lbls = (ns.metadata and ns.metadata.labels) or {}

            if lbls["x-k8s.io/cluster-inventory-consumer"] ~= nil then
              table.insert(consumerNamespaces, ns)
            end

            local csName = lbls["clusterset.multicluster.x-k8s.io"]
            if csName and clustersetNsByName[csName] == nil then
              -- record the first namespace discovered for this clusterset
              clustersetNsByName[csName] = ns.metadata and ns.metadata.name or nil
            end
          end

          local combined = {}

          for _, cl in ipairs(clusters) do
            local clName = cl.metadata and cl.metadata.name
            if clName then
              local sec = secIndex[clName]

              local kubeRaw = nil
              local secName = nil
              local secNs   = nil
              if sec and sec.data then
                kubeRaw = sec.data["value"] or sec.data["kubeconfig"]
                secName = sec.metadata and sec.metadata.name or nil
                secNs   = sec.metadata and sec.metadata.namespace or nil
              end

              if kubeRaw then
                -- derive ClusterProfile name
                local cpName = getLabel(cl, "clusterprofile-name")

                -- resolve ClusterProfile namespace
                local cpNs = getLabel(cl, "clusterprofile-namespace")

                if not cpNs then
                  local clusterSetName = getLabel(cl, "clusterset.k8s.io")
                  if clusterSetName then
                    cpNs = clustersetNsByName[clusterSetName]
                  end
                end

                if not cpNs or cpNs == "" then
                  cpNs = "default"
                end

                -- emit target per consumer namespace
                for _, ns in ipairs(consumerNamespaces) do
                  local nsName = ns.metadata and ns.metadata.name
                  if nsName then
                    table.insert(combined, {
                      apiVersion = "projectsveltos.io/v1alpha1",
                      kind = "InventorySecretTarget",
                      metadata = {
                        name = clName .. "--" .. nsName,
                        namespace = "mgmt",
                        labels = cl.metadata and cl.metadata.labels or {},
                        annotations = cl.metadata and cl.metadata.annotations or {},
                      },
                      spec = {
                        clusterName = clName,
                        kubeconfigRaw = kubeRaw,
                        kubeconfigSecretName = secName,
                        kubeconfigSecretNamespace = secNs,
                        targetNamespace = nsName,
                        clusterProfileName = cpName,
                        clusterProfileNamespace = cpNs,
                      },
                    })
                  end
                end
              end
            end
          end

          if #combined > 0 then
            hs.resources = combined
          end
          return hs
        end
    EOF
    ```

---

## Step 2: EventTrigger per Synthetic Resource

!!! example "EventTrigger (instantiate template one per event)"
    ```yaml
    cat > eventtrigger-push-model-from-capi.yaml <<EOF
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: EventTrigger
    metadata:
      name: cluster-inventory-consumer-credentials-from-capi
    spec:
      sourceClusterSelector:
        matchLabels:
          cluster-api: enabled
      eventSourceName: cluster-inventory-consumer-credentials-from-capi
      oneForEvent: true
      policyRefs:
        - kind: ConfigMap
          namespace: mgmt
          name: cluster-inventory-consumer-credentials-from-capi-template
    EOF
    ```

---

## Step 3: ConfigMap Template to Create KEP-4322 Secret

!!! example "ConfigMap (create kubeconfig Secret in consumer namespaces)"
    ```yaml
    cat > cm-push-model-template.yaml <<EOF
    ---
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: cluster-inventory-consumer-credentials-from-capi-template
      namespace: mgmt
      annotations:
        projectsveltos.io/instantiate: ok
        projectsveltos.io/subresources: status
    data:
      secret.yaml: |
        {{- $spec := .Resource.spec -}}
        {{- $cpName := $spec.clusterProfileName -}}
        {{- $cpNs := $spec.clusterProfileNamespace | default "default" -}}

        apiVersion: v1
        kind: Secret
        metadata:
          name: {{ printf "%s-%s-kubeconfig" $cpNs $cpName }}
          namespace: {{ $spec.targetNamespace }}
          labels:
            x-k8s.io/cluster-profile: {{ $cpName }}
            x-k8s.io/cluster-profile-namespace: {{ $cpNs }}
        type: Opaque
        data:
          config: {{ $spec.kubeconfigRaw }}
    EOF
    ```

---

## KEP-4322 Compliance

- Places Secrets in namespaces labeled `x-k8s.io/cluster-inventory-consumer`.
- Labels each Secret with `x-k8s.io/cluster-profile` and `x-k8s.io/cluster-profile-namespace`.
- Stores kubeconfig under `data.config`.
- Supports grouping via ClusterSets by mapping `clusterset.k8s.io` to namespaces labeled `clusterset.multicluster.x-k8s.io`.

---

## Result

- For every Cluster × Consumer namespace pair, a Secret named `{clusterProfileNamespace}-{clusterProfileName}-kubeconfig` is created in the consumer namespace.
- This enables consumers to discover and consume cluster credentials following the Push Model of KEP-4322 while keeping Sveltos core unchanged.
