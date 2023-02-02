---
title: How to install
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative cluster APIs. Learn here how to install Sveltos.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
authors:
    - Gianluca Mardente
---
To install Sveltos simply run:

```
kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/manifest.yaml
```

It will install Sveltos CRDs and resources.

If Prometheus operator is not present in your management cluster, you will see (and can ignore) following error:

*error: unable to recognize "https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/manifest.yaml": no matches for kind "ServiceMonitor" in version "monitoring.coreos.com/v1"*

Sveltos uses the git-flow branching model. The base branch is dev. If you are looking for latest features, please use the dev branch. If you are looking for a stable version, please use the main branch or tags labeled as v0.x.x.

## Get Sveltos Status​

Get Sveltos status and verify all pods are up and running

```
projectsveltos   access-manager-6f7fcdd95d-qwkwc           2/2     Running   0          2m2s
projectsveltos   classifier-manager-79b4485978-dz2xs       2/2     Running   0          2m2s
projectsveltos   fm-controller-manager-74558b7dd9-xjjrr    2/2     Running   0          7m6s
projectsveltos   sveltoscluster-manager-55f999f55d-4thzd   2/2     Running   0          2m2s
```

### Sveltosctl

#### Run sveltosctl as a pod
[sveltosctl](https://github.com/projectsveltos/sveltosctl) is not installed by default. 

If you decide to run [sveltosctl](https://github.com/projectsveltos/sveltosctl) as a pod in the management cluster, here are the instructions:

```
kubectl create -f  https://raw.githubusercontent.com/projectsveltos/sveltosctl/main/manifest/utils.projectsveltos.io_snapshots.yaml

kubectl create -f  https://raw.githubusercontent.com/projectsveltos/sveltosctl/main/manifest/sveltosctl.yaml
```

Please keep in mind sveltosctl requires a PersistentVolume. So modify this section accordingly before posting the YAML.

```
  volumeClaimTemplates:
  - metadata:
      name: snapshot
    spec:
      accessModes: [ "ReadWriteOnce" ]
      storageClassName: "standard"
      resources:
        requests:
          storage: 1Gi
```

Once the pod is running,
```
 kubectl exec -it -n projectsveltos sveltosctl-0   -- ./sveltosctl --help
```

You might also want to change the timezone of sveltosctl pod by using specific timezone config and hostPath volume to set specific timezone. Currently:

```
  volumes:
  - hostPath:
      path: /usr/share/zoneinfo/America/Los_Angeles
      type: File
    name: tz-config
```
