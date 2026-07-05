---
title: Workload Identity Registration
description: Register managed clusters with Sveltos using cloud provider workload identity (GKE, EKS, AKS) — no static kubeconfig required.
tags:
    - Kubernetes
    - add-ons
    - helm
    - multi-tenancy
    - workload-identity
    - GKE
    - EKS
    - AKS
authors:
    - Gianluca Mardente
---

## Workload Identity Registration

Standard Sveltos cluster registration stores a long-lived kubeconfig in a Kubernetes Secret. With Workload Identity registration we remove that requirement. Sveltos obtains short-lived credentials from the cloud provider at runtime, using the management cluster pod's own identity.

This approach works when:

- The management and the managed clusters are in the same cloud account or project.
- The management cluster runs with a cloud provider identity (GKE Workload Identity, AWS IRSA, or Azure Workload Identity).

No kubeconfig `Secret` is stored in the Sveltos management cluster. The credentials are refreshed automatically when they expire.

!!!note
    Workload Identity registration requires Sveltos **v1.12.0** or later.

## Which Service Accounts Need the Cloud Identity Annotation

Only the Sveltos components that talk to managed clusters need the cloud provider's workload identity annotation on their ServiceAccount:

- `access-manager`
- `addon-controller`
- `event-manager`
- `hc-manager`
- `sc-manager`
- `techsupport-controller`
- `mcp-server`
- `drift-detection-manager` and `sveltos-agent-manager`, but only when Sveltos runs in agentless mode (`agent.managementCluster: true` in the Helm chart)

!!! tip "Preferred: set the annotation once via Helm"
    If Sveltos is installed with the `projectsveltos` Helm chart, set `global.serviceAccountAnnotations` instead of annotating each ServiceAccount by hand. The value is merged into every ServiceAccount listed above, and a component-specific `<component>.serviceAccount.annotations` still takes precedence on key collisions:

    ```yaml
    # values.yaml
    global:
      serviceAccountAnnotations:
        iam.gke.io/gcp-service-account: sveltos-wi@<project>.iam.gserviceaccount.com   # GKE
        # eks.amazonaws.com/role-arn: arn:aws:iam::<account-id>:role/sveltos-wi        # EKS
        # azure.workload.identity/client-id: <client-id>                              # AKS
    ```

    ```bash
    $ helm upgrade --install projectsveltos projectsveltos/projectsveltos \
      -n projectsveltos --create-namespace \
      -f values.yaml
    ```

    The manual `kubectl annotate serviceaccount` steps in the guides below still work, and are the only option for installs that don't use the Helm chart.

## Register a Cluster

When using workload identity, each cloud provider has a dedicated subcommand: `register cluster-eks` for Amazon EKS, `register cluster-gke` for Google GKE, and `register cluster-aks` for Azure AKS. If you are registering a cluster with a kubeconfig, use `register cluster` instead.

### AWS (EKS)

```bash
$ sveltosctl register cluster-eks \
  --namespace=<namespace> \
  --cluster=<cluster-name> \
  --endpoint=<eks-api-server-url> \
  --eks-cluster-name=<eks-cluster-name> \
  --ca-file=/tmp/managed-ca.crt
```

| Flag | Required | Description |
|------|----------|-------------|
| `--endpoint` | Yes | API server URL of the EKS cluster (e.g. `https://...`). |
| `--eks-cluster-name` | Yes | EKS cluster name. Embedded in the bearer token so the API server can identify the target cluster. |
| `--ca-file` | No | Path to the CA certificate for the EKS API server. When provided, sveltosctl creates a `<cluster>-sveltos-ca` Secret and references it in the SveltosCluster. |
| `--role-arn` | No | IAM role ARN to assume before generating the token. If omitted, the pod's own IRSA role is used directly. |
| `--region` | No | AWS region of the EKS cluster. Defaults to the `AWS_REGION` environment variable injected by IRSA. |

### GCP (GKE)

