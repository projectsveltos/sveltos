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
    - Gianluca Mardente
---

# Introduction to the Sveltos Grafana Dashboard

The Sveltos Dashboard is designed to help users monitor key operational metrics, and the status of their sveltosclusters in real time. Grafana helps users visualize this data effectively, so they can make more efficient and informed operational decisions. 

## Getting Started

Once Prometheus and Grafana have been deployed on your sveltosclusters, and the Prometheus data source has been added to Grafana, import the configured Grafana dashboard from :

```
https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/SveltosGrafanaDashboard.json.
```

Confirm that all metrics are linked to their corresponding panels. The dashboard should automatically detect data connections from Prometheus.

Refresh to begin plotting tracked metrics. Customize the dashboard to maximize utility -- by updating thresholds, adding/removing/editing panels, and transforming metrics tracked.

!!! note 
    Some metrics only appear on Grafana when their value is non-zero, e.g. ``projectsveltos_reconcile_operations_total``, and ``projectsveltos_total_drifts``. As long as Prometheus and Grafana have been configured correctly, this should not be a problem.

Detailed descriptions of the panels available on the dashboard, and the tracked metrics, are listed below.

## Available Metrics

Sveltos lets users track and visualize a number of key operational metrics, which include:

* ``projectsveltos_cluster_connectivity_status``: Set to `0` for a connected cluster and `1` for a disconnected cluster.

* ``projectsveltos_kubernetes_version_info:`` Stores Kubernetes version deployed on sveltosclusters.

* ``projectsveltos_program_charts_time_seconds_count:`` Stores the number of Helm charts deployed.

* ``projectsveltos_program_charts_time_seconds_bucket:`` Stores the number of Helm charts deployed within buckets(s)
 <!-- [0.3, 0.6, 0.9, 1.2, 1.5, 2, 3, 5, 10, 30, 60] -->
* ``projectsveltos_program_resources_time_seconds_count:`` Stores the number of resources deployed.

* ``projectsveltos_program_resources_time_seconds_bucket:`` Stores the number of resources deployed within buckets(s)
* ``projectsveltos_reconcile_operations_total:`` Stores the total number of reconciliations that occur.

* ``projectsveltos_total_drifts:`` Stores the total number of drifts that occur.

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


