---
title: Sveltos Visibility
description: sveltosctl is the command line client for Sveltos. sveltosctl nicely displays add-ons deployed in each Kubernetes cluster by Sveltos.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
authors:
    - Gianluca Mardente
---

## Sveltoctl Visibility

**sveltosctl** nicely displays the add-ons deployed in every Sveltos managed Kubernetes cluster.

### show addons
*show addons* can be used to display a list of Kubernetes add-ons deployed in each clusters by Sveltos.

The displayed information are:

- The CAPI/Sveltos Cluster in the form namespace/name;
- Resource/helm chart information;
- Time resource/helm chart was deployed;
- ClusterProfiles that caused resource/helm chart to be deployed in the cluster.

```
$ sveltosctl show addons
+-------------------------------------+---------------+-----------+----------------+---------+-------------------------------+------------------+
|               CLUSTER               | RESOURCE TYPE | NAMESPACE |      NAME      | VERSION |             TIME              | CLUSTER PROFILE |
+-------------------------------------+---------------+-----------+----------------+---------+-------------------------------+------------------+
| default/sveltos-management-workload | helm chart    | kyverno   | kyverno-latest | v2.5.0  | 2022-09-30 11:48:45 -0700 PDT | clusterprofile1   |
| default/sveltos-management-workload | :Pod          | default   | nginx          | N/A     | 2022-09-30 13:41:05 -0700 PDT | clusterprofile2   |
+-------------------------------------+---------------+-----------+----------------+---------+-------------------------------+------------------+
```

show addons command allows filtering by:

- clusters' namespace
- clusters' name
- ClusterProfile
- resource type (Helm releases only, or Kubernetes resources only)

```
$ sveltosctl show addons --help
Usage:
  sveltosctl show features [options] [--namespace=<name>] [--cluster=<name>] [--clusterprofile=<name>] [--helm-charts] [--resources] [--verbose]

     --namespace=<name>      Show features deployed in clusters in this namespace. If not specified all namespaces are considered.
     --cluster=<name>        Show features deployed in cluster with name. If not specified all cluster names are considered.
     --clusterprofile=<name> Show features deployed because of this clusterprofile. If not specified all clusterprofile names are considered.
     --helm-charts           Show only Helm releases. Cannot be combined with --resources.
     --resources             Show only Kubernetes resources. Cannot be combined with --helm-charts.
```

### show resources

Using Projectsveltos can facilitate the display of information about resources in managed clusters.

Checkout the [observability section](../../../observability/display_resources.md) for more details.

```bash
$ sveltosctl show resources --kind=pod --namespace=nginx
+-----------------------------+---------------+-----------+-----------------------------------+-------------------+
|           CLUSTER           |      GVK      | NAMESPACE |               NAME                |      MESSAGE      |
+-----------------------------+---------------+-----------+-----------------------------------+-------------------+
| default/clusterapi-workload | /v1, Kind=Pod | nginx     | nginx-deployment-85996f8dbd-7tctq | Deployment: nginx |
|                             |               | nginx     | nginx-deployment-85996f8dbd-tz4gd | Deployment: nginx |
| gke/pre-production          |               | nginx     | nginx-deployment-c4f7848dc-6jtwg  | Deployment: nginx |
|                             |               | nginx     | nginx-deployment-c4f7848dc-trllk  | Deployment: nginx |
| gke/production              |               | nginx     | nginx-deployment-676cf9b46d-k84pb | Deployment: nginx |
|                             |               | nginx     | nginx-deployment-676cf9b46d-mmbl4 | Deployment: nginx |
+-----------------------------+---------------+-----------+-----------------------------------+-------------------+
```

### show usage

*show usage* displays below information:

- Which clusters are currently a match for a ClusterProfile;
- For ConfigMap/Secret list of clusters where their content is currently deployed.


Such information is useful to see what clusters would be affected by a change before making such a change.

```
$ sveltosctl show usage
+----------------+--------------------+----------------------------+-------------------------------------+
| RESOURCE KIND  | RESOURCE NAMESPACE |       RESOURCE NAME        |              CLUSTERS               |
+----------------+--------------------+----------------------------+-------------------------------------+
| ClusterProfile |                    | kyverno                    | default/sveltos-management-workload |
| ConfigMap      | default            | kyverno-disallow-gateway   | default/sveltos-management-workload |
+----------------+--------------------+----------------------------+-------------------------------------+
```

### show classifier-labels

*show classifier-labels* displays labels that `Classifier` and `ManagementClusterClassifier` instances are actively managing on each cluster, along with the name of the instance that owns each label.

The displayed information are:

- The CAPI/Sveltos Cluster in the form namespace/name;
- Label key and value;
- The name of the `Classifier` or `ManagementClusterClassifier` instance managing the label;
- The type (`Classifier` or `ManagementClusterClassifier`).

```bash
$ sveltosctl show classifier-labels
+-----------------------------+-------------+------------+-------------------------+----------------------------+
|           CLUSTER           |     KEY     |   VALUE    |      CLASSIFIER/MCC     |           TYPE             |
+-----------------------------+-------------+------------+-------------------------+----------------------------+
| capi-clusters/prod-eu1      | env         | production | tag-production-clusters | ManagementClusterClassifier|
| capi-clusters/prod-eu1      | cost-centre | platform   | tag-production-clusters | ManagementClusterClassifier|
| capi-clusters/staging-eu1   | gatekeeper  | v3-10      | deploy-gatekeeper-3-10  | Classifier                 |
+-----------------------------+-------------+------------+-------------------------+----------------------------+
```

*show classifier-labels* allows filtering by:

- clusters' namespace
- clusters' name

Pass `--warnings` to display only label conflicts, where two instances are competing to own the same label key on the same cluster:

```bash
$ sveltosctl show classifier-labels --warnings
+-----------------------------+------+------------------+------------+----------------------------------------------+
|           CLUSTER           | KEY  |    WANTED BY     |    TYPE    |                   CONFLICT                   |
+-----------------------------+------+------------------+------------+----------------------------------------------+
| capi-clusters/prod-eu1      | env  | other-classifier | Classifier | label already managed by tag-production-...  |
+-----------------------------+------+------------------+------------+----------------------------------------------+
```

### show admin-rbac

*show admin-rbac* can be used to display permissions granted to tenant admins in each managed clusters by the platform admin.

If we have two clusters, a ClusterAPI powered one and a SveltosCluster, both matching label selector
```env=internal``` and we post [RoleRequests](https://raw.githubusercontent.com/projectsveltos/access-manager/main/examples/shared_access.yaml), we get:

```
$ sveltosctl show admin-rbac
+---------------------------------------------+-------+----------------+------------+-----------+----------------+-------+
|                   CLUSTER                   | ADMIN |   NAMESPACE    | API GROUPS | RESOURCES | RESOURCE NAMES | VERBS |
+---------------------------------------------+-------+----------------+------------+-----------+----------------+-------+
| Cluster:default/sveltos-management-workload | eng   | build          | *          | *         | *              | *     |
| Cluster:default/sveltos-management-workload | eng   | ci-cd          | *          | *         | *              | *     |
| Cluster:default/sveltos-management-workload | hr    | human-resource | *          | *         | *              | *     |
| SveltosCluster:gke/prod-cluster             | eng   | build          | *          | *         | *              | *     |
| SveltosCluster:gke/prod-cluster             | eng   | ci-cd          | *          | *         | *              | *     |
| SveltosCluster:gke/prod-cluster             | hr    | human-resource | *          | *         | *              | *     |
+---------------------------------------------+-------+----------------+------------+-----------+----------------+-------+
```
