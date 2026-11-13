---
title: Sveltos - Kubernetes Add-on Controller | Manage Kubernetes Add-ons with Ease | GitOps | ArgoCD Integration
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative APIs to deploy Kubernetes add-ons across multiple clusters.
tags:
    - Kubernetes
    - add-ons
    - helm
    - kustomize
    - clusterapi
    - multi-tenancy
    - Sveltos
    - GitOps
    - argoCD
authors:
    - Eleni Grosdouli
---

## Introduction to Sveltos and GitOps Controllers

Sveltos is not competing with GitOps controllers like ArgoCD or Flux. Instead, these components work together to improve and extend existing GitOps setups. Sveltos configuration is cluster-agnostic. Its built-in Event Framework and templating features allow it to manage complex tasks and support GitOps-driven workflows.

## Sveltos and ArgoCD

ArgoCD is a widely adopted tool for continuous deployments, an open-source tool with hundreds of stars, adopters, and a huge community supporting it. ArgoCD is a popular tool for GitOps, especially for continuous deployments. However, it does not have native support for features like events and pipelines. They come through separate plugins such as [Argo Events](https://argoproj.github.io/argo-events/) and [Argo Workflows/Rollouts](https://argoproj.github.io/workflows/), which means extra components need to be installed and managed on top of the core setup.

This is where Sveltos comes in. Instead of stitching together plugins, we pair ArgoCD with Sveltos and get advanced [templating](../../template/intro_template.md), an [Event Framework](../../events/addon_event_deployment.md), and native Cluster API integration out of the box. Sveltos does not replace ArgoCD; it extends it. ArgoCD stays focused on syncing the source of truth to the management cluster, while Sveltos takes over a label-driven orchestration of add-ons and applications across Kubernetes fleets. The outcome is way simpler to scale complex, multi-cluster workloads without adding more tools to the existing stack.

## Common Use-Cases

As we mentioned in a previous post, there is no one-size-fits-all approach. It is heavily dependent on the use-cases at hand and architectural decisions in place.

There are different deployment approaches when it comes to Sveltos and ArgoCD integration.

| | Use-Case 1: Sveltos-Managed ArgoCD | Use-Case 2: Independent Bootstrap (Platform Engineering Projects) |
|---|---|---|
| **Starting point** | Sveltos running on the management cluster and is used to bring up ArgoCD | Greenfield or production-grade project where platform tools need a clear, independent foundation and separation of concerns |
| **How ArgoCD is installed** | ArgoCD is installed and managed by Sveltos through a `ClusterProfile` resource targeting the management cluster | ArgoCD and Sveltos are both installed on the management cluster using a preferred bootstrap approach (Infrastructure as Code (IaC), pipeline execution, or scripts) |
| **How Sveltos is installed** | Sveltos is already present on the management cluster before ArgoCD is deployed | Sveltos is installed the same way, during the same bootstrap step, independent of ArgoCD |
| **Role of ArgoCD** | ArgoCD syncs Sveltos resources (`ClusterProfiles`, `Profiles`, etc.) from a defined repository | ArgoCD exclusively syncs manifest files, including Sveltos resources, into the management cluster |
| **Role of Sveltos** | Sveltos installs ArgoCD and takes over the deployment lifecycle of a Kubernetes fleet based on labels | Sveltos takes over the deployment lifecycle of the fleet based on labels, with no dependency on ArgoCD for its own installation |
| **Risk to consider** | Circular dependency: if ArgoCD prunes the `ClusterProfile` that installed it, Sveltos can be instructed to remove ArgoCD | None. Neither tool manages the other, so a Git or sync issue with one does not take down the other |
| **Effort required** | Quick to set up, one `ClusterProfile` gets both tools running | Slightly more upfront work, a bootstrap script or IaC step, but a cleaner separation of concerns |

## Use-Case 1: ArgoCD Installation with Sveltos ClusterProfile

As Sveltos installs ArgoCD on the management cluster, we will add the label `type=mgmt` to identify it.

```bash
$ kubectl label sveltoscluster mgmt -n mgmt type=mgmt
```

Sveltos is already running on the management cluster with any bootstrap or means available. It installs ArgoCD through a `ClusterProfile`. Below is an example of what the resource looks like.

!!! example "Sveltos ClusterProfile ArgoCD Deployment"
    ```yaml
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: argocd
    spec:
      clusterSelector:
        matchLabels:
          type: mgmt
      syncMode: Continuous
      helmCharts:
      - repositoryURL: https://argoproj.github.io/argo-helm
        repositoryName: argo
        chartName: argo-cd
        chartVersion: 9.4.17
        releaseName: argocd
        releaseNamespace: argocd
        helmChartAction: Install
      policyRefs:
      - name: argo-resources
        namespace: default
        kind: ConfigMap
    ```

!!! example "ArgoCD Resources as Sveltos Template"
    ```yaml
    apiVersion: v1
    kind: ConfigMap
    metadata:
      name: argo-resources
      namespace: default
    data:
      argo_resources.yaml: |
        ---
        apiVersion: argoproj.io/v1alpha1
        kind: Application
        metadata:
          name: sveltos-manifests
          namespace: argocd
          finalizers:
            - resources-finalizer.argocd.argoproj.io
        spec:
          project: default
          source:
            repoURL: "https://<your domain>/<group name>/<repository name>.git"
            targetRevision: HEAD
            path: resources/sveltos-manifests/
          destination:
            server: https://kubernetes.default.svc
            namespace: default
          syncPolicy:
            automated:
              selfHeal: true
              prune: true
            retry:
              limit: 5
              backoff:
                duration: 5s
                maxDuration: 3m0s
                factor: 2
          ---
          apiVersion: v1
          kind: Secret
          metadata:
            name: sveltos-repo-sync
            namespace: argocd
            labels:
              argocd.argoproj.io/secret-type: repository
          stringData:
            url: "https://<your domain>/<group name>/<repository name>.git"
    ```

Looking at the first manifest file, Sveltos targets clusters with the label set to `type=mgmt`. This is the management cluster. After ArgoCD is up and running, we deploy ArgoCD resources to the management cluster, expressed as a Sveltos template.

Once ArgoCD is running, it takes over syncing the Sveltos resources directory from a repository. This is the fastest way to a working setup, but it introduces a circular dependency: Sveltos manages ArgoCD, and ArgoCD syncs the manifests that define that management. If the ArgoCD `ClusterProfile` is accidentally removed or moved from the synced path, ArgoCD will prune it, and Sveltos will interpret that as an instruction to uninstall ArgoCD.

## Use-Case 2: Independent Bootstrap of Both Tools

For the second use-case, both ArgoCD and Sveltos are installed in the management cluster independently through a bootstrap approach. That could be anything at all. It could be a script, an IaC plan, or a pipeline that does the job. The benefits of this approach are that we have a clear separation of concerns. ArgoCD is responsible for synchronizing manifest files to the management cluster, while Sveltos takes over the deployment of add-ons and applications to a fleet of clusters.

The GitOps workflow in this case looks like the following.

```bash
Push to Repository
        │
        ▼
ArgoCD syncs resources and Sveltos resources to the management cluster
        │
        ▼
Sveltos deploys to Sveltos-managed clusters based on labels
```

A change to a `ClusterProfile`, committed and merged through a PR or a Merge request, is synced by ArgoCD to the management cluster and picked up by Sveltos, which rolls it out to every matching managed cluster.

## Next Steps

Check out how [Sveltos works together with Cluster API](../clusterAPI/use_case_eks.md) or explore the other use-cases. To explore Sveltos' capabilities at a large scale, take a look at [Artem Lajko's post "GitOps for 15,000+ Clusters: What Large-Scale Testing with vCluster Taught Us"](https://itnext.io/gitops-for-15-000-clusters-what-large-scale-testing-with-vcluster-taught-us-41e4b0d43e0b)