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
kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/dev/manifest/manifest.yaml
```

```
kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/default-classifier.yaml
```

It will install Sveltos CRDs and resources.

If Prometheus operator is not present in your management cluster, you will see (and can ignore) following error:

*error: unable to recognize "https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/manifest.yaml": no matches for kind "ServiceMonitor" in version "monitoring.coreos.com/v1"*

Sveltos uses the git-flow branching model. The base branch is dev. If you are looking for latest features, please use the dev branch. If you are looking for a stable version, please use the main branch or tags labeled as v0.x.x.

## Install using helm

Sveltos pods assume to be running in the projectsveltos namespace, so please create it if not present already.

```
kubectl create namespace projectsveltos
helm repo add projectsveltos https://projectsveltos.github.io/helm-charts
helm install projectsveltos projectsveltos/projectsveltos -n projectsveltos
```

## Get Sveltos Status​

Get Sveltos status and verify all pods are up and running

```
projectsveltos access-manager-69d7fd69fc-7r4lw         2/2     Running   0  40s
projectsveltos classifier-manager-6489f67447-52xd6     2/2     Running   0  40s
projectsveltos fm-controller-manager-55fc5f89f6-b4dwt  2/2     Running   0  40s
projectsveltos hc-manager-7b6d7c4968-x8f7b             2/2     Running   0  39s
projectsveltos sc-manager-cb6786669-9qzdw              2/2     Running   0  40s
projectsveltos event-manager-7b885dbd4c-tmn6m          2/2     Running   0  40s
```

## Verify default classifier

Verify default classifier instance has been installed. 

```
kubectl get classifier
```

If not present, do install it manually

```
kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/default-classifier.yaml
```

## Configuration

If you want to know more about how to configure Sveltos, please refer to this [section](addons.md#sveltos-manager-controller-configuration) and [this](labels_management.md#classifier-controller-configuration).

## Sveltosctl

### Run sveltosctl as a pod
[sveltosctl](https://github.com/projectsveltos/sveltosctl "Sveltos CLI") is not installed by default. 

If you decide to run [sveltosctl](https://github.com/projectsveltos/sveltosctl "Sveltos CLI") as a pod in the management cluster, here are the instructions:

```
kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/sveltosctl_manifest.yaml
```

Please keep in mind sveltosctl requires a PersistentVolume. So modify this section accordingly before posting the YAML.

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
