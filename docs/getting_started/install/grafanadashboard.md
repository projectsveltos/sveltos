---
title: How to install Sveltos Grafana dashboard
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative cluster APIs. 
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
    - Grafana
    - Dashboard
authors:
    - Medha Kumar
---

# Introduction to the Sveltos Grafana Dashboard

The Sveltos Dashboard is designed to help users monitor key operational metrics and the status of their sveltosclusters in real-time. Grafana helps users visualize this data effectively, so they can make more efficient and informed operational decisions. 

![dashboard](../../assets/dashboard.png)


## Getting Started

With the latest Sveltos release, users can take full advantage of the Sveltos Grafana dashboard. Before we start using the capabilities, ensure [Grafana](https://artifacthub.io/packages/helm/grafana/grafana) and [Prometheus](https://artifacthub.io/packages/helm/prometheus-community/prometheus) are deployed on the **Sveltos management** cluster.

To allow Prometheus to collect metrics from the **Sveltos management** cluster, perform the below if Sveltos was installed using the Helm chart.

### Helm Chart

```bash
$ helm upgrade <your release name> projectsveltos/projectsveltos -n projectsveltos --set prometheus.enabled=true
```

Once Grafana and Prometheus are available, proceed by adding the [Prometheus data source](https://grafana.com/docs/grafana/latest/datasources/prometheus/configure-prometheus-data-source/) to Grafana and then **import** the below Grafana dashboard.

```bash
https://raw.githubusercontent.com/projectsveltos/sveltos/main/docs/assets/sveltosgrafanadashboard.json
```

!!! note
    Depending on the Grafana/Prometheus installation, identify the `serviceMonitorSelector` label of the **Prometheus** instance and import it to the Sveltos `servicemonitor` resources as a label. Check out the example below.

    ```bash
    $ kubectl get servicemonitor -n projectsveltos
    $ kubectl patch servicemonitor addon-controller -n projectsveltos -p '{"metadata":{"labels":{"prometheus":"example-label"}}}' --type=merge
    ```

Confirm that all metrics are linked to their corresponding panels. The dashboard should automatically detect data connections from Prometheus.

Refresh to begin plotting tracked metrics. Customize the dashboard to maximize utility -- by updating thresholds, adding/removing/editing panels, and transforming metrics tracked.

!!! note 
    Some metrics only appear on Grafana when their value is non-zero, e.g. ``projectsveltos_reconcile_operations_total``, and ``projectsveltos_total_drifts``. As long as Prometheus and Grafana have been configured correctly, this should not be a problem.

Detailed descriptions of the panels available on the dashboard, and the tracked metrics, are listed below.

## Available Metrics

Sveltos lets users track and visualize a number of key operational metrics, which include:

* ``projectsveltos_cluster_connectivity_status``: Gauge indicating the connectivity status of each cluster, where `0` means healthy and `1` means disconnected.

* ``projectsveltos_kubernetes_version_info:`` Gauge providing the Kubernetes version (major.minor.patch) of each cluster.

* ``projectsveltos_program_charts_time_seconds_count:`` Counter of the total number of Helm charts deployed.

* ``projectsveltos_program_charts_time_seconds_bucket:`` Histogram of the durations taken to deploy Helm charts on workload clusters.
 <!-- [0.3, 0.6, 0.9, 1.2, 1.5, 2, 3, 5, 10, 30, 60] -->
* ``projectsveltos_program_resources_time_seconds_count:`` Counter of the total number of resources deployed.

* ``projectsveltos_program_resources_time_seconds_bucket:`` Histogram of the durations taken to deploy resources on workload clusters

* ``projectsveltos_reconcile_operations_total:`` Counter of the total number of reconcile operations performed for Helm charts, Resources, and Kustomizations across clusters.

* ``projectsveltos_total_drifts:`` Counter of the total number of configuration drifts detected in clusters, categorized by cluster and feature.

* Per-Cluster `program_resources_time_seconds` Histograms: Histograms (per cluster) of durations taken to deploy resources, indexed by cluster information.

* Per-Cluster `program_charts_time_seconds` Histograms: Histograms (per cluster) of durations taken to deploy Helm charts, indexed by cluster information.

## Dashboard Panels

### 1. Cluster Connectivity Status 
- **Type**: Gauge
- **Purpose**: Displays the connectivity status of each Kubernetes cluster managed by Sveltos.
- **Query Used**: ``projectsveltos_cluster_connectivity_status``
- **Interpretation**: A “Healthy" cluster is one that is connected ( projectsveltos_cluster_connectivity_status: 0) and depicted in green. A "Disconnected" cluster (projectsveltos_cluster_connectivity_status: 1) is shown in red, to help users rapidly identify and address connectivity issues. 

### 2. Cluster Kubernetes Version
- **Type**: Table
- **Purpose**: Lists the Kubernetes version deployed in each sveltoscluster.
- **Query Used**: ``projectsveltos_kubernetes_version_info``
- **Interpretation**: The table displays clusters with their respective Kubernetes versions, to help users identify clusters in need of updates, and ensure compatibility everywhere.

### 3. Total Helm Charts Deployments
- **Type**: Stat
- **Purpose**: Counts the number of Helm chart deployments.
- **Query Used**: ``projectsveltos_program_charts_time_seconds_count``
- **Interpretation**: Displays the number of Helm charts deployed across all sveltosclusters. This helps users assess the workload managed by Sveltos, track deployment activity, correlate any change in application performance with deployments, and optimize deployment strategies accordingly.

### 4. Total Resources Deployments
- **Type**: Stat
- **Purpose**: Counts the number of resource deployments.
- **Query Used**: ``projectsveltos_program_resources_time_seconds_count``
- **Interpretation**: Displays the total count of resources deployed across all sveltosclusters. This helps users assess the workload managed by Sveltos, track deployment activity, correlate any change in application performance with deployments, and optimize deployment strategies accordingly.


### 5. Time to Deploy Helm Charts in a Profile
- **Type**: Bar Chart
- **Purpose**: Depicts the time required for deploying Helm Charts, by visualizing the 50th and 90th percentile of deployment times.
- **Queries Used**:  
``histogram_quantile(0.90, projectsveltos_program_charts_time_seconds_bucket)`` 
``histogram_quantile(0.50, projectsveltos_program_charts_time_seconds_bucket)``
- **Interpretation**: Provides deeper insights into the deployment times required by Helm Charts. By plotting both the 50th and the 90th percentile, this chart intends to help users gauge performance consistency and distribution, and update their deployment strategies accordingly.

### 6. Time to Deploy Resources in a Profile
- **Type**: Bar Chart
- **Purpose**: Depicts the time required for deploying Resources, by visualizing the 50th and 90th percentile of deployment times.
- **Queries Used**:  
``histogram_quantile(0.90, projectsveltos_program_resources_time_seconds_bucket)``  
``histogram_quantile(0.50, projectsveltos_program_resources_time_seconds_bucket)``
- **Interpretation**: Provides deeper insights into the resource deployment times. By plotting both the 50th and the 90th percentile, this chart intends to help users gauge performance consistency and distribution, and update their deployment strategies accordingly.

### 7.Time to Deploy Helm Charts in a Profile - Histogram
- **Type**: Bar Gauge
- **Purpose**: Provides a histogram view of deployment times for Helm charts.
- **Query Used**: ``projectsveltos_program_charts_time_seconds_bucket``
- **Interpretation**: Captures the distribution of deployment times for Helm charts, and allows users to track and address long-tail latencies.

### 8. Time to Deploy Resources in a Profile - Histogram
- **Type**: Bar Gauge
- **Purpose**: Offers a histogram vieew of resource deployment times.
- **Query Used**: ``projectsveltos_program_resources_time_seconds_bucket``
- **Interpretation**: Captures the distribution of deployment times for resources, and allows users to track and address long-tail latencies.

### 9. Deploy Helm Charts in a Profile - Latency Heatmap
- **Type**: Heatmap
- **Purpose**: Provides a heatmap of Helm chart deployment latencies
- **Query Used**: 
``	  
	sum(rate(projectsveltos_program_charts_time_seconds_bucket[5m]))
``
- **Interpretation**: Highlights the frequency and duration of Helm chart deployment latencies to help users identify patterns and optimize deployment management.

### 10. Deploy Resources in a Profile - Latency Heatmap
- **Type**: Heatmap
- **Purpose**: Provides a heatmap of Resource deployment latencies
- **Query Used**: 
``
sum(rate(projectsveltos_program_resources_time_seconds_bucket[5m]))
``
- **Interpretation**: Highlights the frequency and duration of resource deployment latencies to help users identify patterns and optimize deployment management.

### 11. Reconciliation Operations
- **Type**: Time Series
- **Purpose**: Shows the number of reconciliation operations performed, categorized by cluster (type, namespace, name) and feature.
- **Query Used**: ``projectsveltos_reconcile_operations_total``
- **Interpretation**: Helps users monitor reconciliation processes triggered by Sveltos across clusters, to ensure operational stability.

### 12. Drifts
- **Type**: Time Series
- **Purpose**: Tracks and displays drifts, categorized by cluster (type, namespace, name) and feature.
- **Query Used**: ``projectsveltos_total_drifts``
- **Interpretation**: Allows users to monitor configuration drifts, crucial for maintaining consistency and compliance across sveltosclusters, so they may detect and rectify discrepancies in workload clusters.


