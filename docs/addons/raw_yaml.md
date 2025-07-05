---
title: Sveltos - Kubernetes Add-on Controller | Manage Kubernetes Add-ons with Ease
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative APIs to deploy Kubernetes add-ons across multiple clusters.
tags:
    - Kubernetes
    - add-ons
    - helm
    - kustomize
    - clusterapi
    - multi-tenancy
    - Sveltos
authors:
    - Gianluca Mardente
---

## ClusterProfile policyRefs Reference

The ClusterProfile *spec.policyRefs* is a list of Secrets/ConfigMaps. Both Secrets and ConfigMaps data fields can be a list of key-value pairs. Any key is acceptable, and the value can be multiple objects in YAML or JSON format[^1].

### Example: Create a Secret

To create a Kubernetes Secret that contains the Calico YAMLs and make it usable with Sveltos, utilise the below commands.

```bash
$ wget https://raw.githubusercontent.com/projectcalico/calico/master/manifests/calico.yaml

$ kubectl create secret generic calico --from-file=calico.yaml --type=addons.projectsveltos.io/cluster-profile
```

The commands will download the calico.yaml manifest file and afterwards create a Kubernetes secret of type `generic` by defining the file downloaded in the previous command plus defining the needed `type=addons.projectsveltos.io/cluster-profile`.

!!! note
    A ClusterProfile can only reference Secrets of type ***addons.projectsveltos.io/cluster-profile***

### Example: Create a ConfigMap

The YAML definition below exemplifies a `ConfigMap` that holds multiple resources[^2]. When a ClusterProfile instance references the `ConfigMap`, a `Namespace` and a `Deployment` instance are automatically deployed in any managed cluster that adheres to the ClusterProfile *clusterSelector*.

!!! example "Example - Resources Definition"
    ```yaml
    cat > nginx_cm.yaml <<EOF
    ---
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: nginx
      namespace: default
    data:
      namespace.yaml: |
        kind: Namespace
        apiVersion: v1
        metadata:
          name: nginx
      deployment.yaml: |
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: nginx-deployment
          namespace: nginx
        spec:
          replicas: 2 # number of pods to run
          selector:
            matchLabels:
              app: nginx
          template:
            metadata:
              labels:
                app: nginx
            spec:
              containers:
              - name: nginx
                image: nginx:latest # public image from Docker Hub
                ports:
                - containerPort: 80
    EOF
    ```

Once the required Kubernetes resources are created/deployed, the below example represents a ClusterProfile resource that references the `ConfigMap` and the `Secret` created above.

!!! example "Example - ClusterProfile Definition with Reference"
    ```yaml
    cat > clusterprofile_deploy_nginx.yaml <<EOF
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: deploy-resources
    spec:
      clusterSelector:
        matchLabels:
          env: fv
      policyRefs:
      - name: nginx
        namespace: default
        kind: ConfigMap
      - name: calico
        namespace: default
        kind: Secret
    EOF
    ```

!!! note
    The `namespace` definition refers to the namespace where the `ConfigMap`, and the Secret were created in the management cluster. In our example, both resources created in the `default` namespace.

When a ClusterProfile references a `ConfigMap` or a `Secret`, the **kind** and **name** fields are required, while the namespace field is optional. Specifying a namespace uniquely identifies the resource using the tuple namespace, name, and kind, and that resource will be used for all matching clusters.

If you leave the namespace field empty, Sveltos will search for the `ConfigMap` or the `Secret` with the provided name within the namespace of each matching cluster.

### Example: Understand Namespace Definition

!!! example ""
    ```yaml
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: deploy-resources
    spec:
      clusterSelector:
        matchLabels:
          env: fv
      policyRefs:
      - name: nginx
        kind: ConfigMap
    ```

Consider the provided ClusterProfile, when we have two workload clusters matching. One in the _foo_ namespace and another in the _bar_ namespace. Sveltos will search for the `ConfigMap` _nginx_ in the _foo_ namespace for the Cluster in the _foo_ namespace and for a `ConfigMap` _ngix_ in the _bar_ namespace for the Cluster in the _bar_ namespace.

