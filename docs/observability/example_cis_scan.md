---
title: Notifications - Projectsveltos
description: Use Sveltos to deploy Kube-Bench to all managed clusters
tags:
    - Kubernetes
    - CIS Kubernetes Benchmark
authors:
    - Gianluca Mardente
---

Running security scans on managed Kubernetes clusters is crucial to ensure compliance with best practices.

Sveltos can leverage [kube-bench](https://github.com/aquasecurity/kube-bench) to run a security scan on all managed clusters.

Using the Sveltos event framework, we can centralized CIS Kubernetes Benchmark compliance results for a unified view.

![Deploy kube-bench to all production clusters](../assets/sveltos-deploy-kube-bench.png)

![Post process and collect kube-bench results](../assets/post-process-collect-kube-bench-failures.png)


```
sveltosctl show resources --kind=configmap
+---------------+---------------------+------------+---------------------+--------------------------------+
|    CLUSTER    |         GVK         | NAMESPACE  |        NAME         |            MESSAGE             |
+---------------+---------------------+------------+---------------------+--------------------------------+
| civo/cluster1 | /v1, Kind=ConfigMap | kube-bench | kube-bench-failures | [FAIL] 4.1.1 Ensure that       |
|               |                     |            |                     | the kubelet service file       |
|               |                     |            |                     | permissions are set to 600 or  |
|               |                     |            |                     | more restrictive (Automated)   |
|               |                     |            |                     | [FAIL] 4.1.5 Ensure that the   |
|               |                     |            |                     | --kubeconfig kubelet.conf      |
|               |                     |            |                     | file permissions are set       |
|               |                     |            |                     | to 600 or more restrictive     |
|               |                     |            |                     | (Automated) [FAIL] 4.1.6       |
|               |                     |            |                     | Ensure that the --kubeconfig   |
|               |                     |            |                     | kubelet.conf file ownership is |
|               |                     |            |                     | set to root:root (Automated)   |
|               |                     |            |                     | [FAIL] 4.1.9 If the kubelet    |
|               |                     |            |                     | config.yaml configuration      |
|               |                     |            |                     | file is being used validate    |
|               |                     |            |                     | permissions set to 600 or      |
|               |                     |            |                     | more restrictive (Automated)   |
|               |                     |            |                     | [FAIL] 4.1.10 If the kubelet   |
|               |                     |            |                     | config.yaml configuration      |
|               |                     |            |                     | file is being used validate    |
|               |                     |            |                     | file ownership is set          |
|               |                     |            |                     | to root:root (Automated)       |
|               |                     |            |                     | [FAIL] 4.2.1 Ensure that the   |
|               |                     |            |                     | --anonymous-auth argument      |
|               |                     |            |                     | is set to false (Automated)    |
|               |                     |            |                     | [FAIL] 4.2.2 Ensure that       |
|               |                     |            |                     | the --authorization-mode       |
|               |                     |            |                     | argument is not set to         |
|               |                     |            |                     | AlwaysAllow (Automated)        |
|               |                     |            |                     | [FAIL] 4.2.3 Ensure that the   |
|               |                     |            |                     | --client-ca-file argument is   |
|               |                     |            |                     | set as appropriate (Automated) |
|               |                     |            |                     | [FAIL] 4.2.6 Ensure that the   |
|               |                     |            |                     | --make-iptables-util-chains    |
|               |                     |            |                     | argument is set to             |
|               |                     |            |                     | true (Automated) [FAIL]        |
|               |                     |            |                     | 4.2.10 Ensure that the         |
|               |                     |            |                     | --rotate-certificates          |
|               |                     |            |                     | argument is not set to false   |
|               |                     |            |                     | (Automated) [FAIL] 4.3.1       |
|               |                     |            |                     | Ensure that the kube-proxy     |
|               |                     |            |                     | metrics service is bound       |
|               |                     |            |                     | to localhost (Automated)       |
|               |                     |            |                     | [FAIL] 5.1.1 Ensure that       |
|               |                     |            |                     | the cluster-admin role is      |
|               |                     |            |                     | only used where required       |
|               |                     |            |                     | (Automated) [FAIL] 5.1.2       |
|               |                     |            |                     | Minimize access to secrets     |
|               |                     |            |                     | (Automated) [FAIL] 5.1.3       |
|               |                     |            |                     | Minimize wildcard use in Roles |
|               |                     |            |                     | and ClusterRoles (Automated)   |
|               |                     |            |                     | [FAIL] 5.1.4 Minimize access   |
|               |                     |            |                     | to create pods (Automated)     |
|               |                     |            |                     | [FAIL] 5.1.5 Ensure that       |
|               |                     |            |                     | default service accounts are   |
|               |                     |            |                     | not actively used. (Automated) |
|               |                     |            |                     | [FAIL] 5.1.6 Ensure that       |
|               |                     |            |                     | Service Account Tokens are     |
|               |                     |            |                     | only mounted where necessary   |
|               |                     |            |                     | (Automated)                    |
| civo/cluster2 |                     | kube-bench | kube-bench-failures | [FAIL] 4.1.1 Ensure that       |
|               |                     |            |                     | the kubelet service file       |
|               |                     |            |                     | permissions are set to 600 or  |
|               |                     |            |                     | more restrictive (Automated)   |
|               |                     |            |                     | [FAIL] 4.1.5 Ensure that the   |
|               |                     |            |                     | --kubeconfig kubelet.conf      |
|               |                     |            |                     | file permissions are set       |
|               |                     |            |                     | to 600 or more restrictive     |
|               |                     |            |                     | (Automated) [FAIL] 4.1.6       |
|               |                     |            |                     | Ensure that the --kubeconfig   |
|               |                     |            |                     | kubelet.conf file ownership is |
|               |                     |            |                     | set to root:root (Automated)   |
|               |                     |            |                     | [FAIL] 4.1.9 If the kubelet    |
|               |                     |            |                     | config.yaml configuration      |
|               |                     |            |                     | file is being used validate    |
|               |                     |            |                     | permissions set to 600 or      |
|               |                     |            |                     | more restrictive (Automated)   |
|               |                     |            |                     | [FAIL] 4.1.10 If the kubelet   |
|               |                     |            |                     | config.yaml configuration      |
|               |                     |            |                     | file is being used validate    |
|               |                     |            |                     | file ownership is set          |
|               |                     |            |                     | to root:root (Automated)       |
|               |                     |            |                     | [FAIL] 4.2.1 Ensure that the   |
|               |                     |            |                     | --anonymous-auth argument      |
|               |                     |            |                     | is set to false (Automated)    |
|               |                     |            |                     | [FAIL] 4.2.2 Ensure that       |
|               |                     |            |                     | the --authorization-mode       |
|               |                     |            |                     | argument is not set to         |
|               |                     |            |                     | AlwaysAllow (Automated)        |
|               |                     |            |                     | [FAIL] 4.2.3 Ensure that the   |
|               |                     |            |                     | --client-ca-file argument is   |
|               |                     |            |                     | set as appropriate (Automated) |
|               |                     |            |                     | [FAIL] 4.2.6 Ensure that the   |
|               |                     |            |                     | --make-iptables-util-chains    |
|               |                     |            |                     | argument is set to             |
|               |                     |            |                     | true (Automated) [FAIL]        |
|               |                     |            |                     | 4.2.10 Ensure that the         |
|               |                     |            |                     | --rotate-certificates          |
|               |                     |            |                     | argument is not set to false   |
|               |                     |            |                     | (Automated) [FAIL] 4.3.1       |
|               |                     |            |                     | Ensure that the kube-proxy     |
|               |                     |            |                     | metrics service is bound       |
|               |                     |            |                     | to localhost (Automated)       |
|               |                     |            |                     | [FAIL] 5.1.1 Ensure that       |
|               |                     |            |                     | the cluster-admin role is      |
|               |                     |            |                     | only used where required       |
|               |                     |            |                     | (Automated) [FAIL] 5.1.2       |
|               |                     |            |                     | Minimize access to secrets     |
|               |                     |            |                     | (Automated) [FAIL] 5.1.3       |
|               |                     |            |                     | Minimize wildcard use in Roles |
|               |                     |            |                     | and ClusterRoles (Automated)   |
|               |                     |            |                     | [FAIL] 5.1.4 Minimize access   |
|               |                     |            |                     | to create pods (Automated)     |
|               |                     |            |                     | [FAIL] 5.1.5 Ensure that       |
|               |                     |            |                     | default service accounts are   |
|               |                     |            |                     | not actively used. (Automated) |
|               |                     |            |                     | [FAIL] 5.1.6 Ensure that       |
|               |                     |            |                     | Service Account Tokens are     |
|               |                     |            |                     | only mounted where necessary   |
|               |                     |            |                     | (Automated)                    |
| gke/cluster   |                     | kube-bench | kube-bench-failures | [FAIL] 3.2.1 Ensure that the   |
|               |                     |            |                     | --anonymous-auth argument      |
|               |                     |            |                     | is set to false (Automated)    |
|               |                     |            |                     | [FAIL] 3.2.2 Ensure that       |
|               |                     |            |                     | the --authorization-mode       |
|               |                     |            |                     | argument is not set to         |
|               |                     |            |                     | AlwaysAllow (Automated)        |
|               |                     |            |                     | [FAIL] 3.2.3 Ensure that the   |
|               |                     |            |                     | --client-ca-file argument is   |
|               |                     |            |                     | set as appropriate (Automated) |
|               |                     |            |                     | [FAIL] 3.2.6 Ensure that the   |
|               |                     |            |                     | --protect-kernel-defaults      |
|               |                     |            |                     | argument is set to true        |
|               |                     |            |                     | (Manual) [FAIL] 3.2.9 Ensure   |
|               |                     |            |                     | that the --event-qps argument  |
|               |                     |            |                     | is set to 0 or a level which   |
|               |                     |            |                     | ensures appropriate event      |
|               |                     |            |                     | capture (Automated) [FAIL]     |
|               |                     |            |                     | 3.2.12 Ensure that the         |
|               |                     |            |                     | RotateKubeletServerCertificate |
|               |                     |            |                     | argument is set to true        |
|               |                     |            |                     | (Automated)                    |
+---------------+---------------------+------------+---------------------+--------------------------------+
```

!!! tip
    The YAML defintions can be found [here](https://github.com/projectsveltos/demos/tree/main/cis-scan).