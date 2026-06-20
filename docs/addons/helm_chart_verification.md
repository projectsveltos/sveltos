---
title: Sveltos - Helm Chart Supply Chain Verification
description: Sveltos can verify the integrity and origin of a Helm chart before deploying it, using Cosign signature verification for OCI charts and GPG provenance verification for HTTP charts.
tags:
    - Kubernetes
    - add-ons
    - helm
    - cosign
    - supply chain
    - security
authors:
    - Gianluca Mardente
---

## Helm Chart Supply Chain Verification

Before deploying a Helm chart, Sveltos can verify that it was signed by a trusted source and that its contents have not been modified. Two mechanisms are supported depending on where the chart is hosted.

| Chart source | Verification mechanism |
|---|---|
| OCI registry (`oci://`) | Cosign signature verification |
| HTTP repository (`https://`) | Helm GPG provenance (`.prov`) verification |

If verification fails the chart is not deployed and the failure reason is recorded on the [`ClusterSummary`](https://projectsveltos.io/main/internals/cr-ownership/#clusterprofileprofile-clustersummary) status. Charts without a verification field deploy as before.

---

## Cosign Signature Verification (OCI charts)

When a chart is pulled from an OCI registry, Sveltos can verify its Cosign signature. Two providers are available:  **Keyless** for charts signed by a CI pipeline using short-lived OIDC certificates and **PublicKey** for charts signed with a static key pair.

### Keyless Provider

Keyless signing is used when a CI system such as GitHub Actions signs the chart at release time. No long-lived key is involved. Instead, the signing identity is encoded in a short-lived certificate issued by Fulcio (part of the Sigstore public infrastructure) and recorded in the Rekor transparency log.

Sveltos verifies that the chart was signed by a certificate matching the expected OIDC issuer and subject before deploying it.

#### Example: Verify a Chart Signed by a GitHub Actions Workflow

The chart `registry-1.docker.io/gianlucam76/cosign-test:0.1.0` is a public chart signed by the GitHub Actions workflow at `https://github.com/gianlucam76/cosign-test`. You can use it to test keyless verification end to end.

!!! example ""
    ```yaml
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: cosign-keyless-example
    spec:
      clusterSelector:
        matchLabels:
          env: prod
      helmCharts:
      - repositoryURL:    oci://registry-1.docker.io/gianlucam76
        repositoryName:   cosign-test
        chartName:        cosign-test
        chartVersion:     0.1.0
        releaseName:      cosign-test
        releaseNamespace: cosign-test
        helmChartAction:  Install
        signatureVerification:
          provider: Keyless
          matchOIDCIdentity:
          - issuer: "^https://token.actions.githubusercontent.com$"
            subject: "^https://github.com/gianlucam76/cosign-test/.*$"
    ```

The `issuer` and `subject` fields are regular expressions. Sveltos verifies that at least one signature on the chart was issued by a certificate matching both. If the chart was signed by a different workflow or repository, the deployment is blocked.

To verify the same chart manually with the cosign CLI:

```bash
$ cosign verify registry-1.docker.io/gianlucam76/cosign-test:0.1.0 \
  --certificate-oidc-issuer="https://token.actions.githubusercontent.com" \
  --certificate-identity-regexp="https://github.com/gianlucam76/cosign-test"
```

#### Using Keyless Verification With Your Own Chart

To sign a chart from a GitHub Actions workflow and verify it with Sveltos:

**Step 1** — add a workflow that packages, pushes and signs the chart:

```yaml
# .github/workflows/publish.yaml
name: Publish

on:
  push:
    branches: [main]

permissions:
  id-token: write   # required for keyless OIDC signing
  contents: read

jobs:
  publish-and-sign:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: sigstore/cosign-installer@v3
      - uses: azure/setup-helm@v4

      - name: Log in to registry
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.REGISTRY_USERNAME }}
          password: ${{ secrets.REGISTRY_TOKEN }}

      - name: Package and push
        id: push
        run: |
          helm package charts/mychart
          DIGEST=$(helm push mychart-1.0.0.tgz oci://registry-1.docker.io/myorg 2>&1 \
            | grep '^Digest:' | awk '{print $2}')
          echo "digest=${DIGEST}" >> "$GITHUB_OUTPUT"

      - name: Sign
        env:
          REGISTRY_USERNAME: ${{ secrets.REGISTRY_USERNAME }}
          REGISTRY_TOKEN: ${{ secrets.REGISTRY_TOKEN }}
        run: |
          cosign sign --yes \
            --registry-username "${REGISTRY_USERNAME}" \
            --registry-password "${REGISTRY_TOKEN}" \
            registry-1.docker.io/myorg/mychart@${{ steps.push.outputs.digest }}
```

**Step 2** — reference the chart in a ClusterProfile:

```yaml
---
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: mychart
spec:
  clusterSelector:
    matchLabels:
      env: prod
  helmCharts:
  - repositoryURL:    oci://registry-1.docker.io/myorg
    repositoryName:   mychart
    chartName:        mychart
    chartVersion:     1.0.0
    releaseName:      mychart
    releaseNamespace: mychart
    helmChartAction:  Install
    signatureVerification:
      provider: Keyless
      matchOIDCIdentity:
      - issuer: "^https://token.actions.githubusercontent.com$"
        subject: "^https://github.com/myorg/myrepo/.*$"
```

!!! note
    The subject regexp should match the specific workflow path and branch you want to trust. Using `.*` at the end matches any branch and workflow file in the repository. Tighten it as needed, for example `^https://github.com/myorg/myrepo/.github/workflows/publish.yaml@refs/heads/main$` to trust only the main branch publish workflow.

---

### PublicKey Provider

The PublicKey provider verifies the signature against a static PEM-encoded public key stored in a Kubernetes Secret on the management cluster. No Sigstore transparency log or certificate authority is contacted. Verification uses only the public key and the signature stored in the OCI registry.

#### Step 1 — Generate Cosign Key Pair

```bash
$ cosign generate-key-pair
```

This creates `cosign.key` (private key, keep secret) and `cosign.pub` (public key).

#### Step 2 — Sign the Chart

```bash
# Push the chart to an OCI registry first
$ helm push mychart-1.0.0.tgz oci://registry-1.docker.io/myorg

# Sign with the private key
$ cosign sign --key cosign.key registry-1.docker.io/myorg/mychart:1.0.0
```

#### Step 3: Store the Public Key in a Secret on the Management Cluster

```bash
$ kubectl create secret generic cosign-pubkey \
  --from-file=cosign.pub=cosign.pub \
  --namespace=projectsveltos
```

The Secret must have a key named exactly `cosign.pub`. It can live in any namespace on the management cluster.

#### Step 4: Reference It in a ClusterProfile

```yaml
---
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: mychart-static-key
spec:
  clusterSelector:
    matchLabels:
      env: prod
  helmCharts:
  - repositoryURL:    oci://registry-1.docker.io/myorg
    repositoryName:   mychart
    chartName:        mychart
    chartVersion:     1.0.0
    releaseName:      mychart
    releaseNamespace: mychart
    helmChartAction:  Install
    signatureVerification:
      provider: PublicKey
      secretRef:
        name: cosign-pubkey
        namespace: projectsveltos
```

!!! note
    The `namespace` field in `secretRef` lets us place the Secret in any namespace on the management cluster. This avoids having to replicate the Secret when a ClusterProfile targets clusters in multiple namespaces. If `namespace` is omitted, Sveltos falls back to the managed cluster's namespace.

---

## GPG Provenance Verification (HTTP charts)

When a chart is pulled from an HTTP repository, Sveltos can verify the Helm `.prov` provenance file. The `.prov` file contains a SHA256 checksum of the chart archive and a PGP signature over that checksum. Sveltos fetches both the chart and its `.prov` file, verifies the PGP signature using the provided GPG public key, and confirms the checksum matches the downloaded bytes.

This is the same mechanism used by `helm verify` and `helm install --verify`.

#### Step 1: Package and Sign the Chart

```bash
# Sign the chart with a GPG key
$ helm package mychart/
$ helm sign mychart-1.0.0.tgz --key "My Chart Key"

# This produces mychart-1.0.0.tgz and mychart-1.0.0.tgz.prov
# Upload both to your Helm repository
```

#### Step 2: Export the GPG Public Key and Store It in a Secret

```bash
# Export the public key as a binary GPG keyring
$ gpg --export "My Chart Key" > keyring.gpg

# Create the Secret on the management cluster
$ kubectl create secret generic chart-gpg-keyring \
  --from-file=keyring.gpg=keyring.gpg \
  --namespace=projectsveltos
```

The Secret must have a key named exactly `keyring.gpg`. It can live in any namespace on the management cluster.

#### Step 3: Reference It in a ClusterProfile

```yaml
---
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: mychart-gpg
spec:
  clusterSelector:
    matchLabels:
      env: prod
  helmCharts:
  - repositoryURL:    https://charts.example.com
    repositoryName:   myrepo
    chartName:        myrepo/mychart
    chartVersion:     1.0.0
    releaseName:      mychart
    releaseNamespace: mychart
    helmChartAction:  Install
    provenanceVerification:
      keyringSecretRef:
        name: chart-gpg-keyring
        namespace: projectsveltos
```

!!! note
    The `namespace` field in `keyringSecretRef` lets you place the Secret in any namespace on the management cluster, avoiding replication when a ClusterProfile targets clusters in multiple namespaces. If `namespace` is omitted, Sveltos falls back to the managed cluster's namespace.

!!! note
    `provenanceVerification` only applies to HTTP chart repositories. It is ignored for OCI charts and for charts fetched from Flux sources.

---

## Checking Verification Status

When verification fails, the reason for the failure is recorded in the `ClusterSummary` status.

```bash
$ kubectl get clustersummary <name> -n <namespace> -o jsonpath='{.status.featureSummaries}'
```

If verification prevents a deployment from proceeding, the status might look similar to the below.

```yaml
status:
  featureSummaries:
  - featureID: Helm
    status: Failed
    failureMessage: "cosign signature verification failed for registry-1.docker.io/myorg/mychart:1.0.0: ..."
```
