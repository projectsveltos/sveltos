---
title: Techsupport
description: Techsupport allows an administrator to collect techsupports, both logs and resources, from managed Kubernetes clusters.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
authors:
    - Gianluca Mardente
---
Techsupports is a Sveltos feature which allows both platform admin and tenant admin to collect tech supports (pod logs and resources) from managed Kubernetes cluster.

If following label is set on Techsupport instance created by tenant admin

```
projectsveltos.io/admin-name: <admin>
```

Sveltos will make sure tenant admin collects what it has been [authorized to by platform admin](multi-tenancy.md).


## Techsupport CRD

Techsupport CRD is used to configure Sveltos to periodically collect tech supports from managed Kubernetes clusters. Here is a quick example. 

```yaml
apiVersion: utils.projectsveltos.io/v1alpha1
kind: Techsupport
metadata:
  name: hourly
spec:
  clusterSelector: env=fv
  schedule: "00 * * * *"
  storage: /collection
  logs:
  - namespace: kube-system
    sinceSeconds: 600
  resources:
  - group: ""
    version: v1
    kind: Deployment
  - group: ""
    version: v1
    kind: Secret
```

Above Techsupport instance is instructing Sveltos to:

1. consider any managed Kubernetes cluster matching the __clusterSelector__ field;
2. collect logs from all pods in the kube-system namespace. The __sinceSeconds__ field specifies how much logs need to be collected. In this example the last 600 seconds for each pod;
3. collect all deployments and all secrets.

__Techsupport__ CRD allows filtering pods and resources using label and field selectors.

A more complex example:

```yaml
apiVersion: utils.projectsveltos.io/v1alpha1
kind: Techsupport
metadata:
  name: hourly
spec:
  clusterSelector: env=fv
  schedule: "00 * * * *"
  storage: /collection
  logs:
  - labelFilters:
    - key: env
      operation: Equal
      value: production
    - key: department
      operation: Different
      value: eng
    namespace: default
    sinceSeconds: 600
  resources:
  - group: ""
    kind: Deployment
    labelFilters:
    - key: env
      operation: Equal
      value: production
    - key: department
      operation: Different
      value: eng
    namespace: default
    version: v1
  - group: ""
    kind: Service
    labelFilters:
    - key: env
      operation: Equal
      value: production
    - key: department
      operation: Different
      value: eng
    namespace: default
```

Please refer to [CRD](https://github.com/projectsveltos/sveltosctl/blob/main/api/v1alpha1/techsupport_types.go) for more information.

## List techsupports

[sveltosctl](https://github.com/projectsveltos/sveltosctl "Sveltos CLI")  can be used to display collected techsupports.

```
./sveltosctl techsupport list 
+--------------------+---------------------+
| TECHSUPPORT POLICY |        DATE         |
+--------------------+---------------------+
| hourly             | 2023-02-22:16:39:00 |
| hourly             | 2023-02-22:17:39:00 |
+--------------------+---------------------+
```

When techsupport is collected, Sveltos stores using following format:

```
techsupport/
  <techsupport name>/
    <collection time>/
      <cluster namespace>/
        <cluster name>/
```

then two subdirectoris:

1. ```logs```
2. ```resources```

For instance:

```
root@sveltos-management-worker:/# ls /techsupport/hourly/2023-02-22\:17\:39\:00/Capi\:default/sveltos-management-workload/
logs  resources
```

### Logs

The ```logs``` directory then contains one subdirectory per namespace, which then contains logs collected for the pods in that namespace.

```
root@sveltos-management-worker:/# ls -la /techsupport/hourly/2023-02-22\:17\:39\:00/Capi\:default/sveltos-management-workload/logs/kube-system/
total 412
drwxr-xr-x 2 root root   4096 Feb 23 01:39 .
drwxr-xr-x 3 root root   4096 Feb 23 01:39 ..
-rw-r--r-- 1 root root   5695 Feb 23 01:39 calico-kube-controllers-58dbc876ff-b8ssz-calico-kube-controllers
-rw-r--r-- 1 root root 145743 Feb 23 01:39 calico-node-4f5p2-calico-node
-rw-r--r-- 1 root root 109267 Feb 23 01:39 calico-node-9tzjc-calico-node
-rw-r--r-- 1 root root    232 Feb 23 01:39 coredns-565d847f94-mn4v2-coredns
-rw-r--r-- 1 root root    232 Feb 23 01:39 coredns-565d847f94-xxv99-coredns
-rw-r--r-- 1 root root  53077 Feb 23 01:39 etcd-sveltos-management-workload-mwptj-skgjk-etcd
-rw-r--r-- 1 root root  27622 Feb 23 01:39 kube-apiserver-sveltos-management-workload-mwptj-skgjk-kube-apiserver
-rw-r--r-- 1 root root  29220 Feb 23 01:39 kube-controller-manager-sveltos-management-workload-mwptj-skgjk-kube-controller-manager
-rw-r--r-- 1 root root   2230 Feb 23 01:39 kube-proxy-nc44r-kube-proxy
-rw-r--r-- 1 root root   2230 Feb 23 01:39 kube-proxy-zzh7j-kube-proxy
-rw-r--r-- 1 root root  15368 Feb 23 01:39 kube-scheduler-sveltos-management-workload-mwptj-skgjk-kube-scheduler
```

### Resources 

The ```resources``` directory then contains one subdirectory per namespace.
In each namespace subirectory then all collected resources from that namespace organized per Kind.

```
root@sveltos-management-worker:/# ls -la /techsupport/hourly/2023-02-22\:17\:39\:00/Capi\:default/sveltos-management-workload/resources/
total 28
drwxr-xr-x 7 root root 4096 Feb 23 01:39 .
drwxr-xr-x 4 root root 4096 Feb 23 01:39 ..
drwxr-xr-x 3 root root 4096 Feb 23 01:39 default
drwxr-xr-x 3 root root 4096 Feb 23 01:39 kube-system
drwxr-xr-x 3 root root 4096 Feb 23 01:39 kyverno
drwxr-xr-x 3 root root 4096 Feb 23 01:39 projectsveltos
drwxr-xr-x 3 root root 4096 Feb 23 01:39 spark
root@sveltos-management-worker:/# ls -la /techsupport/hourly/2023-02-22\:17\:39\:00/Capi\:default/sveltos-management-workload/resources/kyverno/
total 12
drwxr-xr-x 3 root root 4096 Feb 23 01:39 .
drwxr-xr-x 7 root root 4096 Feb 23 01:39 ..
drwxr-xr-x 2 root root 4096 Feb 23 01:39 Service
root@sveltos-management-worker:/# ls -la /techsupport/hourly/2023-02-22\:17\:39\:00/Capi\:default/sveltos-management-workload/resources/kyverno/Service/
total 16
drwxr-xr-x 2 root root 4096 Feb 23 01:39 .
drwxr-xr-x 3 root root 4096 Feb 23 01:39 ..
-rw-r--r-- 1 root root 1958 Feb 23 01:39 kyverno-latest-svc-metrics.yaml
-rw-r--r-- 1 root root 1946 Feb 23 01:39 kyverno-latest-svc.yaml
```
