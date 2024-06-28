---
title: Install sveltosctl
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
## sveltosctl

The [Sveltosctl](https://github.com/projectsveltos/sveltosctl "Sveltos CLI") is the command-line interface (CLI) for Sveltos. It is an available option to query Sveltos resources but not a mandatory option.

### Option 1: Binaries

It offers a convenient CLI experience. The Binaries for each release are available on the [releases page](https://github.com/projectsveltos/sveltosctl/releases).

The Binaries are sufficient to register worker clusters with Sveltos, query resources etc. However, if you want more capabilities like the [Techsupport](../sveltosctl/techsupport.md) and the [Snapshot](../sveltosctl/snapshot.md), use "Option 2: Run sveltosctl as a pod".

### Option 2: Run sveltosctl as Pod

If you choose to run sveltosctl as a pod in the management cluster, the YAML configuration can be found [here](https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/sveltosctl_manifest.yaml).

Remember that sveltosctl necessitates a PersistentVolume. Before posting the YAML, make the necessary adjustments to the below section.

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
$ sveltosctl --help
```

You might also want to change the timezone of sveltosctl pod by using specific timezone config and hostPath volume to set specific timezone. Currently:

```yaml
  volumes:
  - hostPath:
      path: /usr/share/zoneinfo/America/Los_Angeles
      type: File
    name: tz-config
```

!!! tip
    The Sveltos CLI pod cannot be used as a way to register a worker Kubernetes cluster. For that, use the Sveltos Binaries.