```bash
$ sveltosctl register cluster-gke \
  --namespace=<namespace> \
  --cluster=<cluster-name> \
  --endpoint=https://<endpoint> \
  --project-id=<project-id> \
  --gke-cluster-name=<gke-cluster-name> \
  --location=<region-or-zone> \
  --ca-file=/tmp/ca.crt
```

| Flag | Required | Description |
|------|----------|-------------|
| `--endpoint` | Yes | API server URL of the GKE cluster (e.g. `https://34.x.x.x`). |
| `--project-id` | Yes | GCP project ID. |
| `--gke-cluster-name` | Yes | GKE cluster name. |
| `--location` | Yes | GCP region or zone (e.g. `us-central1-a`). |
| `--ca-file` | No | Path to the CA certificate for the GKE API server. |

### Azure (AKS)

```bash
$ sveltosctl register cluster-aks \
  --namespace=<namespace> \
  --cluster=<cluster-name> \
  --endpoint=https://<aks-api-server> \
  --tenant-id=<tenant-id> \
  --client-id=<client-id>
```

| Flag | Required | Description |
|------|----------|-------------|
| `--endpoint` | Yes | API server URL of the AKS cluster (e.g. `https://my-aks.hcp.eastus.azmk8s.io`). |
| `--tenant-id` | Yes | Azure AD tenant ID. |
| `--client-id` | Yes | Client ID of the managed identity or app registration federated with the management cluster service account. |
| `--ca-file` | No | Path to the CA certificate for the AKS API server. |
| `--subscription-id` | No | Azure subscription containing the AKS cluster. |
| `--resource-group` | No | Resource group containing the AKS cluster. |
| `--aks-cluster-name` | No | AKS cluster name. |

## Deregister a Cluster

```bash
$ sveltosctl deregister cluster \
  --namespace=<namespace> \
  --cluster=<cluster-name>
```

This deletes the SveltosCluster and the `<cluster>-sveltos-ca` Secret if one was created.

## End-to-end Setup Guides

The guides below walk through the full cloud-side setup required before running the registration command.

!!! note
    These guides show one specific way we configured each cloud provider. They are not the only valid approach. If you already know how to set up IRSA, GKE Workload Identity, or Azure federated credentials for a Kubernetes workload, you can skip straight to the `sveltosctl register cluster-eks/cluster-gke/cluster-aks` command above. The cloud setup only needs to end with the management cluster pod having permission to call the managed cluster's API server.

