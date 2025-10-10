---
title: Register Cluster
description: Sveltos comes with support to automatically discover ClusterAPI powered clusters. Any other cluster (GKE for instance) can easily be registered with Sveltos.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
authors:
    - Gianluca Mardente
---

## Sveltos Cluster Registration

Sveltos supports **automatic** discovery of clusters powered by [ClusterAPI (CAPI)](https://github.com/kubernetes-sigs/cluster-api). When Sveltos is deployed in a management cluster with **CAPI**, no further action is required for add-on management. It will watch for *clusters.cluster.x-k8s.io* instances and program those accordingly.

For any other types of clusters, whether on-prem or in the cloud, Sveltos provides **seamless** [management of Kubernetes add-ons](../addons/addons.md). Check out the [examples section](#registration-examples).

## Register Cluster

### sveltosctl Registration

It is recommended, but not required, to use the [sveltosctl](https://github.com/projectsveltos/sveltosctl "Sveltos CLI") for cluster registration. Alternatively, to **programmatically** register clusters, consult the [section](#programmatic-registration).

```bash
$ sveltosctl register cluster \
    --namespace=monitoring \
    --cluster=prod-cluster \
    --kubeconfig=~/.kube/prod-cluster.config \
    --labels=environment=production,tier=backend
```

| Parameter        |    Description                                                                                                   |
|------------------|------------------------------------------------------------------------------------------------------------------|
| `--namespace`    |    The namespace in the **management cluster** where Sveltos stores information about the registered cluster.    |
| `--cluster`      |    The **name** to identify the registered cluster within Sveltos.                                               |
| `--kubeconfig`   |    The path to the **kubeconfig** file for the registered cluster.                                               |
| `--labels`       |    (Optional) Comma-separated key-value pairs to define labels for the registered cluster.                       |

!!!note
    If the `kubeconfig` has multiple contexes, and the default context points to the management cluster, use the __--fleet-cluster-context__ option. This option sets the name of the context that points to the cluster to be registered. The below example will generate a kubeconfig file and register the cluster with Sveltos.

    ```bash
    $ sveltosctl register cluster \
        --namespace=<namespace> \
        --cluster=<cluster name> \
        --fleet-cluster-context=<context name> \
        --labels=key1=value1,key2=value2
    ```

??? tip "Alternative Sveltos Cluster Registration"

    If a different `kubeconfig` is required, users can utilise the `sveltosctl generate kubeconfig` command. It allows Sveltos to create the required `ServiceAccount` alongside the `kubeconfig`. To proceed with the registration process, follow the steps listed below.

    1. Generate the kubeconfig: Use the `sveltosctl generate kubeconfig` command while pointing it to the cluster you want Sveltos to manage. The command will create a ServiceAccount with `cluster-admin` permissions and generate the kubeconfig based on it. [^1]

    1. Register the Cluster: Use the `sveltosctl register cluster` pointing it to the Sveltos management cluster. Provide the following options:
        - `--namespace=<namespace>`: Namespace in the management cluster where Sveltos will store information about the registered cluster.
        - `--cluster=<cluster name>`: A chosen name to identify the registered cluster within Sveltos.
        - `--kubeconfig=<path to file with Kubeconfig>`: Path to the kubeconfig file generated in step 1.
        - `--labels=<key1=value1,key2=value2>` (Optional): Comma-separated key-value pairs to define labels for the registered cluster (e.g., --labels=environment=production,tier=backend).


    **Registration Example**

    Pointing to the **managed** cluster (Generate kubeconfig with ServiceAccount creation):

    ```$ sveltosctl generate kubeconfig --create > ~/.kube/prod-cluster.config```

    Pointing to the **management** cluster (Register the cluster):

    ```
    $ sveltosctl register cluster \
        --namespace=monitoring \
        --cluster=prod-cluster \
        --kubeconfig=~/.kube/prod-cluster.config \
        --labels=environment=production,tier=backend
    ```

    The example will register a cluster (i.e, creates a SveltosCluster instance) named *prod-cluster* in the *monitoring* namespace with the labels set to "environment=production" and "tier=backend".

    If later on you want to change the labels assigned to the cluster, use the kubectl command below.

    ```$ kubectl edit sveltoscluster prod-cluster -n monitoring```

#### Registration Examples

??? example "EKS"
    Once an EKS cluster is created, perform the below steps.

    1. Retrieve the `kubeconfig` file with the AWS CLI.

        ```bash
        $ aws eks update-kubeconfig --region <the region the cluster created> --name <the name of the cluster>
        ```

    1. Generate Sveltos Relevant Kubeconfig
        ```bash
        $ export KUBECONFIG=<directory of the EKS kubeconfig file>
        $ sveltosctl generate kubeconfig --create --expirationSeconds=86400 > eks_kubeconfig.yaml
        ```
    1. Register EKS with Sveltos

        ```bash
        $ export KUBECONFIG=<Sveltos management cluster>
        $ sveltosctl register cluster --namespace=<namespace> --cluster=<cluster name> \
            --kubeconfig=<path to Sveltos file with Kubeconfig> \
            --labels=env=test
        ```

    !!!tip
        For Step #2, Sveltos will have **cluster-admin** privileges to the cluster.

??? example "GKE"
    1. Pointing to GKE cluster, run *sveltosctl generate kubeconfig --create --expirationSeconds=86400*
    1. Run *sveltosctl register cluster* command pointing it to the kubeconfig file generated by the step above.

    !!!tip
        Step #1 gives Sveltos cluster-admin privileges (that is done because we do not know in advance which add-ons we want Sveltos to deploy). We might choose to give Sveltos fewer privileges. Just keep in mind it needs enough privileges to deploy the add-ons you request to deploy.

??? example "Rancher RKE2"
    If you use Rancher's next-generation Kubernetes distribution [RKE2](https://docs.rke2.io/), you will only need to download the kubeconfig either from the Rancher UI under the Cluster Management section or via SSH into the RKE2 Cluster and under the */etc/rancher/rke2/rke2.yaml* directory. Run the below command.

    ```
    $ sveltosctl register cluster \
        --namespace=<namespace> \
        --cluster=<cluster name> \
        --kubeconfig=<path to file with Kubeconfig> \
        --labels=env=test
    ```

    If you use a kubeconfig downloaded from Rancher upstream cluster it will expire in 30 days ( this is by default if expiration time is not modified ). 
    To overcome this limit can be enabled token-renewal feature to continue managing downstream clusters without interruptions.

    After enabling token-renewal feature on cluster-profiles, it must be also enabled JWT Authentication on Rancher upstream cluster for managed downstream clusters to allow dedicated serviceaccount authentication [JWT Authentication on Rancher](https://ranchermanager.docs.rancher.com/how-to-guides/new-user-guides/authentication-permissions-and-global-configuration/jwt-authentication).
    
??? example "Civo"
    If you use [Civo Cloud](https://www.civo.com), simply download the cluster Kubeconfig and perform the below.

    ```
    $ sveltosctl register cluster \
        --namespace=<namespace> \
        --cluster=<cluster name> \
        --kubeconfig=<path to file with Kubeconfig> \
        --labels=env=test
    ```

??? example "Kamaji"
    If you use the **Hosted Control Plane** solution [Kamaji](https://kamaji.clastix.io/), follow steps below below to perform a tenant cluster registration with Sveltos.

    1. Point the kubeconfig to the Kamaji Management Cluster
        ```bash
        $ export KUBECONFIG=~/demo/kamaji/kubeconfig/kamaji-admin.kubeconfig
        ```
    2. Check the secrets in the namespace the tenant cluster was created
        ```bash
        $ kubectl get secrets -n {your namespace}
        ```
    3. Look for the secret with the following name format `<tenant_name>-admin-kubeconfig`
    4. Get and decode the secret to a file of your preference
        ```bash
        $ kubectl get secrets -n {your namespace} <tenant_name>-admin-kubeconfig -o json \
        | jq -r '.data["admin.conf"]' \
        | base64 --decode \
        > <path to file with kubeconfig>/<tenant_name>-admin.kubeconfig
        ```
    5. Perform a Sveltos registration
        ```bash
        $ sveltosctl register cluster \
            --namespace=<namespace> \
            --cluster=<cluster name> \
            --kubeconfig=<path to file with kubeconfig> \
            --labels=key1=value1,key2=value2
        ```
        Example
        ```bash
        $ sveltosctl register cluster \
            --namespace=projectsveltos \
            --cluster=tenant-00 \
            --kubeconfig=~/demo/kamaji/kubeconfig/tenant-00-admin.kubeconfig \
            --labels=tcp=tenant-00
        ```

??? example "vCluster"
    If you use [vCluster](https://www.vcluster.com/) with **Helm** for multi-tenancy, follow the steps below to perform a cluster registration with Sveltos.

    1. Point the kubeconfig to the parent Kubernetes cluster
        ```bash
        $ export KUBECONFIG=~/demo/vcluster/multi-tenant/kubeconfig/demo01.yaml
        ```
    1. Check the secrets in the namespace the virtual cluster was created
        ```bash
        $ kubectl get secrets -n {your namespace}
        ```
    1. Look for the secret with the following name format `vc-<vcluster name>`
    1. Get and decode the secret to a file of your preference
        ```bash
        $ kubectl get secret vc-vcluster-dev -n dev --template={{.data.config}} | base64 -d > ~/demo/vcluster/multi-tenant/kubeconfig/vcluster-dev.yaml
        ```
    1. Perform a Sveltos registration
        ```bash
        $ sveltosctl register cluster \
            --namespace=<namespace> \
            --cluster=<cluster name> \
            --kubeconfig=<path to file with Kubeconfig> \
            --labels=key1=value1,key2=value2
        ```
        Example
        ```bash
        $ sveltosctl register cluster \
            --namespace=projectsveltos \
            --cluster=vcluster-dev \
            --kubeconfig=~/demo/vcluster/multi-tenant/kubeconfig/vcluster-dev.yaml \
            --labels=env=dev
        ```

### Programmatic Registration

To programmatically register clusters with Sveltos, create the below resources in the **management** cluster.

- **Secret**: Store the kubeconfig of the **managed** cluster in the data section under the key `kubeconfig`.
- **SveltosCluster**: Represent your cluster as an `SveltosCluster` instance.

By default, Sveltos searches for a `Secret` named `<cluster-name>-sveltos-kubeconfig` in the **same namespace as the SveltosCluster**. To use a different Secret name, set the __SveltosCluster.Spec.KubeconfigName__ field to the desired name.

??? example "Kubernetes Resources Example"
    **Secret Resource**
    ```yaml hl_lines="4-5 7"
    apiVersion: v1
    kind: Secret
    metadata:
      name: YOUR-CLUSTER-NAME-sveltos-kubeconfig
      namespace: YOUR-CLUSTER-NAMESPACE
    data:
      kubeconfig: BASE64 ENCODED kubeconfig
    type: Opaque
    ```
    **SveltosCluster Resource**
    ```yaml hl_lines="2 4-5"
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: SveltosCluster
    metadata:
      name: YOUR-CLUSTER-NAME
      namespace: YOUR-CLUSTER-NAMESPACE
      labels:
        foo: bar
        sveltos-agent: present
    ```

!!!tip
    To get an idea on how an already registered cluster looks like, check out the Sveltos `mgmt` cluster using the command ```kubectl get sveltoscluster mgmt -n mgmt -o yaml```.

## Register Management Cluster

Sveltos manages add-ons not only on **managed** clusters but also on the **management** clusters. The management cluster is the Kubernetes cluster where Sveltos is deployed. To enable add-ons there, apply the labels of your choice. The Sveltos management cluster is registered in the `mgmt` namespace under the name `mgmt`.


```bash
$  kubectl get sveltoscluster -A --show-labels
NAMESPACE    NAME         READY   VERSION        AGE   LABELS
mgmt         mgmt         true    v1.32.6+k3s1   24h   projectsveltos.io/k8s-version=v1.32.6,sveltos-agent=present
```

```bash
$ kubectl label sveltoscluster mgmt -n mgmt cluster=mgmt
```

For a Helm chart installation, have a look at the Helm chart [values](https://artifacthub.io/packages/helm/sveltos/projectsveltos?modal=values&path=registerMgmtCluster) to include the labels of your choice.

[^1]:
    As an alternative to generate kubeconfig have a look at the [script: get-kubeconfig.sh](https://raw.githubusercontent.com/gianlucam76/scripts/master/get-kubeconfig.sh). Read the script comments to get more clarity on the use and expected outcomes. This script was developed by [Gravitational Teleport](https://github.com/gravitational/teleport/blob/master/examples/k8s-auth/get-kubeconfig.sh). We simply slightly modified to fit Sveltos use case.
[^2]:
    To manage add-ons and deployments on the **management cluster**, by default, Sveltos automatically registers the cluster as `mgmt` in the `mgmt` namespace. Follow the standard Sveltos label concept to mark it for deployments.
