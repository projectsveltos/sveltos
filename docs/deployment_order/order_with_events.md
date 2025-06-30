---
title: Resource Deployment Order - Order with Events
description: Describe how Sveltos can be instructed to follow an order when deploying resources
tags:
    - Kubernetes
    - Sveltos
    - add-ons
    - order
authors:
    - Gianluca Mardente
---

## Scenario Description

In some cases, it is necessary to deploy Kubernetes resources only after other resources are in a `healthy` state. For example, a Job that creates a table in a database should not be deployed until the database Deployment is healthy.

Sveltos can assist with this problem by allowing you to use events to control the rollout of your application.

An event is a notification that is sent when a certain condition is met. For example, you can create an event that it is sent when a database Deployment becomes healthy.

You can then use this event to trigger the deployment of the Job that creates the table in the database.

By using events, you can ensure that your application is rolled out in a controlled and orderly manner.

![Sveltos Resource Deployment Order](../assets/sveltos_resource_order.png)

![Sveltos Resource Deployment Order](../assets/sveltos_resource_order.gif)

### PostgreSQL Deployment and Service

[^5]With the ConfigMap __postgresql-deployment__ and the __postgresql-service__ containing respectively PostgreSQL Deployment and Service[^1], the below ClusterProfile
will instruct Sveltos to create a PostgreSQL Deployment and Service in all clusters matching the label __env: fv__.

```yaml
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: postgresql
spec:
  clusterSelector:
    matchLabels:
      env: fv
  policyRefs:
  - name: postgresql-deployment
    namespace: default
    kind: ConfigMap
  - name: postgresql-service
    namespace: default
    kind: ConfigMap
```

```bash
$ sveltosctl show addons

+-----------------------------+-----------------+-----------+------------+---------+-------------------------------+------------------+
|           CLUSTER           |  RESOURCE TYPE  | NAMESPACE |    NAME    | VERSION |             TIME              | CLUSTER PROFILES |
+-----------------------------+-----------------+-----------+------------+---------+-------------------------------+------------------+
| default/clusterapi-workload | apps:Deployment | todo      | postgresql | N/A     | 2023-08-20 08:23:11 -0700 PDT | postgresql       |
| default/clusterapi-workload | :Service        | todo      | postgresql | N/A     | 2023-08-20 08:23:11 -0700 PDT | postgresql       |
+-----------------------------+-----------------+-----------+------------+---------+-------------------------------+------------------+
```

### Create a Table in the database

With the ConfigMap __postgresql-job__ containing a Job that creates a table Todo in the database[^2], the below YAML definition instruct Sveltos to wait for the PostgreSQL Deployment to be healthy and only then deply the Job.

!!! example ""
    ```yaml
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: EventSource
    metadata:
    name: postgresql-deployment-health
    spec:
    collectResources: false
    resourceSelectors:
    - group: "apps"
      version: "v1"
      kind: "Deployment"
      namespace: todo
      evaluate: |
        function evaluate()
          hs = {}
          hs.matching = false
          hs.message = ""
          if obj.metadata.name == "postgresql" then
            if obj.status ~= nil then
              if obj.status.availableReplicas ~= nil then
                if obj.status.availableReplicas == obj.spec.replicas then
                  hs.matching = true
                end
              end
            end
          end
          return hs
        end
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: EventTrigger
    metadata:
    name: deploy-insert-table-job
    spec:
    sourceClusterSelector:
      matchLabels:
        env: fv
    eventSourceName: postgresql-deployment-health
    stopMatchingBehavior: LeavePolicies
    policyRefs:
    - name: postgresql-job
      namespace: default
      kind: ConfigMap
    ```

As soon as the PostgreSQL Deployment is `healthy`, Sveltos will deploy the Job. The Job will create table __Todo__.

```bash
$ sveltosctl show addons
+-----------------------------+-----------------+-----------+------------+---------+-------------------------------+------------------------------+
|           CLUSTER           |  RESOURCE TYPE  | NAMESPACE |    NAME    | VERSION |             TIME              |       CLUSTER PROFILES       |
+-----------------------------+-----------------+-----------+------------+---------+-------------------------------+------------------------------+
| default/clusterapi-workload | apps:Deployment | todo      | postgresql | N/A     | 2023-08-20 08:23:11 -0700 PDT | postgresql                   |
| default/clusterapi-workload | :Service        | todo      | postgresql | N/A     | 2023-08-20 08:23:11 -0700 PDT | postgresql                   |
| default/clusterapi-workload | batch:Job       | todo      | todo-table | N/A     | 2023-08-20 08:30:19 -0700 PDT | sveltos-2gv4dh8dl5fqy2z0amnx |
+-----------------------------+-----------------+-----------+------------+---------+-------------------------------+------------------------------+
```

### Deploy todo App

With the ConfigMap __todo-app__ containing the todo app (ServiceAccount, Deployment, Service)[^3], the below YAML defintion instructs Sveltos to deploy the `todo` app only after previous Job is complete.