??? example "EKS — IRSA-based workload identity"

    Both the management cluster and the managed cluster are EKS clusters in the
    same AWS account.

    **Variables**

    ```bash
    $ export ACCOUNT_ID=<aws-account-id>
    $ export REGION=us-east-1
    $ export MGMT_CLUSTER=sveltos-mgmt
    $ export MANAGED_CLUSTER=sveltos-managed
    $ export SERVICE_ACCOUNTS="access-manager addon-controller event-manager hc-manager sc-manager techsupport-controller mcp-server"
    # Agentless mode (agent.managementCluster: true)? drift-detection-manager and sveltos-agent-manager need access too:
    # $ export SERVICE_ACCOUNTS="${SERVICE_ACCOUNTS} drift-detection-manager sveltos-agent-manager"
    ```

    **Step 1 — Create clusters as an IAM user (not root)**

    EKS grants cluster admin access to the IAM entity that creates the cluster.
    Root-created clusters cannot be accessed by IAM users without extra configuration.

    ```bash
    $ eksctl create cluster --name ${MGMT_CLUSTER} --region ${REGION} --nodes 2
    $ eksctl create cluster --name ${MANAGED_CLUSTER} --region ${REGION} --nodes 1
    ```

    **Step 2 — Install Sveltos on the management cluster**

    ```bash
    $ aws eks update-kubeconfig --name ${MGMT_CLUSTER} --region ${REGION}
    $ kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/manifest.yaml
    $ kubectl get pods -n projectsveltos
    ```

    **Step 3 — Associate the OIDC provider**

    `eksctl` does not register the OIDC provider automatically.

    ```bash
    $ eksctl utils associate-iam-oidc-provider \
      --cluster ${MGMT_CLUSTER} --region ${REGION} --approve

    $ export OIDC_ID=$(aws eks describe-cluster --name ${MGMT_CLUSTER} --region ${REGION} \
      --query "cluster.identity.oidc.issuer" --output text | awk -F'/' '{print $NF}')
    ```

    **Step 4 — Create an IAM role trusted by every Sveltos service account**

    One IAM role is shared by all the service accounts in `SERVICE_ACCOUNTS`
    (all in namespace `projectsveltos`). The trust policy's `sub` condition
    lists one entry per service account.

    ```bash
    $ SUBS=""
    $ for sa in ${SERVICE_ACCOUNTS}; do
        SUBS="${SUBS}\"system:serviceaccount:projectsveltos:${sa}\","
      done
    $ SUBS="[${SUBS%,}]"

    $ cat > /tmp/trust-policy.json << EOF
    {
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/oidc.eks.${REGION}.amazonaws.com/id/${OIDC_ID}"
          },
          "Action": "sts:AssumeRoleWithWebIdentity",
          "Condition": {
            "StringEquals": {
              "oidc.eks.${REGION}.amazonaws.com/id/${OIDC_ID}:aud": "sts.amazonaws.com"
            },
            "ForAnyValue:StringEquals": {
              "oidc.eks.${REGION}.amazonaws.com/id/${OIDC_ID}:sub": ${SUBS}
            }
          }
        }
      ]
    }
    EOF

    $ aws iam create-role \
      --role-name sveltos-wi \
      --assume-role-policy-document file:///tmp/trust-policy.json
    ```

    **Step 5 — Annotate every service account**

    ```bash
    $ for sa in ${SERVICE_ACCOUNTS}; do
        kubectl annotate serviceaccount ${sa} -n projectsveltos \
          eks.amazonaws.com/role-arn=arn:aws:iam::${ACCOUNT_ID}:role/sveltos-wi --overwrite
      done

    $ kubectl rollout restart deployment -n projectsveltos \
      access-manager addon-controller event-manager hc-manager sc-manager techsupport-controller mcp-server
    ```

    `drift-detection-manager` and `sveltos-agent-manager` (agentless mode) are not
    static Deployments — Sveltos (re)creates their pods on demand, so no rollout
    restart is needed for them; the annotation is picked up the next time a pod is created.

    Verify IRSA environment variables are injected, e.g. for `sc-manager`:

    ```bash
    $ kubectl describe pod -n projectsveltos -l app=sc-manager | grep "AWS_ROLE_ARN\|AWS_WEB_IDENTITY_TOKEN_FILE"
    ```

    **Step 6 — Grant the IAM role access to the managed cluster**

    ```bash
    $ aws eks create-access-entry \
      --cluster-name ${MANAGED_CLUSTER} \
      --principal-arn arn:aws:iam::${ACCOUNT_ID}:role/sveltos-wi \
      --region ${REGION}

    $ aws eks associate-access-policy \
      --cluster-name ${MANAGED_CLUSTER} \
      --principal-arn arn:aws:iam::${ACCOUNT_ID}:role/sveltos-wi \
      --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
      --access-scope type=cluster \
      --region ${REGION}
    ```

    **Step 7 — Get the managed cluster endpoint and CA certificate**

    ```bash
    $ export ENDPOINT=$(aws eks describe-cluster --name ${MANAGED_CLUSTER} --region ${REGION} \
      --query "cluster.endpoint" --output text)

    $ aws eks describe-cluster --name ${MANAGED_CLUSTER} --region ${REGION} \
      --query "cluster.certificateAuthority.data" --output text \
      | base64 --decode > /tmp/managed-ca.crt
    ```

    **Step 8 — Register the managed cluster**

    ```bash
    $ sveltosctl register cluster-eks \
      --namespace=projectsveltos \
      --cluster=eks-managed \
      --endpoint=${ENDPOINT} \
      --eks-cluster-name=${MANAGED_CLUSTER} \
      --ca-file=/tmp/managed-ca.crt
    ```

    **Step 9 — Verify**

    ```bash
    $ kubectl get sveltoscluster eks-managed -n projectsveltos
    ```

    `READY` should become `true` within a few seconds.

    **Troubleshooting**

    *"the server has asked for the client to provide credentials"*: Verify the access entry and policy association:

    ```bash
    $ aws eks list-associated-access-policies \
      --cluster-name ${MANAGED_CLUSTER} \
      --principal-arn arn:aws:iam::${ACCOUNT_ID}:role/sveltos-wi \
      --region ${REGION}
    ```

    *OIDC provider missing*: `aws iam list-open-id-connect-providers` returns an empty list. Re-run step 3.

    *Cluster created as root*: Only the creating IAM entity has access by default. Delete and recreate the cluster as your IAM user, or add the IAM user via an EKS access entry using root credentials.

    *AWS_REGION not set*: `--region` is optional and falls back to the `AWS_REGION` environment variable injected by IRSA. Set it explicitly in the flag if you see a region error.

