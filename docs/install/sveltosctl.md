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

[Sveltosctl](https://github.com/projectsveltos/sveltosctl "Sveltos CLI"), the command-line interface (CLI) for Sveltos, is available but not mandatory for using Sveltos. It offers a convenient CLI experience. Binaries for each release can be found on the [releases page](https://github.com/projectsveltos/sveltosctl/releases).

### Run sveltosctl as a pod

Binaries are sufficient unless you require the [Techsupport](../sveltosctl/techsupport.md) and [Snapshot](../sveltosctl/snapshot.md) features.

If you choose to run sveltosctl as a pod in the management cluster, the YAML configuration is available [here](https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/sveltosctl_manifest.yaml).

Remember that sveltosctl necessitates a PersistentVolume. Before posting the YAML, make the necessary adjustments to this section.

```yaml
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

```yaml
  volumes:
  - hostPath:
      path: /usr/share/zoneinfo/America/Los_Angeles
      type: File
    name: tz-config
```
