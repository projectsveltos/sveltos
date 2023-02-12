---
title: Visibility
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

[sveltosctl](https://github.com/projectsveltos/sveltosctl "Sveltos CLI") is the command line client for Sveltos. sveltosctl nicely displays add-ons deployed in each Kubernetes cluster by Sveltos.

### show features
*show features* can be used to display list of resources/helm releases deployed in each clusters by Sveltos. 
Displayed information contains:

- the CAPI Cluster in the form namespace/name;
- resource/helm chart information;
- time resource/helm chart was deployed;
- ClusterProfiles that caused resource/helm chart to be deployed in the cluster.

```
./bin/sveltosctl show features
+-------------------------------------+---------------+-----------+----------------+---------+-------------------------------+------------------+
|               CLUSTER               | RESOURCE TYPE | NAMESPACE |      NAME      | VERSION |             TIME              | CLUSTER PROFILE |
+-------------------------------------+---------------+-----------+----------------+---------+-------------------------------+------------------+
| default/sveltos-management-workload | helm chart    | kyverno   | kyverno-latest | v2.5.0  | 2022-09-30 11:48:45 -0700 PDT | clusterprofile1   |
| default/sveltos-management-workload | :Pod          | default   | nginx          | N/A     | 2022-09-30 13:41:05 -0700 PDT | clusterprofile2   |
+-------------------------------------+---------------+-----------+----------------+---------+-------------------------------+------------------+
```

show features command allows filtering by:

- clusters' namespace
- clusters' name
- ClusterProfile

```
./bin/sveltosctl show features --help
Usage:
  sveltosctl show features [options] [--namespace=<name>] [--cluster=<name>] [--clusterprofile=<name>] [--verbose]

     --namespace=<name>      Show features deployed in clusters in this namespace. If not specified all namespaces are considered.
     --cluster=<name>        Show features deployed in cluster with name. If not specified all cluster names are considered.
     --clusterprofile=<name> Show features deployed because of this clusterprofile. If not specified all clusterprofile names are considered.
```

### show usage

*show usage* displays following information:

- which clusters are currently a match for a ClusterProfile;
- for ConfigMap/Secret list of clusters where their content is currently deployed.


Such information is useful to see what clusters would be affected by a change before making such a change.

```
./bin/sveltosctl show usage 
+----------------+--------------------+----------------------------+-------------------------------------+
| RESOURCE KIND  | RESOURCE NAMESPACE |       RESOURCE NAME        |              CLUSTERS               |
+----------------+--------------------+----------------------------+-------------------------------------+
| ClusterProfile |                    | kyverno                    | default/sveltos-management-workload |
| ConfigMap      | default            | kyverno-disallow-gateway   | default/sveltos-management-workload |
+----------------+--------------------+----------------------------+-------------------------------------+
```

### show admin-rbac

*show admin-rbac* can be used to display permissions granted to tenant admins in each managed clusters by platform admin.

If we have two clusters, a ClusterAPI powered one and a SveltosCluster, both matching label selector
```env=internal``` and we post [RoleRequests](https://raw.githubusercontent.com/projectsveltos/access-manager/main/examples/shared_access.yaml), we get:

```
./bin/sveltosctl show admin-rbac       
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