??? example "GKE — Workload Identity"

    Both the management cluster and the managed cluster are GKE clusters in the
    same GCP project.

    **Variables**

    ```bash
    $ export PROJECT=<project-id>
    $ export MGMT_CLUSTER=cluster-mgmt
    $ export MANAGED_CLUSTER=cluster-managed
    $ export ZONE=us-central1-a
    $ export SERVICE_ACCOUNTS="access-manager addon-controller event-manager hc-manager sc-manager techsupport-controller mcp-server"
    # Agentless mode (agent.managementCluster: true)? drift-detection-manager and sveltos-agent-manager need access too:
    # $ export SERVICE_ACCOUNTS="${SERVICE_ACCOUNTS} drift-detection-manager sveltos-agent-manager"
    ```

    **Step 1 — Create clusters**

    ```bash
    $ gcloud container clusters create ${MGMT_CLUSTER} \
      --zone=${ZONE} --project=${PROJECT}

    $ gcloud container clusters create ${MANAGED_CLUSTER} \
      --zone=${ZONE} --project=${PROJECT}
    ```

    **Step 2 — Enable Workload Identity on the management cluster**

    ```bash
    $ gcloud container clusters update ${MGMT_CLUSTER} \
      --workload-pool=${PROJECT}.svc.id.goog \
      --zone=${ZONE} --project=${PROJECT}
    ```

    **Step 3 — Enable GKE_METADATA on the management node pool**

    Without this, pods cannot use Workload Identity even when the cluster has it enabled.

    ```bash
    $ gcloud container node-pools update default-pool \
      --cluster=${MGMT_CLUSTER} \
      --zone=${ZONE} --project=${PROJECT} \
      --workload-metadata=GKE_METADATA
    ```

    Wait for node rotation to complete:

    ```bash
    $ gcloud container node-pools describe default-pool \
      --cluster=${MGMT_CLUSTER} --zone=${ZONE} --project=${PROJECT} \
      --format='value(config.workloadMetadataConfig.mode)'
    # should print: GKE_METADATA
    ```

    **Step 4 — Install Sveltos on the management cluster**

    ```bash
    $ gcloud container clusters get-credentials ${MGMT_CLUSTER} \
      --zone=${ZONE} --project=${PROJECT}

    $ kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/manifest.yaml
    ```

    **Step 5 — Create a Google Service Account for Sveltos**

    ```bash
    $ gcloud iam service-accounts create sveltos-wi --project=${PROJECT}
    ```

    **Step 6 — Link every Kubernetes service account to the GSA**

    ```bash
    $ for sa in ${SERVICE_ACCOUNTS}; do
        gcloud iam service-accounts add-iam-policy-binding \
          sveltos-wi@${PROJECT}.iam.gserviceaccount.com \
          --role=roles/iam.workloadIdentityUser \
          --member="serviceAccount:${PROJECT}.svc.id.goog[projectsveltos/${sa}]" \
          --project=${PROJECT}

        kubectl annotate serviceaccount ${sa} \
          -n projectsveltos \
          iam.gke.io/gcp-service-account=sveltos-wi@${PROJECT}.iam.gserviceaccount.com --overwrite
      done

    $ kubectl rollout restart deployment -n projectsveltos \
      access-manager addon-controller event-manager hc-manager sc-manager techsupport-controller mcp-server
    ```

    `drift-detection-manager` and `sveltos-agent-manager` (agentless mode) are not
    static Deployments — Sveltos (re)creates their pods on demand, so no rollout
    restart is needed for them; the annotation is picked up the next time a pod is created.

    **Step 7 — Grant the GSA access to the managed cluster**

    ```bash
    $ gcloud projects add-iam-policy-binding ${PROJECT} \
      --member=serviceAccount:sveltos-wi@${PROJECT}.iam.gserviceaccount.com \
      --role=roles/container.admin
    ```

    **Step 8 — Get the managed cluster endpoint and CA certificate**

    ```bash
    $ export ENDPOINT=$(gcloud container clusters describe ${MANAGED_CLUSTER} \
      --zone=${ZONE} --project=${PROJECT} \
      --format='value(endpoint)')

    $ gcloud container clusters describe ${MANAGED_CLUSTER} \
      --zone=${ZONE} --project=${PROJECT} \
      --format='value(masterAuth.clusterCaCertificate)' \
      | base64 --decode > /tmp/ca.crt
    ```

    **Step 9 — Register the managed cluster**

    ```bash
    $ sveltosctl register cluster-gke \
      --namespace=projectsveltos \
      --cluster=gke-managed \
      --endpoint=https://${ENDPOINT} \
      --project-id=${PROJECT} \
      --gke-cluster-name=${MANAGED_CLUSTER} \
      --location=${ZONE} \
      --ca-file=/tmp/ca.crt
    ```

    **Step 10 — Verify**

    ```bash
    $ kubectl get sveltoscluster gke-managed -n projectsveltos
    ```

    `READY` should become `true` within a few seconds.

    **Troubleshooting**

    *"the server has asked for the client to provide credentials"*: The node pool is not using `GKE_METADATA` mode. Run step 3 and wait for node rotation to complete, then restart the sc-manager pod.

    *`PROJECT` is empty*: Shell variables are lost between sessions. Re-export them before running any `gcloud` commands.

