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

## Register a Cluster

Use `sveltosctl register cluster` with `--workload-identity-provider` and the provider-specific flags.

### Common flags

| Flag | Description |
|------|-------------|
| `--workload-identity-provider` | Cloud provider. One of `aws`, `gcp`, `azure`. |
| `--workload-identity-endpoint` | API server URL of the managed cluster (e.g. `https://...`). Required. |
| `--workload-identity-ca-file` | Path to the CA certificate for the managed cluster API server. When provided, sveltosctl creates a `<cluster>-sveltos-ca` Secret and references it in the SveltosCluster. |

!!! note
    `--workload-identity-provider` is mutually exclusive with `--kubeconfig` and `--fleet-cluster-context`.

### AWS (EKS)

```bash
$ sveltosctl register cluster \
  --namespace=<namespace> \
  --cluster=<cluster-name> \
  --workload-identity-provider=aws \
  --workload-identity-endpoint=<eks-api-server-url> \
  --workload-identity-ca-file=/tmp/managed-ca.crt \
  --aws-cluster-name=<eks-cluster-name>
```

| Flag | Required | Description |
|------|----------|-------------|
| `--aws-cluster-name` | Yes | EKS cluster name. Embedded in the bearer token so the API server can identify the target cluster. |
| `--aws-role-arn` | No | IAM role ARN to assume before generating the token. If omitted, the pod's own IRSA role is used directly. |
| `--aws-region` | No | AWS region of the EKS cluster. Defaults to the `AWS_REGION` environment variable injected by IRSA. |

### GCP (GKE)

```bash
$ sveltosctl register cluster \
  --namespace=<namespace> \
  --cluster=<cluster-name> \
  --workload-identity-provider=gcp \
  --workload-identity-endpoint=https://<endpoint> \
  --workload-identity-ca-file=/tmp/ca.crt \
  --gcp-project-id=<project-id> \
  --gcp-cluster-name=<gke-cluster-name> \
  --gcp-location=<region-or-zone>
```

| Flag | Required | Description |
|------|----------|-------------|
| `--gcp-project-id` | Yes | GCP project ID. |
| `--gcp-cluster-name` | Yes | GKE cluster name. |
| `--gcp-location` | Yes | GCP region or zone (e.g. `us-central1-a`). |

### Azure (AKS)

```bash
$ sveltosctl register cluster \
  --namespace=<namespace> \
  --cluster=<cluster-name> \
  --workload-identity-provider=azure \
  --workload-identity-endpoint=https://<aks-api-server> \
  --azure-tenant-id=<tenant-id> \
  --azure-client-id=<client-id>
```

| Flag | Required | Description |
|------|----------|-------------|
| `--azure-tenant-id` | Yes | Azure AD tenant ID. |
| `--azure-client-id` | Yes | Client ID of the managed identity or app registration federated with the management cluster service account. |
| `--azure-subscription-id` | No | Azure subscription containing the AKS cluster. |
| `--azure-resource-group` | No | Resource group containing the AKS cluster. |
| `--azure-cluster-name` | No | AKS cluster name. |

## Deregister a Cluster

```bash
$ sveltosctl deregister cluster \
  --namespace=<namespace> \
  --cluster=<cluster-name>
```

This deletes the SveltosCluster and the `<cluster>-sveltos-ca` Secret if one was created.

## End-to-end Setup Guides

The guides below walk through the full cloud-side setup required before running `sveltosctl register cluster`.

!!! note
    These guides show one specific way we configured each cloud provider. They are not the only valid approach. If you already know how to set up IRSA, GKE Workload Identity, or Azure federated credentials for a Kubernetes workload, you can skip straight to the `sveltosctl register cluster` command above — the cloud setup only needs to end with the management cluster pod having permission to call the managed cluster's API server.

