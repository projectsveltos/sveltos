---
title: Example – multi-cluster Services via Sveltos Event Framework (KEP-1645)
description: Use Sveltos' Event Framework to implement the mcs-controller.
tags:
    - Kubernetes
    - Sveltos
    - event driven
    - multi-cluster
    - MCS
    - KEP-1645
authors:
    - kahirokunn
    - Gianluca Mardente
---

## Overview

KEP-1645: Multi-Cluster Services (MCS) API from SIG Multi-Cluster standardizes how a Service in one cluster can be exported and discovered in others. See the proposal: [KEP-1645: Multi-Cluster Services (MCS) API](https://github.com/kubernetes/enhancements/tree/master/keps/sig-multicluster/1645-multi-cluster-services-api)

* **ServiceExport**: Marks a namespaced Service for export.
* **ServiceImport**: ClusterSet-scoped discovery surface for consumers.

### Problem Description

Sveltos does not ship a built-in controller for KEP-1645.

### Solution

Use Sveltos' **Event Framework** to automate the MCS pipeline:

1. Detect `ServiceExport` the corresponding `Service`.
2. Create a **derived Service** (normalized to `ClusterIP`) and then a **ServiceImport** populated from the derived Service.
3. Detect `EndpointSlice` updates and mirror them across clusters, ensuring label/shape compatibility for CoreDNS.

!!!note
The examples below focus on resource creation and synchronization. `status` updates (conditions on `ServiceExport`, health, conflicts) are out of scope here and can be implemented later with an auxiliary controller or an additional Event pipeline.

---

## KEP-1645 Specification

### Resource Roles

The MCS API defines the following resources:

* **ServiceExport**: Created in the source cluster to mark a Service for export
* **ServiceImport**: Created in consuming clusters for service discovery
* **Derived Service**: A regular Service object (`derived-<hash>`) that kube-proxy can recognize without modifications
* **EndpointSlice**: Contains the actual endpoint information, labeled for multi-cluster discovery

### Service Type Conversion Rules

| Source Service Type | ServiceImport Type | Derived Service Type | Notes |
|-------------------|-------------------|---------------------|-------|
| ClusterIP | ClusterSetIP | ClusterIP | Standard conversion |
| NodePort | ClusterSetIP | ClusterIP | Normalized to ClusterIP |
| LoadBalancer | ClusterSetIP | ClusterIP | Normalized to ClusterIP |
| Headless (`clusterIP: None`) | Headless | ClusterIP (headless) | Creates headless derived service |
| ExternalName | - | - | Cannot be exported |

### Naming Conventions and Labels

**Resource naming:**

* Derived Service: `derived-<adler32sum(ServiceExport name)>`
* EndpointSlice: `derived-<adler32sum(ServiceExport name)>-<cluster-id>`

**Labels:**

* `multicluster.kubernetes.io/service-name`: Original service name (on both derived Service and EndpointSlice)
* `kubernetes.io/service-name`: Derived service name (on EndpointSlice)
* `multicluster.kubernetes.io/service-imported: "true"` (on derived Service)

---

## Prerequisites

* Sveltos (and the Event Framework) installed in the management cluster.
* Source clusters labeled for selection; destination clusters labeled for consumption (examples below use [`clusterset.k8s.io: environ-1`](https://github.com/kubernetes/enhancements/tree/master/keps/sig-multicluster/2149-clusterid#clustersetk8sio-clusterproperty) and [`cluster.clusterset.k8s.io: <cluster-id>`](https://github.com/kubernetes/enhancements/tree/master/keps/sig-multicluster/2149-clusterid#clusterclustersetk8sio-clusterproperty)).
* [MCS CRDs](https://github.com/kubernetes-sigs/mcs-api/tree/master/config/crd) present (`apiVersion: multicluster.x-k8s.io/v1alpha1`).
* Consistent namespaces across clusters [namespace sameness](https://github.com/kubernetes/community/blob/master/sig-multicluster/namespace-sameness-position-statement.md).
* CoreDNS [v1.12.2+](https://github.com/coredns/coredns/releases/tag/v1.12.2) with the multicluster capability enabled.
* Flat Network connectivity: Pod IPs must be directly routable between clusters for this kube-proxy compatible implementation. The mirrored EndpointSlices contain actual Pod IPs that need to be reachable across cluster boundaries.

---

## Architecture

In the **management cluster**, Sveltos wires two event flows:

* **EventSource: `mcs-service-deriver`**
  Watches `ServiceExport` + `Service` and emits a **derived Service**.

* **EventSource: `mcs-serviceimport-generator`**
  Watches the **derived Service** and emits a **ServiceImport** whose `spec.ips` is copied from the derived Service's `.spec.clusterIPs`.

* **EventSource: `mcs-endpoint-mirror`**
  Watches `ServiceExport` + `EndpointSlice` and mirrors **EndpointSlice** data with required labels for DNS.

Each flow uses an **EventTrigger** plus a templated policy to render target resources in destination clusters. Hashing for derived names uses `adler32sum` over the ServiceExport name, producing stable `derived-<hash>` identifiers.

---

## Step 1: Detect ServiceExports & Services, then create derived Service

This step normalizes `ClusterIP`/`NodePort`/`LoadBalancer` into a **derived ClusterIP Service**.

!!! example "EventSource + EventTrigger + Policy (derived Service)"
    ```yaml
    cat > eventsource-service-deriver.yaml <<'EOF'
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: EventSource
    metadata:
      name: mcs-service-deriver
    spec:
      collectResources: true
      resourceSelectors:
      - group: "multicluster.x-k8s.io"
        version: "v1alpha1"
        kind: "ServiceExport"
      - group: ""
        version: "v1"
        kind: "Service"
      aggregatedSelection: | # lua
        function evaluate()
          local hs = {}
          local collectedServices = {}
          hs.message = ""

          local serviceExports = {}
          local services = {}

          -- Categorize resources by type
          for _, resource in ipairs(resources) do
            local group = ""
            if resource.apiVersion ~= nil then
              local parts = {}
              for part in string.gmatch(resource.apiVersion, "[^/]+") do
                table.insert(parts, part)
              end
              if #parts > 1 then
                group = parts[1]
              end
            end

            if resource.kind == "ServiceExport" and group == "multicluster.x-k8s.io" then
              local key = resource.metadata.namespace .. "/" .. resource.metadata.name
              serviceExports[key] = resource
            elseif resource.kind == "Service" and group == "" then
              table.insert(services, resource)
            end
          end

          -- Process Services
          for _, service in ipairs(services) do
            local serviceKey = service.metadata.namespace .. "/" .. service.metadata.name

            -- Check if a corresponding ServiceExport exists
            if serviceExports[serviceKey] ~= nil then
              -- Add ServiceExport information to the Service's labels
              if service.metadata.labels == nil then
                service.metadata.labels = {}
              end
              service.metadata.labels["service-export-name"] = service.metadata.name
              service.metadata.labels["service-export-namespace"] = service.metadata.namespace
              service.metadata.labels["multicluster.kubernetes.io/service-name"] = service.metadata.name

              table.insert(collectedServices, service)
              hs.message = hs.message .. "Found Service for ServiceExport: " .. service.metadata.name .. "\n"
            end
          end

          if #collectedServices > 0 then
            hs.resources = collectedServices
          end
          return hs
        end
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: EventTrigger
    metadata:
      name: mcs-service-deriver
    spec:
      sourceClusterSelector:
        matchExpressions:
        - key: cluster.clusterset.k8s.io
          operator: NotIn
          values:
          - ""
        - key: clusterset.k8s.io
          operator: In
          values:
          - environ-1
      eventSourceName: mcs-service-deriver
      oneForEvent: true
      syncMode: ContinuousWithDriftDetection
      policyRefs:
      - name: mcs-service-deriver
        namespace: mgmt
        kind: Secret
    ---
    apiVersion: v1
    kind: Secret
    metadata:
      name: mcs-service-deriver
      namespace: mgmt
      annotations:
        projectsveltos.io/instantiate: ok
    type: addons.projectsveltos.io/cluster-profile
    stringData:
      service.yaml: | # helm
        apiVersion: v1
        kind: Service
        metadata:
          name: derived-{{ .Resource.metadata.name | adler32sum }}
          namespace: {{ .Resource.metadata.namespace }}
          labels:
            multicluster.kubernetes.io/service-name: {{ .Resource.metadata.name }}
            multicluster.kubernetes.io/service-imported: "true"
            app.kubernetes.io/managed-by: sveltos
            {{- range $key, $value := .Resource.metadata.labels }}
            {{- if ne $key `service-export-name` }}
            {{- if ne $key `service-export-namespace` }}
            {{ $key }}: {{ $value }}
            {{- end }}
            {{- end }}
            {{- end }}
        spec:
          {{- if eq .Resource.spec.clusterIP `None` }}
          clusterIP: None
          {{- else }}
          type: ClusterIP
          {{- end }}
          {{- if .Resource.spec.selector }}
          selector:
            {{- range $key, $value := .Resource.spec.selector }}
            {{ $key }}: {{ $value }}
            {{- end }}
          {{- end }}
          {{- if .Resource.spec.ports }}
          ports:
          {{- range .Resource.spec.ports }}
          - name: {{ .name }}
            port: {{ .port }}
            {{- if .targetPort }}
            targetPort: {{ .targetPort }}
            {{- end }}
            protocol: {{ .protocol }}
          {{- end }}
          {{- end }}
    EOF
    ```

## Step 2: Create ServiceImport from the derived Service

This step reacts to the derived Service and generates the `ServiceImport`. For non-headless Services, `spec.ips` is copied from `.spec.clusterIPs`. For headless Services, `type: Headless` and `ips` is omitted.

!!! example "EventSource + EventTrigger + Policy (ServiceImport from derived Service)"
    ```yaml
    cat > eventsource-serviceimport-creator.yaml <<'EOF'
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: EventSource
    metadata:
      name: mcs-serviceimport-generator
    spec:
      collectResources: true
      resourceSelectors:
      - group: ""
        version: "v1"
        kind: "Service"
        labelFilters:
        - key: "multicluster.kubernetes.io/service-imported"
          operation: "Equal"
          value: "true"
        - key: "app.kubernetes.io/managed-by"
          operation: "Equal"
          value: "sveltos"
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: EventTrigger
    metadata:
      name: mcs-serviceimport-generator
    spec:
      sourceClusterSelector:
        matchExpressions:
        - key: cluster.clusterset.k8s.io
          operator: NotIn
          values:
          - ""
        - key: clusterset.k8s.io
          operator: In
          values:
          - environ-1
      eventSourceName: mcs-serviceimport-generator
      oneForEvent: true
      syncMode: ContinuousWithDriftDetection
      policyRefs:
      - name: mcs-serviceimport-generator
        namespace: mgmt
        kind: Secret
    ---
    apiVersion: v1
    kind: Secret
    metadata:
      name: mcs-serviceimport-generator
      namespace: mgmt
      annotations:
        projectsveltos.io/instantiate: ok
    type: addons.projectsveltos.io/cluster-profile
    stringData:
      serviceimport.yaml: | # helm
        apiVersion: multicluster.x-k8s.io/v1alpha1
        kind: ServiceImport
        metadata:
          name: {{ index .Resource.metadata.labels "multicluster.kubernetes.io/service-name" }}
          namespace: {{ .Resource.metadata.namespace }}
          annotations:
            multicluster.kubernetes.io/derived-service: {{ .Resource.metadata.name }}
        spec:
          type: {{ if eq .Resource.spec.clusterIP `None` }}Headless{{ else }}ClusterSetIP{{ end }}
          {{- if ne .Resource.spec.clusterIP `None` }}
          ips:
          {{- range .Resource.spec.clusterIPs }}
          - {{ . }}
          {{- end }}
          {{- end }}
          {{- if .Resource.spec.ports }}
          ports:
          {{- range .Resource.spec.ports }}
          - name: {{ .name }}
            port: {{ .port }}
            protocol: {{ .protocol }}
          {{- end }}
          {{- end }}
    EOF
    ```

---

## Step 3: Detect EndpointSlices & mirror them for DNS

This step watches `EndpointSlice` updates tied to exported Services and mirrors them into destination clusters. It ensures:

* `kubernetes.io/service-name` is set to the *derived* Service (`derived-<hash>`).
* EndpointSlice name follows the pattern: `derived-<hash>-<cluster-id>`.
* Other labels (e.g., per-cluster identity) are preserved.

!!! example "EventSource + EventTrigger + Policy (EndpointSlice mirroring)"
    ```yaml
    cat > eventsource-endpoint-mirror.yaml <<'EOF'
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: EventSource
    metadata:
      name: mcs-endpoint-mirror
    spec:
      collectResources: true
      resourceSelectors:
      - group: "multicluster.x-k8s.io"
        version: "v1alpha1"
        kind: "ServiceExport"
      - group: "discovery.k8s.io"
        version: "v1"
        kind: "EndpointSlice"
        labelFilters:
        - key: "kubernetes.io/service-name"
          operation: "Different"
          value: ""
      aggregatedSelection: | # lua
        function evaluate()
          local hs = {}
          local collectedEndpointSlices = {}
          hs.message = ""

          local serviceExports = {}
          local endpointSlices = {}

          -- Categorize resources by type
          for _, resource in ipairs(resources) do
            local group = ""
            if resource.apiVersion ~= nil then
              local parts = {}
              for part in string.gmatch(resource.apiVersion, "[^/]+") do
                table.insert(parts, part)
              end
              if #parts > 1 then
                group = parts[1]
              end
            end

            if resource.kind == "ServiceExport" and group == "multicluster.x-k8s.io" then
              local key = resource.metadata.namespace .. "/" .. resource.metadata.name
              serviceExports[key] = resource
            elseif resource.kind == "EndpointSlice" and group == "discovery.k8s.io" then
              table.insert(endpointSlices, resource)
            end
          end

          -- Process EndpointSlices
          for _, endpointSlice in ipairs(endpointSlices) do
            if endpointSlice.metadata.labels ~= nil and
              endpointSlice.metadata.labels["kubernetes.io/service-name"] ~= nil then

              local serviceName = endpointSlice.metadata.labels["kubernetes.io/service-name"]
              local serviceExportKey = endpointSlice.metadata.namespace .. "/" .. serviceName

              -- Check if a corresponding ServiceExport exists
              if serviceExports[serviceExportKey] ~= nil then
                -- Add ServiceExport information to EndpointSlice labels
                if endpointSlice.metadata.labels == nil then
                  endpointSlice.metadata.labels = {}
                end
                endpointSlice.metadata.labels["service-export-name"] = serviceName
                endpointSlice.metadata.labels["service-export-namespace"] = endpointSlice.metadata.namespace
                endpointSlice.metadata.labels["multicluster.kubernetes.io/service-name"] = serviceExports[serviceExportKey].metadata.name

                table.insert(collectedEndpointSlices, endpointSlice)
                hs.message = hs.message .. "Found EndpointSlice for ServiceExport: " .. serviceName .. "\n"
              end
            end
          end

          if #collectedEndpointSlices > 0 then
            hs.resources = collectedEndpointSlices
          end
          return hs
        end
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: EventTrigger
    metadata:
      name: mcs-endpoint-mirror
    spec:
      sourceClusterSelector:
        matchExpressions:
        - key: cluster.clusterset.k8s.io
          operator: NotIn
          values:
          - ""
        - key: clusterset.k8s.io
          operator: In
          values:
          - environ-1
      eventSourceName: mcs-endpoint-mirror
      oneForEvent: true
      syncMode: ContinuousWithDriftDetection
      policyRefs:
      - name: mcs-endpoint-mirror
        namespace: mgmt
        kind: Secret
    ---
    apiVersion: v1
    kind: Secret
    metadata:
      name: mcs-endpoint-mirror
      namespace: mgmt
      annotations:
        projectsveltos.io/instantiate: ok
    type: addons.projectsveltos.io/cluster-profile
    stringData:
      endpointslice.yaml: |
        apiVersion: discovery.k8s.io/v1
        kind: EndpointSlice
        metadata:
          name: derived-{{ index .Resource.metadata.labels "service-export-name" | adler32sum }}-{{ index .Cluster.metadata.labels "cluster.clusterset.k8s.io" }}
          namespace: {{ .Resource.metadata.namespace }}
          labels:
            {{- range $key, $value := .Resource.metadata.labels }}
            {{- if eq $key "kubernetes.io/service-name" }}
            {{ $key }}: derived-{{ $value | adler32sum }}
            {{- else }}
            {{ $key }}: {{ $value }}
            {{- end }}
            {{- end }}
            endpointslice.kubernetes.io/managed-by: sveltos
        addressType: {{ .Resource.addressType }}
        {{- if .Resource.endpoints }}
        endpoints:
        {{- range .Resource.endpoints }}
        - addresses:
          {{- range .addresses }}
          - {{ . }}
          {{- end }}
          {{- if .conditions }}
          conditions:
            ready: {{ .conditions.ready }}
            serving: {{ .conditions.serving }}
            terminating: {{ .conditions.terminating }}
          {{- end }}
        {{- end }}
        {{- end }}
        {{- if .Resource.ports }}
        ports:
        {{- range .Resource.ports }}
        - name: {{ .name }}
          port: {{ .port }}
          protocol: {{ .protocol }}
        {{- end }}
        {{- end }}
    EOF
    ```

---

## Step 4: Configure CoreDNS for Multi-Cluster DNS

To enable DNS resolution for `clusterset.local` domain, CoreDNS needs to be configured with the kubernetes plugin. This configuration is based on [Cilium's MCS-API prerequisites](https://docs.cilium.io/en/latest/network/clustermesh/mcsapi/#prerequisites).

### Update CoreDNS Version

First, ensure CoreDNS is at version 1.12.2 or later which includes multi-cluster capability:

```bash
kubectl -n kube-system set image deployment/coredns coredns=registry.k8s.io/coredns/coredns:v1.12.2
```

### Add RBAC for ServiceImports

CoreDNS needs permissions to read ServiceImports:

```bash
# Create ClusterRole for reading ServiceImports
kubectl create clusterrole coredns-mcsapi \
   --verb=list,watch --resource=serviceimports.multicluster.x-k8s.io

# Bind the role to CoreDNS service account
kubectl create clusterrolebinding coredns-mcsapi \
   --clusterrole=coredns-mcsapi --serviceaccount=kube-system:coredns
```

### Configure CoreDNS Corefile

Update the CoreDNS ConfigMap to add `clusterset.local` zone and enable the multicluster plugin:

```bash
# Update CoreDNS configuration
kubectl get configmap -n kube-system coredns -o yaml | \
   sed -e 's/cluster\.local/cluster.local clusterset.local/g' | \
   sed -E 's/^(.*)kubernetes(.*)\{/\1kubernetes\2{\n\1   multicluster clusterset.local/' | \
   kubectl replace -f-
```

This configuration:

* Adds `clusterset.local` to the DNS zones handled by CoreDNS
* Enables the `multicluster` plugin for the `clusterset.local` zone
* Maintains backward compatibility with existing `cluster.local` resolution

### Apply Configuration

Roll out the CoreDNS deployment to apply the changes:

```bash
kubectl rollout restart deployment -n kube-system coredns
```

### Verification

After configuration, services exported via ServiceExport/ServiceImport will be resolvable at:

* `<service-name>.<namespace>.svc.clusterset.local` - for ClusterSetIP services

---

## Concrete Transformation Examples

### ClusterIP Service Example

#### Source Cluster (cluster-a): Original Resources

```yaml
# Original Service
apiVersion: v1
kind: Service
metadata:
  name: web-service
  namespace: default
spec:
  type: ClusterIP
  selector:
    app: web
  ports:
    - name: http
      port: 80
      targetPort: 8080
---
# ServiceExport
apiVersion: multicluster.x-k8s.io/v1alpha1
kind: ServiceExport
metadata:
  name: web-service
  namespace: default
```

#### Destination Clusters: Generated Resources

```yaml
# Derived Service
apiVersion: v1
kind: Service
metadata:
  name: derived-3d8f2a9c  # adler32sum("web-service")
  namespace: default
  labels:
    multicluster.kubernetes.io/service-name: web-service
    multicluster.kubernetes.io/service-imported: "true"
    app.kubernetes.io/managed-by: sveltos
spec:
  type: ClusterIP
  selector:
    app: web
  ports:
    - name: http
      port: 80
      targetPort: 8080
---
# ServiceImport
apiVersion: multicluster.x-k8s.io/v1alpha1
kind: ServiceImport
metadata:
  name: web-service
  namespace: default
  annotations:
    multicluster.kubernetes.io/derived-service: derived-3d8f2a9c
spec:
  type: ClusterSetIP
  ips: ["10.96.0.120"]
  ports:
    - name: http
      port: 80
      protocol: TCP
---
# EndpointSlice
apiVersion: discovery.k8s.io/v1
kind: EndpointSlice
metadata:
  name: derived-3d8f2a9c-cluster-a
  namespace: default
  labels:
    kubernetes.io/service-name: derived-3d8f2a9c
    multicluster.kubernetes.io/service-name: web-service
    endpointslice.kubernetes.io/managed-by: sveltos
addressType: IPv4
ports:
  - name: http
    port: 80
    protocol: TCP
endpoints:
  - addresses: ["10.0.1.1", "10.0.1.2"]
    conditions:
      ready: true
```

### Headless Service Example

#### Source Cluster: Original Resources

```yaml
# Headless Service
apiVersion: v1
kind: Service
metadata:
  name: stateful-service
  namespace: default
spec:
  clusterIP: None
  selector:
    app: stateful
  ports:
    - name: http
      port: 80
---
# ServiceExport
apiVersion: multicluster.x-k8s.io/v1alpha1
kind: ServiceExport
metadata:
  name: stateful-service
  namespace: default
```

#### Destination Clusters: Generated Resources

```yaml
# Derived Headless Service
apiVersion: v1
kind: Service
metadata:
  name: derived-4b7e3f8a  # adler32sum("stateful-service")
  namespace: default
  labels:
    multicluster.kubernetes.io/service-name: stateful-service
    multicluster.kubernetes.io/service-imported: "true"
    app.kubernetes.io/managed-by: sveltos
spec:
  clusterIP: None
  selector:
    app: stateful
  ports:
    - name: http
      port: 80
---
# ServiceImport
apiVersion: multicluster.x-k8s.io/v1alpha1
kind: ServiceImport
metadata:
  name: stateful-service
  namespace: default
  annotations:
    multicluster.kubernetes.io/derived-service: derived-4b7e3f8a
spec:
  type: Headless
  ports:
    - name: http
      port: 80
      protocol: TCP
---
# EndpointSlice for DNS resolution
apiVersion: discovery.k8s.io/v1
kind: EndpointSlice
metadata:
  name: derived-4b7e3f8a-cluster-a
  namespace: default
  labels:
    kubernetes.io/service-name: derived-4b7e3f8a
    multicluster.kubernetes.io/service-name: stateful-service
    endpointslice.kubernetes.io/managed-by: sveltos
addressType: IPv4
ports:
  - name: http
    port: 80
    protocol: TCP
endpoints:
  - addresses: ["10.0.2.1"]
    conditions:
      ready: true
```

---

## Behavior & Notes

* **Service types**

  * `ClusterIP` / `NodePort` / `LoadBalancer` → derived **ClusterIP** Service + `ServiceImport(type: ClusterSetIP)`.
  * **Headless** (`clusterIP: None`) → derived **Headless** Service + `ServiceImport(type: Headless)` and mirrored **EndpointSlice** data to back DNS.
  * **ExternalName**: not exported (out of scope for this flow).

* **DNS (CoreDNS)**
  DNS configuration is delegated to CoreDNS. The multicluster capability is available in CoreDNS v1.12.2 and later; enable/configure it in your CoreDNS deployment.
  **Note:** If you are not relying on Multi-Cluster DNS names for service discovery, the CoreDNS multicluster capability is **not required**. For headless Services, without Multi-Cluster DNS you will not get cross-cluster A/AAAA/SRV records out of the box.

* **Labels**

  * Both derived Service and mirrored EndpointSlice include `multicluster.kubernetes.io/service-name: <clusterset service>`.
  * EndpointSlice includes `kubernetes.io/service-name: <derived service name>` for kube-proxy.
  * Additional labels from source are preserved (except internal helper labels used during templating).

* **Hashing**

  * Derived names use `adler32sum` of the ServiceExport name: `derived-<hash>`. This produces stable, compact identifiers.
  * EndpointSlice names include cluster identifier: `derived-<hash>-<cluster-id>`.

* **Selector Maintenance**

  * All imported Services maintain their selectors.
  * This enables Pods with matching labels in the importing cluster to be automatically added as service endpoints.

* **Status**

  * Conditions on `ServiceExport` (e.g., invalid types, headless/non-headless conflicts, per-cluster availability) are not set by the snippets above. Implement these via a lightweight controller or an additional Event flow that writes back `status`.

* **ServiceImport IPs field**

  * The `ips` field in `ServiceImport` is **automatically populated** by the second Event flow, copying from the derived Service's `.spec.clusterIPs`.

---

## Result

* Exported Services are **discoverable across clusters** with minimal configuration.
* Consumers resolve via **ServiceImport** (`ClusterSetIP` or **headless** DNS) backed by synchronized **EndpointSlices**.
* The entire pipeline is **event-driven**, declarative.

This pattern accelerates multi-cluster adoption for HA, traffic shaping, and cross-environment integration while keeping the implementation open and extensible.
