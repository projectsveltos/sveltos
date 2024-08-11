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

This demo will showcase Sveltos' capabilities by:

1. Provisioning multiple Postgres instances: All instances will be deployed on a managed Kubernetes cluster, exposed via a LoadBalancer service, and secured with unique credentials;
2. Retrieving instance details: Sveltos will extract Postgres credentials and LoadBalancer endpoint information;
3. Creating database objects: Two separate Jobs will be deployed on distinct managed Kubernetes clusters (`pre-production` and `production`). These Jobs will connect to different Postgres instances and execute SQL commands to create tables.

![Deploying managed services with Sveltos](../assets/sveltos-managed-services.gif)

## Managed Clusters

- managed-services-cluster: This cluster is a managed service cluster used to deploy Postgres databases. It has labels `type: managed-services`
- pre-production: This cluster is dedicated to pre-production deployments. Applications running here will access the pre-production Postgres instance. Labels include `type: pre-production`
- production: This cluster is for production deployments. Applications running here will access the production Postgres instance. Labels include: `type: production`

The type label differentiates between managed service deployment, pre-production, and production environments.
Applications needing to access Postgres databases should be deployed in the appropriate cluster based on their environment (pre-production or production).

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
  - namespaces 
  - secrets
  verbs:
  - "*"
```

## Deploy Postgres

Sveltos will be used to deploy two Postgres instances on the `managed-services-cluster`
 
```bash
wget https://raw.githubusercontent.com/projectsveltos/demos/main/managed-services/production-postgres.yaml 
kubectl create configmap production-postgres --from-file=production-postgres.yaml
wget https://raw.githubusercontent.com/projectsveltos/demos/main/managed-services/pre-production-postgres.yaml 
kubectl create configmap pre-production-postgres --from-file=pre-production-postgres.yaml
kubectl apply -f https://raw.githubusercontent.com/projectsveltos/demos/main/managed-services/deploy-postgres-clusterprofile.yaml
```

Verify two Postgres instances (one in the `pre-production` namespace and the other in the `production` namespace) are deployed using sveltosctl:

```
sveltosctl show addons
+------------------------------------------+-----------------+-------------------------+-------------------------+---------+--------------------------------+-----------------------------------------------+
|                 CLUSTER                  |  RESOURCE TYPE  |        NAMESPACE        |          NAME           | VERSION |              TIME              |                   PROFILES                    |
+------------------------------------------+-----------------+-------------------------+-------------------------+---------+--------------------------------+-----------------------------------------------+
| managed-services/managed-service-cluster | :Secret         | pre-production-services | postgres-secret         | N/A     | 2024-07-29 14:20:20 +0200 CEST | ClusterProfile/deploy-pre-production-postgres |
| managed-services/managed-service-cluster | apps:Deployment | pre-production-services | postgresql              | N/A     | 2024-07-29 14:20:21 +0200 CEST | ClusterProfile/deploy-pre-production-postgres |
| managed-services/managed-service-cluster | :Service        | pre-production-services | postgresql              | N/A     | 2024-07-29 14:20:22 +0200 CEST | ClusterProfile/deploy-pre-production-postgres |
| managed-services/managed-service-cluster | :Namespace      |                         | production-services     | N/A     | 2024-07-29 14:20:04 +0200 CEST | ClusterProfile/deploy-production-postgres     |
| managed-services/managed-service-cluster | :Secret         | production-services     | postgres-secret         | N/A     | 2024-07-29 14:20:06 +0200 CEST | ClusterProfile/deploy-production-postgres     |
| managed-services/managed-service-cluster | apps:Deployment | production-services     | postgresql              | N/A     | 2024-07-29 14:20:07 +0200 CEST | ClusterProfile/deploy-production-postgres     |
| managed-services/managed-service-cluster | :Service        | production-services     | postgresql              | N/A     | 2024-07-29 14:20:08 +0200 CEST | ClusterProfile/deploy-production-postgres     |
| managed-services/managed-service-cluster | :Namespace      |                         | pre-production-services | N/A     | 2024-07-29 14:20:18 +0200 CEST | ClusterProfile/deploy-pre-production-postgres |
+------------------------------------------+-----------------+-------------------------+-------------------------+---------+--------------------------------+-----------------------------------------------+
```

## Fetch Postgres info

Post-Postgres deployment, we require:

- Database credentials for establishing connections.
- LoadBalancer endpoint information (IP:port) to access the Postgres instance externally.

Sveltos event framework was used to collect such information.

```
kubectl apply -f https://raw.githubusercontent.com/projectsveltos/demos/main/managed-services/fetch-credentials.yaml
kubectl apply -f https://raw.githubusercontent.com/projectsveltos/demos/main/managed-services/fetch-service-ip.yaml
```

Verify that information was successfully collected

```
kubectl get configmap -n production-services postgres-host-port 
kubectl get configmap -n pre-production-services postgres-host-port
kubectl get secret -n production-services postgres-credentials
kubectl get secret -n pre-production-services postgres-credentials
```

## Deploy Job to the production cluster

With the Postgres service operational on the managed-services-cluster, we can proceed with deploying a Job to the managed production cluster. 
This Job will create a table within the production Postgres database. To initiate this process, let's construct a ConfigMap containing a Job template.

```
kubectl apply -f https://raw.githubusercontent.com/projectsveltos/demos/main/managed-services/configmap-with-templated-job.yaml
```

Next, we'll instruct Sveltos to instantiate the Job template and deploy it to the production cluster:

```
kubectl apply -f https://raw.githubusercontent.com/projectsveltos/demos/main/managed-services/deploy-job-to-production.yaml
```

By directing kubectl to the production cluster, we can confirm the Job's creation and successful completion. This indicates that the table has been successfully established within the Postgres database on the managed services cluster.

## Deploy Job to the pre-production cluster

A similar Job can be deployed to the pre-production cluster to create a table within the corresponding pre-production Postgres database. 

```
kubectl apply -f https://raw.githubusercontent.com/projectsveltos/demos/main/managed-services/deploy-job-to-pre-production.yaml
```

By directing kubectl to the pre-production cluster, we can confirm the Job's creation and successful completion. This indicates that the table has been successfully established within the Postgres database on the managed services cluster.

## Yet another example

Learn [how to expose](https://medium.com/p/d26b87cbd5a4) your managed services with Gateway API.