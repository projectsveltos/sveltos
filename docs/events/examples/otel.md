---
title: Example - OpenTelemetry Collector data to Splunk
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative APIs to deploy Kubernetes add-ons across multiple clusters.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
    - Sveltos
    - Event Driven
    - Generators
    - Secrets Example
authors:
    - Eleni Grosdouli
---

## Introduction

The example demonstrates how the Sveltos Event Framework, combined with dynamic templating, allows us to collect pod metrics and logs from dedicated Kubernetes namespaces. The data is then securely forwarded to a Splunk instance using the HTTP Event Collector (HEC).

## Scenario

An `EventSource` is configured to detect namespaces within different Sveltos **managed** clusters that do **not** have the `otel-exempt: true` label set and whose names are **not** present in a predefined `ignore_list = {"kube-system", "another", "more", "etc"}`. When such a namespace is detected, Sveltos triggers an Event. The `EventTrigger` creates a `ConfigMap` containing the necessary OTEL configuration details within the `projectsveltos` namespace of the **management** cluster. This approach automates the setup of OTEL for relevant namespaces. Let's dive into the details.

### EventSource

To define the logic based on the use case, we used Lua. This is how the `EventSource` resource looks. More information about Lua can be found [here](https://projectsveltos.github.io/sveltos/main/template/lua/).

!!! Example "EventSource namespace-watcher"
    ```yaml
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: EventSource
    metadata:
      name: namespace-watcher
    spec:
      collectResources: false
      resourceSelectors:
      - group: ""
        version: "v1"
        kind: "Namespace"
        evaluate: |
          function isLabelInExcludedList(current_value)
            local ignore_list = {"kube-system", "another", "more", "etc"}

            for _, value in ipairs(ignore_list) do
              if current_value == value then
                return true
              end
            end
            return false
          end

          function evaluate()
            hs = {}
            hs.matching = true
            hs.message = ""
            if obj.metadata.labels ~= nil then
              for key, value in pairs(obj.metadata.labels) do
                -- exclude all namaspaces with label otel-exempt: true
                if key == "otel-exempt" then
                  if value == "true" then
                    hs.matching = false
                    break
                  end
                elseif key == "kubernetes.io/metadata.name" then
                  -- exclude namespaces with certain names. List is defined in the function
                  if isLabelInExcludedList(value) then
                    hs.matching = false
                    break
                  end
                end
              end
            end
            return hs
          end
    ```

### EventTrigger

Once we have a matching namespace, the `EventTrigger` performs the following actions.

- On the **management** cluster, create a `ConfigMap` for every **managed** cluster matching the `sourceClusterSelector`
- The `ConfigMap` has the name format `{{ .Cluster.metadata.namespace }}-{{ .Cluster.metadata.name }}-cluster-receiver-value`, and is located in the `projectsveltos` namespace
- The `ConfigMap` contains the necessary OTEL Collector details and Sveltos ensure the resource is kept up to date

!!! Example "EventTrigger otel"

    ```yaml
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: EventTrigger
    metadata:
      name: otel
    spec:
      sourceClusterSelector:
        matchExpressions:
          - {key: env, operator: In, values: ["dev", "development", "test", "testing"]}
          - {key: exempt, operator: NotIn, values: ["true"]}
      eventSourceName: namespace-watcher
      destinationCluster:
        name: mgmt
        namespace: mgmt
        kind: SveltosCluster
        apiVersion: lib.projectsveltos.io/v1beta1
      oneForEvent: false
      configMapGenerator:
      - name: cluster-receiver-value
        namespace: default
        nameFormat: "{{ .Cluster.metadata.namespace }}-{{ .Cluster.metadata.name }}-cluster-receiver-value"
    ```

!!!note
    For the example to work, the `ConfigMap` named _cluster-receiver-value_ needs to be deployed to the **management** cluster.

### ConfigMap

!!! Example "ConfigMap cluster-receiver-value"

    ```yaml
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: cluster-receiver-value
      namespace: default
      annotations:
        projectsveltos.io/instantiate: ok
    data:
      cluster-receiver-value.yaml: |
          clusterReceiver:
            resources:
              limits:
                cpu: 1000m
                memory: 2Gi

            extraEnvs:
              {{ range .MatchingResources }}
              - name: "SPLUNK_{{ .Name }}_HEC_TOKEN"
                valueFrom:
                  secretKeyRef:
                    name: "{{ .Name }}-access-token"
                    key: splunk_platform_hec_token
              {{ end }}

            config:
              receivers:
                prometheus:
                  config:
                    scrape_configs:
                      - job_name: "kubernetes-pods"
                        kubernetes_sd_configs:
                          - role: pod
                        relabel_configs:
                          - action: labelmap
                            regex: __meta_kubernetes_pod_label_(.+)
                          - source_labels: [__meta_kubernetes_namespace]
                            action: replace
                            target_label: namespace
                          - source_labels: [__meta_kubernetes_pod_name]
                            action: replace
                            target_label: pod

              exporters:
                {{ range .MatchingResources }}
                splunk_hec/{{ .Name }}:
                  index: "{{ .Name }}"
                  source: kubernetes
                  splunk_app_name: splunk-otel-collector
                  endpoint: https://example.splunkcloud.com:443/services/collector/event
                  token: "$SPLUNK_{{ .Name }}_HEC_TOKEN"
                {{ end }}

              connectors:
                routing/logs:
                  default_pipelines: [logs/other]
                  table:
                    {{ range .MatchingResources }}
                    - context: resource
                      condition: attributes["k8s.namespace.name"] == {{ .Name }}
                      pipelines: "[logs/{{ .Name }}]"
                    {{ end }}

              service:
                pipelines:
                  metrics:
                    receivers:
                      - k8s_cluster
                      - prometheus
                  {{ range .MatchingResources }}
                  logs/{{ .Name }}:
                    receivers:
                      - routingconnector/logs
                    exporters:
                      - splunk_hec/{{ .Name }}
                  {{ end }}
    ```

Every time we have a matching condition, Sveltos can dynamically update the _cluster-receiver-value_ `ConfigMap` with information found in the **managed** cluster. The new `ConfigMap` will be located in the `projectsveltos` namespace with the name `{{ .Cluster.metadata.namespace }}-{{ .Cluster.metadata.name }}-cluster-receiver-value`.

## Conclusion

The demonstrated approach shows how Sveltos effectively automates the dynamic configuration of OTEL across a multi-cluster environment. By identifying and provisioning OTEL details for the namespace of interest, it smooths the observability setup, ensuring efficient and scalable data collection to Splunk. This method reduces manual overhead for managing monitoring configurations.
