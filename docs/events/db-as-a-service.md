---
title: Example Service Event Trigger - Project Sveltos
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative APIs to deploy Kubernetes add-ons across multiple clusters.
tags:
    - Kubernetes
    - managed services
    - Sveltos
    - event driven
authors:
    - Gianluca Mardente
---

This demo will showcase Sveltos' ability to dynamically provision PostgreSQL databases on demand. 

By simply labeling a managed cluster with  `postgres=required`, Sveltos will automatically deploy a dedicated PostgreSQL database within the services managed cluster. This database will then be made accessible to the requesting cluster, ensuring seamless integration and data access.

## Granting Extra RBAC

For this demo, Sveltos needs to be granted extra permission.

```
kubectl edit clusterroles  addon-controller-role-extra
```

and add following permissions

```yaml
- apiGroups:
  - ""
  resources:
  - configmaps 
  - secrets
  verbs:
  - "*"
```

## Lab Setup

A Civo cluster serves as the management cluster.
Another Civo cluster, labeled `type=services`, is dedicated to automatic Postgres DB deployment by Sveltos.

Postgres DB will be deployed using [Cloudnative-pg](https://github.com/cloudnative-pg/cloudnative-pg).

![Sveltos: Deploy Cloudnative-pg](../assets/sveltos-db-as-a-service.gif)

## Step 1: Install Sveltos on Management Cluster

For this tutorial, we will install Sveltos in the management cluster. Sveltos installation details can be found [here](../getting_started/install/install.md).

```
helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.16.1 --set crds.enabled=true
helm install projectsveltos projectsveltos/projectsveltos -n projectsveltos --create-namespace
```

Add the label `type=mgmt` to the management cluster:

```
kubectl label sveltoscluster -n mgmt mgmt type=mgmt
```

## Step 2: Register Clusters with Sveltos

Using Civo UI, download the Kubeconfigs, then:

```
kubectl create ns managed-services
sveltosctl register cluster --namespace=managed-services --cluster=cluster --kubeconfig=<managed cluster kubeconfig> --labels=type=services
```

Verify clusters were successfully registered:

```
kubectl get sveltoscluster -A --show-labels
NAMESPACE          NAME      READY   VERSION        LABELS
mgmt               mgmt      true    v1.29.2+k3s1   projectsveltos.io/k8s-version=v1.29.2,sveltos-agent=present,type=mgmt
managed-services   cluster   true    v1.29.8+k3s1   projectsveltos.io/k8s-version=v1.29.8,sveltos-agent=present,type=services
```

## Step 3: Deploy cloudnative-pg

Following ClusterProfile will deploy Cloudnative-pg in the managed cluster with label `type=services`

```
kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/main/docs/assets/cloudnative-pg.yaml
```

Verify resources were deployed

```
sveltosctl show addons        
+--------------------------+---------------+-------------+------+---------+--------------------------------+----------------------------+
|         CLUSTER          | RESOURCE TYPE |  NAMESPACE  | NAME | VERSION |              TIME              |          PROFILES          |
+--------------------------+---------------+-------------+------+---------+--------------------------------+----------------------------+
| managed-services/cluster | helm chart    | cnpg-system | cnpg | 0.22.1  | 2024-10-25 15:47:54 +0200 CEST | ClusterProfile/deploy-cnpg |
+--------------------------+---------------+-------------+------+---------+--------------------------------+----------------------------+
```

![Sveltos: Deploy Cloudnative-pg](../assets/sveltos-cloudnative-pg.png)


## Step 4: Instruct Sveltos to automatically deploy Postgres DB 

Following configuration will instruct Sveltos to watch for managed cluster with labels `postgres=required`. Anytime such a cluster is detect, Sveltos will:

1. Create a Postgres Cluster instance in the managed cluster with label `type:services`. DB will be exposed via a LoadBalancer service.
2. Fetch credentials to access the DB.
3. fetch the LoadBalancer service external ip: port

```
kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/main/docs/assets/auto-deploy-postgres-cluster.yaml
kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/main/docs/assets/fetch-postgres-data.yaml
```

## Step 5: Onboard a new managed cluster

Whenever a new managed cluster is registered with Sveltos and labeled with 'postgres=required', Sveltos will initiate the deployment of a new Postgres database on the 'type=services' cluster. 
Once deployed, Sveltos will gather the essential connection information, including credentials, external IP address, and port number, for this newly created Postgres instance.

Here we created a new Civo cluster and registered with Sveltos:

```
kubectl create ns coke
sveltosctl register cluster --namespace=coke --cluster=cluster --kubeconfig=<managed cluster kubeconfig> --labels=postgres=required
```

Verify Sveltos deployed the Postgres Cluster and fetched the info necessary to connect:

```
kubectl get secret -n coke
NAME                         TYPE     DATA   AGE
cluster-credentials          Opaque   2      0s
```

The Secret Data section contains:

```
data:
  password: bTloaW9UYUFBdVE1cFBQY1QzWGN6RDF2R3JUYzF5d3NVRTcwUTJQQXVUaTNucEZhRVdEYXpsZ1pmcnAzYWZwdg==
  user: dG9kbw==
```

```
kubectl get configmap -n coke                         
NAME                        DATA   AGE
...
cluster-loadbalancer-data   2      58s
```

The ConfigMap Data section contains:

```
data:
  external-ip: 212.2.242.242
  port: "5432"
```

## Step 6: Deploy an application that access the Postgres DB

Sveltos can now be used to deploy a Job in the `coke` cluster. This Job will access the Postgres DB in the `services` cluster.

This Job is expressed as a template and will be deployed by Sveltos in any cluster with label `type=app`.

```
kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/main/docs/assets/job-to-create-table.yaml
```

```
kubectl label sveltoscluster -n coke cluster type=app
```


## Step 7: Add another managed cluster

Here we created yet another Civo cluster and registered with Sveltos[^1]. As result:

1. Sveltos deployed a new Postgres DB in the `services` cluster;
2. Fetched the credentials and external-ip:port info to access the cluster;
3. Deployed a Job in the `pepsi` cluster that creates a table in the DB.

[^1]:
    ```
    kubectl create ns pepsi
    sveltosctl register cluster --namespace=pepsi --cluster=cluster --kubeconfig=<managed cluster kubeconfig> --labels=postgres=required,type=app
    ```
