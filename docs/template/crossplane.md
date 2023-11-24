---
title: Extending Sveltos
description: Learn how Sveltos coordinates with Crossplane or any other open source projects. Discover how to use Sveltos to create Google Cloud Storage Buckets for managed clusters and deploy applications that interact with these buckets. Dive into the YAML code that instructs Sveltos, explore the process step-by-step, and witness the seamless coordination between Sveltos and Crossplane in action.
tags:
    - Kubernetes
    - Sveltos
    - add-ons
    - helm
    - clusterapi
    - dry run
authors:
    - Gianluca Mardente
---

# Sveltos coordinating Crossplane

![Sveltos, ClusterAPI and Crossplane](../assets/sveltos_clusterapi_crossplane.gif)

In this tutorial, we will use Sveltos to coordinate with Crossplane to create a Google Cloud Storage Bucket for each managed cluster. We will then deploy an application in each managed cluster that uploads a file to the proper bucket.

The following YAML code:

1. Creates a ClusterProfile resource that instructs Sveltos to create a Bucket Custom Resource (CR) in the management cluster.
2. Instructs Sveltos to fetch the Bucket CR instance, and use the Bucket status __url__ and __id__ fields to instantiate a Pod template.
3. Deploys the Pod in the managed cluster.

Once the Pod is deployed, it will upload a file to the my-bucket bucket.

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: deploy-resources
spec:
  clusterSelector: env=fv
  templateResourceRefs:
  - resource:
      apiVersion: storage.gcp.upbound.io/v1beta1
      kind: Bucket
      name: crossplane-bucket-{{ .ClusterNamespace }}-{{ .ClusterName }}
    identifier: CrossplaneBucket
  - resource:
      apiVersion: v1
      kind: Secret
      namespace: crossplane-system
      name: gcp-secret
    identifier: Credentials
  policyRefs:
  - deploymentType: Local
    kind: ConfigMap
    name: bucket
    namespace: default
  - deploymentType: Remote
    kind: ConfigMap
    name: uploader
    namespace: default
---
apiVersion: v1
kind: ConfigMap
metadata:   
  name: bucket
  namespace: default
  annotations:
    projectsveltos.io/template: "true"
data:       
  bucket.yaml: |
    apiVersion: storage.gcp.upbound.io/v1beta1
    kind: Bucket
    metadata:
     name: crossplane-bucket-{{ .Cluster.metadata.namespace }}-{{ .Cluster.metadata.name }}
     labels:
       docs.crossplane.io/example: provider-gcp
       clustername: {{ .Cluster.metadata.name }}
       clusternamespace: {{ .Cluster.metadata.namespace }}
    spec:
      forProvider:
        location: US
      providerConfigRef:
        name: default
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: uploader
  namespace: default
  annotations:
    projectsveltos.io/template: "true"
data:
  secret.yaml: |
    apiVersion: v1
    kind: Secret
    metadata:
      name: gcs-credentials
      namespace: default
      annotations:
        bucket: "{{ (index .MgtmResources "CrossplaneBucket").status.atProvider.url }}"
    type: Opaque
    data:
      service-account.json: {{ $data:=(index .MgtmResources "Credentials").data }} {{ (index $data "creds") }}
  pod.yaml: |
    apiVersion: v1
    kind: Pod
    metadata:
      name: create-and-upload-to-gcs
      namespace: default
      annotations:
        bucket: {{ (index .MgtmResources "CrossplaneBucket").status.atProvider.url }}
    spec:
      containers:
      - name: uploader
        image: google/cloud-sdk:slim
        command: ["bash"]
        args:
          - "-c"
          - |
            echo "Hello world" > /tmp/hello.txt
            gcloud auth activate-service-account --key-file=/var/run/secrets/cloud.google.com/service-account.json
            gsutil cp /tmp/hello.txt gs://{{ (index .MgtmResources "CrossplaneBucket").metadata.name }}
        volumeMounts:
          - name: gcp-sa
            mountPath: /var/run/secrets/cloud.google.com/
            readOnly: true
      volumes:
        - name: gcp-sa
          secret:
            secretName: gcs-credentials
```