## Programmatic Registration

To create the resources in a programmatic manner, apply a `SveltosCluster` with `spec.workloadIdentity` set.

=== "AWS (EKS)"
    ```yaml
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: SveltosCluster
    metadata:
      name: eks-managed
      namespace: projectsveltos
    spec:
      workloadIdentity:
        provider: AWS
        endpoint: "https://<eks-api-server>"
        caSecretRef:
          name: eks-managed-ca   # Secret with key ca.crt
        aws:
          clusterName: sveltos-managed
          # region: us-east-1    # optional; defaults to AWS_REGION env var
          # roleARN: arn:aws:iam::123456789012:role/my-role  # optional
    ```

=== "GCP (GKE)"
    ```yaml
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: SveltosCluster
    metadata:
      name: gke-managed
      namespace: projectsveltos
    spec:
      workloadIdentity:
        provider: GCP
        endpoint: "https://<gke-endpoint>"
        caSecretRef:
          name: gke-managed-ca   # Secret with key ca.crt
        gcp:
          projectID: <project-id>
          clusterName: cluster-managed
          location: us-central1-a
    ```

=== "Azure (AKS)"
    ```yaml
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: SveltosCluster
    metadata:
      name: aks-managed
      namespace: projectsveltos
    spec:
      workloadIdentity:
        provider: Azure
        endpoint: "https://<aks-api-server>"
        azure:
          tenantID: <tenant-id>
          clientID: <client-id>
          # subscriptionID, resourceGroup, clusterName are optional
    ```

The CA Secret referenced by `caSecretRef` must contain a `ca.crt` key:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: eks-managed-ca
  namespace: projectsveltos
data:
  ca.crt: <base64-encoded-CA-certificate>
```
