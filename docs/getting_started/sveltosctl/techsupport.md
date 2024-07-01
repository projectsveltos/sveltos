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

## Introduction to Techsupport

Techsupports is a Sveltos feature which allows both the platform admin and the tenant admin to collect tech supports (pod logs and resources) from managed Kubernetes cluster.

To do that, add the below label to the Techsupport instance created by the tenant admin.

```
projectsveltos.io/admin-name: <admin>
```

Sveltos will make sure the tenant admin collects what it has been [authorized to by platform admin](../../features/multi-tenancy-sharing-cluster.md).


## Techsupport CRD

Techsupport CRD is used to configure Sveltos to periodically collect tech supports from managed Kubernetes clusters.

!!! example "Example 1"
    ```yaml
    cat > techsupport.yaml <<EOF
    ---
    apiVersion: utils.projectsveltos.io/v1beta1
    kind: Techsupport
    metadata:
      name: hourly
    spec:
      clusterSelector:
        matchLabels:
          env: fv
      schedule: "00 * * * *"
      storage: /collection
      logs:
      - namespace: kube-system
        sinceSeconds: 600
      resources:
      - group: "apps"
        version: v1
        kind: Deployment
      - group: ""
        version: v1
        kind: Secret
    EOF
    ```

The above YAML Techsupport definition instructs Sveltos to:

1. Consider any managed Kubernetes cluster matching the __clusterSelector__ field;
2. Collect logs from all pods in the kube-system namespace. The __sinceSeconds__ field specifies how many logs need to be collected. In this example the last 600 seconds for each pod;
3. Collect all deployments and all secrets.

The __Techsupport__ CRD allows filtering pods and resources using the label and the field selectors.

!!! example "Example 2"
    ```yaml
    cat > techsupport_advanced.yaml <<EOF
    ---
    apiVersion: utils.projectsveltos.io/v1beta1
    kind: Techsupport
    metadata:
      name: hourly
    spec:
      clusterSelector:
        matchLabels:
          env: fv
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
      - group: "apps"
        version: v1
        kind: Deployment
        labelFilters:
        - key: env
          operation: Equal
          value: production
        - key: department
          operation: Different
          value: eng
        namespace: default
      - group: ""
        version: v1
        kind: Service
        labelFilters:
        - key: env
          operation: Equal
          value: production
        - key: department
          operation: Different
          value: eng
        namespace: default
    EOF
    ```

- *schedule* field specifies when a tech-support needs to be collected. It is [Cron format](https://en.wikipedia.org/wiki/Cron).

- *storage* field represents a directory where snapshots will be stored. It must be an existing directory (on a PersistentVolume mounted by sveltosctl)

- *logs* field instructs Sveltos which logs to collect. In the above example, all the logs in *default* namespace with the label set to *env=production* and the *department!=eng* will be collected. Additionally, only the last *600* seconds of the log will be collected.

- *resources* field is a list of Kubernetes resources Sveltos will collect logs. In the above example, Services and Deployments from the default namespace with the labels matching  *env=production* and *department!=eng* will be collected.


For more information, refer to the [CRD](https://github.com/projectsveltos/sveltosctl/blob/main/api/v1beta1/techsupport_types.go).

## List techsupports

[sveltosctl](https://github.com/projectsveltos/sveltosctl "Sveltos CLI")  can be used to display collected techsupports.

```
$ sveltosctl techsupport list 
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

then two subdirectory:

1. ```logs```
2. ```resources```

For instance:

```
$ ls /techsupport/hourly/2023-02-22\:17\:39\:00/Capi\:default sveltos-management-workload/
logs  resources
```

### Logs

The ```logs``` directory contains one subdirectory per namespace, which contains logs collected for the pods in the defined namespace.

```
$ ls -la /techsupport/hourly/2023-02-22\:17\:39\:00/Capi\:default/sveltos-management-workload/logs/kube-system/
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

The ```resources``` directory contains one subdirectory per namespace.
In each subirectory, all the collected resources are organized per Kind.

```
$ ls -la /techsupport/hourly/2023-02-22\:17\:39\:00/Capi\:default/sveltos-management-workload/resources/
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

[Sveltosctl](https://github.com/projectsveltos/sveltosctl "Sveltos CLI") when running as a Pod in the management cluster, can be configured to collect tech-support from managed clusters with the [Snapshot](../sveltosctl/snapshot.md) CRD definition.
