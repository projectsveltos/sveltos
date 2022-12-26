Today, it's very common for organizations to run and manage multiple Kubernetes clusters across different cloud providers or infrastructures. With an increasing number of clusters, consistently managing Kubernetes addons is not an easy task.

[Sveltos](https://github.com/projectsveltos) is a lightweight application designed to manage hundreds of clusters. It does so by providing declarative APIs to deploy Kubernetes addons across set of clusters. 

Sveltos focuses not only on the ability to scale the number of clusters it can manage, but also to give visibility to exactly which addons are installed on each cluster.

## Features List
1. Kubernetes [addon distribution](addons.md) across multiple clusters;
2. [Templates](template.md) instantiated reading values from management cluster;
3. Kubernetes [cluster classification](labels_management.md) and automatic label management based on cluster runtime states;
4. [Snapshot and Rollback](snapshot.md).

## Core Concepts

Sveltos is a set of Kubernetes custom resource definitions (CRDs) and controllers to deploy kubernetes addons across multiple Kubernetes clusters.

1. [ClusterProfile CRD](configuration.md#deploying-addons) is the CRD used to instruct Sveltos on which addons to deploy on a set of clusters;
2. [Sveltos manager](configuration.md#sveltos-manager) is a controller running in the management cluster. It watches for *ClusterProfile* instances and *cluster* instances (both CAPI Cluster and SveltosCluster). It orchestrates Kubernetes addon deployments: when a cluster is a match for a ClusterProfile instance, all addons listed in the ClusterProfile instance are deployed in the cluster.
3. [Classifier CRD](configuration.md#managing-labels) is the CRD used to instructs Sveltos on how to classify a cluster;
4. [Classifier](configuration.md#classifier) is a controller running in the management cluster. Its counterpart, *Classifier Agent* is a controller running in each managed cluster. Classifier distributes Classifier CRD instances to any managed cluster. Classifier Agent watches for cluster runtime state (kubernetes version and/or resources deployed) and Classifier CRD instances. It reports back to management cluster whether a managed cluster is a match or not for each Classifier instance;
5. [Sveltosctl](https://github.com/projectsveltos/sveltosctl) is the sveltos CLI; 
6. [Snapshot CRD](configuration.md#snapshot) is the CRD used to instruct Sveltos on collecting configuration snapshots;
7. [SveltosCluster](register-cluster.md#register-cluster) is the CRD used to register a cluster with Sveltos (only non CAPI powered cluster needs to be manually registered with Sveltos).   