??? example "EKS — IRSA-based workload identity"

    Both the management cluster and the managed cluster are EKS clusters in the
    same AWS account.

    **Variables**

    ```bash
    $ export ACCOUNT_ID=<aws-account-id>
    $ export REGION=us-east-1
    $ export MGMT_CLUSTER=sveltos-mgmt
    $ export MANAGED_CLUSTER=sveltos-managed
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

    **Step 4 — Create an IAM role for the sc-manager pod**

    The `sc-manager` deployment uses the Kubernetes service account `sc-manager`
    in namespace `projectsveltos`.

    ```bash
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
              "oidc.eks.${REGION}.amazonaws.com/id/${OIDC_ID}:sub": "system:serviceaccount:projectsveltos:sc-manager",
              "oidc.eks.${REGION}.amazonaws.com/id/${OIDC_ID}:aud": "sts.amazonaws.com"
            }
          }
        }
      ]
    }
    EOF

    $ aws iam create-role \
      --role-name sveltos-sc-manager \
      --assume-role-policy-document file:///tmp/trust-policy.json
    ```

    **Step 5 — Annotate the sc-manager service account**

    ```bash
    $ kubectl annotate serviceaccount sc-manager \
      -n projectsveltos \
      eks.amazonaws.com/role-arn=arn:aws:iam::${ACCOUNT_ID}:role/sveltos-sc-manager

    $ kubectl rollout restart deployment sc-manager -n projectsveltos
    ```

    Verify IRSA environment variables are injected:

    ```bash
    $ kubectl describe pod -n projectsveltos -l app=sc-manager | grep "AWS_ROLE_ARN\|AWS_WEB_IDENTITY_TOKEN_FILE"
    ```

    **Step 6 — Grant the IAM role access to the managed cluster**

    ```bash
    $ aws eks create-access-entry \
      --cluster-name ${MANAGED_CLUSTER} \
      --principal-arn arn:aws:iam::${ACCOUNT_ID}:role/sveltos-sc-manager \
      --region ${REGION}

    $ aws eks associate-access-policy \
      --cluster-name ${MANAGED_CLUSTER} \
      --principal-arn arn:aws:iam::${ACCOUNT_ID}:role/sveltos-sc-manager \
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
    $ sveltosctl register cluster \
      --namespace=projectsveltos \
      --cluster=eks-managed \
      --workload-identity-provider=aws \
      --workload-identity-endpoint=${ENDPOINT} \
      --workload-identity-ca-file=/tmp/managed-ca.crt \
      --aws-cluster-name=${MANAGED_CLUSTER}
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
      --principal-arn arn:aws:iam::${ACCOUNT_ID}:role/sveltos-sc-manager \
      --region ${REGION}
    ```

    *OIDC provider missing*: `aws iam list-open-id-connect-providers` returns an empty list. Re-run step 3.

    *Cluster created as root*: Only the creating IAM entity has access by default. Delete and recreate the cluster as your IAM user, or add the IAM user via an EKS access entry using root credentials.

    *AWS_REGION not set*: `--aws-region` is optional and falls back to the `AWS_REGION` environment variable injected by IRSA. Set it explicitly in the flag if you see a region error.

??? example "GKE — Workload Identity"

    Both the management cluster and the managed cluster are GKE clusters in the
    same GCP project.

    **Variables**

    ```bash
    $ export PROJECT=<project-id>
    $ export MGMT_CLUSTER=cluster-mgmt
    $ export MANAGED_CLUSTER=cluster-managed
    $ export ZONE=us-central1-a
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

    **Step 6 — Link the Kubernetes service account to the GSA**

    ```bash
    $ gcloud iam service-accounts add-iam-policy-binding \
      sveltos-wi@${PROJECT}.iam.gserviceaccount.com \
      --role=roles/iam.workloadIdentityUser \
      --member="serviceAccount:${PROJECT}.svc.id.goog[projectsveltos/sc-manager]" \
      --project=${PROJECT}

    $ kubectl annotate serviceaccount sc-manager \
      -n projectsveltos \
      iam.gke.io/gcp-service-account=sveltos-wi@${PROJECT}.iam.gserviceaccount.com

    $ kubectl rollout restart deployment sveltoscluster-manager -n projectsveltos
    ```

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
    $ sveltosctl register cluster \
      --namespace=projectsveltos \
      --cluster=gke-managed \
      --workload-identity-provider=gcp \
      --workload-identity-endpoint=https://${ENDPOINT} \
      --workload-identity-ca-file=/tmp/ca.crt \
      --gcp-project-id=${PROJECT} \
      --gcp-cluster-name=${MANAGED_CLUSTER} \
      --gcp-location=${ZONE}
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