More ClusterProfile examples can be found [here](https://github.com/projectsveltos/sveltos-manager/tree/main/examples "Manage Kubernetes add-ons: examples").

### Example: Template-based Referencing for ConfigMaps and Secrets

We can express `ConfigMap` and `Secret` **names** as templates. This allows us to generate them dynamically based on the available cluster information, simplifying management and reducing repetition.

#### Available cluster information

- **cluster namespace**: `.Cluster.metadata.namespace`
- **cluster name**: `.Cluster.metadata.name`
- **cluster type**: `.Cluster.kind`

Consider two SveltosCluster instances in the _civo_ namespace.

```bash
$ kubectl get sveltoscluster -n civo --show-labels
NAME             READY   VERSION        LABELS
pre-production   true    v1.29.2+k3s1   env=civo,projectsveltos.io/k8s-version=v1.29.2
production       true    v1.28.7+k3s1   env=civo,projectsveltos.io/k8s-version=v1.28.7
```

Two `ConfigMaps` named _nginx-pre-production_ and _nginx-production_ exist in the same namespace.

```bash
$ kubectl get configmap -n civo
NAME                   DATA   AGE
nginx-pre-production   2      4m59s
nginx-production       2      4m41s
```

The only difference between the `ConfigMaps` is the __replicas__ setting: 1 for _pre-production_ and 3 for _production_.

The below points are included in the `ClusterProfile`.

1. *Matches both SveltosClusters*
1. *Dynamic ConfigMap Selection*:
    - For the `pre-production` cluster, the profile should use the `nginx-pre-production` ConfigMap.
    - For the `production` cluster, the profile should use the `nginx-production` ConfigMap.

!!! example ""
    ```yaml hl_lines="9-11"
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: deploy-nginx
    spec:
      clusterSelector:
        matchLabels:
          env: civo
      policyRefs:
      - name: nginx-{{ .Cluster.metadata.name }}
        kind: ConfigMap
    ```
The demonstrated approach provides a **flexible** and **centralized** way to reference `ConfigMaps` and `Secrets` based on the availanle cluster information.

## Template

Define the content for resources in your `PolicyRefs` using templates. During deployment, Sveltos will automatically populate these templates with relevant information from your cluster and other resources in the management cluster. See the template section [template section](../template/template_generic_examples.md) for details.

Remember to adapt the provided resources to your specific repository structure, cluster configuration, and desired templating logic.

[^1]:A ConfigMap is not designed to hold large chunks of data. The data stored in a ConfigMap cannot exceed 1 MiB. If you need to store settings that are larger than this limit, you may want to consider mounting a volume or use a separate database or file service.
[^2]: Another way to create a Kubernetes ConfigMap resource is with the imperative approach. The below command will create the same ConfigMap resource in the management cluster.
```bash
$ kubectl create configmap nginx --from-file=namespace.yaml --from-file=deployment.yaml
```

## Subresources

Sveltos can update specific subresources of a resource. This is achieved by leveraging the `projectsveltos.io/subresources` annotation. When the annotation is present on a resource referenced in the `PolicyRefs` section, Sveltos updates the designated subresources alongside the main resource. Subresources are specified as a comma-separated list within the annotation value.

For example, to instruct Sveltos to update the status subresource of a Service, we can create a `ConfigMap` with the following structure and reference this `ConfigMap` from a ClusterProfile/Profile.

!!! example ""
    ```yaml hl_lines="24-25"
    ---
    apiVersion: v1
    data:
      service.yaml: |
        apiVersion: v1
        kind: Service
        metadata:
          name: sveltos-subresource
          namespace: default
        spec:
          selector:
            app: foo
          ports:
          - name: my-port
            port: 443
            protocol: TCP
            targetPort: 1032
          type: LoadBalancer
        status:
          loadBalancer:
            ingress:
            - ip: 1.1.1.1
    kind: ConfigMap
    metadata:
      annotations:
        projectsveltos.io/subresources: status
      name: load-balancer-service
      namespace: default
    ```