!!! example ""
    ```yaml
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: EventSource
    metadata:
    name: postgresql-job-completed
    spec:
    collectResources: false
    resourceSelectors:
    - group: "batch"
      version: "v1"
      kind: "Job"
      namespace: todo
      evaluate: |
        function evaluate()
          hs = {}
          hs.matching = false
          hs.message = ""
          if obj.metadata.name == "todo-table" then
            if obj.status ~= nil then
              if obj.status.succeeded == 1 then
                hs.matching = true
              end
            end
          end
          return hs
        end
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: EventTrigger
    metadata:
    name: deploy-todo-app
    spec:
    sourceClusterSelector:
      matchLabels:
        env: fv
    eventSourceName: postgresql-job-completed
    stopMatchingBehavior: LeavePolicies
    policyRefs:
    - name: todo-app
      namespace: default
      kind: ConfigMap
    ```

```bash
$ sveltosctl show addons
+-----------------------------+---------------------------+-----------+-------------+---------+-------------------------------+------------------------------+
|           CLUSTER           |       RESOURCE TYPE       | NAMESPACE |    NAME     | VERSION |             TIME              |       CLUSTER PROFILES       |
+-----------------------------+---------------------------+-----------+-------------+---------+-------------------------------+------------------------------+
| default/clusterapi-workload | apps:Deployment           | todo      | postgresql  | N/A     | 2023-08-20 08:23:11 -0700 PDT | postgresql                   |
| default/clusterapi-workload | :Service                  | todo      | postgresql  | N/A     | 2023-08-20 08:23:11 -0700 PDT | postgresql                   |
| default/clusterapi-workload | batch:Job                 | todo      | todo-table  | N/A     | 2023-08-20 08:30:19 -0700 PDT | sveltos-2gv4dh8dl5fqy2z0amnx |
| default/clusterapi-workload | :Service                  | todo      | todo-gitops | N/A     | 2023-08-20 08:36:17 -0700 PDT | sveltos-n7201iyuxbsyra94r59f |
| default/clusterapi-workload | :ServiceAccount           | todo      | todo-gitops | N/A     | 2023-08-20 08:36:17 -0700 PDT | sveltos-n7201iyuxbsyra94r59f |
| default/clusterapi-workload | apps:Deployment           | todo      | todo-gitops | N/A     | 2023-08-20 08:36:17 -0700 PDT | sveltos-n7201iyuxbsyra94r59f |
| default/clusterapi-workload | networking.k8s.io:Ingress | todo      | todo        | N/A     | 2023-08-20 08:36:17 -0700 PDT | sveltos-n7201iyuxbsyra94r59f |
+-----------------------------+---------------------------+-----------+-------------+---------+-------------------------------+------------------------------+
```

### Write Entry to Database

With the ConfigMap __todo-insert-data__ containing a Job which will add an entry to databse[^4], the below YAML definition instructs Sveltos to deploy a Job only after the `todo` app is `healthy`.

!!! example ""
    ```yaml
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: EventSource
    metadata:
    name: todo-app-health
    spec:
    collectResources: false
    resourceSelectors:
    - group: "apps"
      version: "v1"
      kind: "Deployment"
      namespace: todo
      evaluate: |
        function evaluate()
          hs = {}
          hs.matching = false
          hs.message = ""
          if obj.metadata.name == "todo-gitops" then
            if obj.status ~= nil then
              if obj.status.availableReplicas ~= nil then
                if obj.status.availableReplicas == obj.spec.replicas then
                  hs.matching = true
                end
              end
            end
          end
          return hs
        end
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: EventTrigger
    metadata:
    name: insert-data
    spec:
    sourceClusterSelector:
      matchLabels:
        env: fv
    eventSourceName: todo-app-health
    stopMatchingBehavior: LeavePolicies
    policyRefs:
    - name: todo-insert-data
      namespace: default
      kind: ConfigMap
    ```

## Scenario Resources

[^1]: Get PostgreSQL YAML
```bash
$ wget https://raw.githubusercontent.com/projectsveltos/sveltos/main/docs/assets/postgresql_deployment.yaml

$ wget https://raw.githubusercontent.com/projectsveltos/sveltos/main/docs/assets/postgresql_service.yaml

$ kubectl create configmap postgresql-deployment --from-file postgresql_deployment.yaml

$ kubectl create configmap postgresql-service --from-file postgresql_service.yaml
```

[^2]: Get Job YAML
```bash
$ wget https://raw.githubusercontent.com/projectsveltos/sveltos/main/docs/assets/postgresql_job.yaml

$ kubectl create configmap postgresql-job --from-file postgresql_job.yaml
```

[^3]: Get todo-app YAML
```bash
$ wget https://raw.githubusercontent.com/projectsveltos/sveltos/main/docs/assets/todo_app.yaml

$ kubectl create configmap todo-app --from-file todo_app.yaml
```

[^4]: Get Job YAML
```bash
$ wget https://raw.githubusercontent.com/projectsveltos/sveltos/main/docs/assets/todo_insert.yaml

$ kubectl create configmap todo-insert-data --from-file todo_insert.yaml
```

[^5]: The example used in this document is based on and modified from [here](https://redhat-scholars.github.io/argocd-tutorial/argocd-tutorial/04-syncwaves-hooks.html).

