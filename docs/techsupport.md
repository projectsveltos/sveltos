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

```techsupport/<techsupport name>/<collection time>/<cluster namespace>/<cluster name>/```

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
total 16
drwxr-xr-x 2 root root 4096 Feb 23 01:39 .
drwxr-xr-x 3 root root 4096 Feb 23 01:39 ..
-rw-r--r-- 1 root root    0 Feb 23 01:39 calico-kube-controllers-58dbc876ff-xcszf-calico-kube-controllers
-rw-r--r-- 1 root root  288 Feb 23 01:39 calico-node-2wdjt-calico-node
-rw-r--r-- 1 root root  286 Feb 23 01:39 calico-node-r24r6-calico-node
-rw-r--r-- 1 root root    0 Feb 23 01:39 coredns-565d847f94-5b86m-coredns
-rw-r--r-- 1 root root    0 Feb 23 01:39 coredns-565d847f94-dmhwt-coredns
-rw-r--r-- 1 root root    0 Feb 23 01:39 etcd-sveltos-management-workload-n2m8r-sgtlc-etcd
-rw-r--r-- 1 root root    0 Feb 23 01:39 kube-apiserver-sveltos-management-workload-n2m8r-sgtlc-kube-apiserver
-rw-r--r-- 1 root root    0 Feb 23 01:39 kube-controller-manager-sveltos-management-workload-n2m8r-sgtlc-kube-controller-manager
-rw-r--r-- 1 root root    0 Feb 23 01:39 kube-proxy-d8dtv-kube-proxy
-rw-r--r-- 1 root root    0 Feb 23 01:39 kube-proxy-ppxmr-kube-proxy
-rw-r--r-- 1 root root    0 Feb 23 01:39 kube-scheduler-sveltos-management-workload-n2m8r-sgtlc-kube-scheduler
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