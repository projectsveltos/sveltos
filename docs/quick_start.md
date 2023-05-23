---
title: Kubernetes add-ons management for tens of clusters quick start
description: Projectsveltos extends the functionality of Cluster API with a solution for managing the installation, configuration & deletion of kubernetes cluster add-ons.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
authors:
    - Gianluca Mardente
---

# Deploy add-ons

The main goal of Sveltos is to deploy add-ons in managed Kubernetes clusters. So let's see that in action (see [install](install.md) section first).

## Deploy Helm charts

To deploy Kyverno in any Kubernetes cluster with labels _env: fv_ create this ClusterProfile instance in the management cluster:

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: deploy-kyverno
spec:
  clusterSelector: env=fv
  syncMode: Continuous
  helmCharts:
  - repositoryURL:    https://kyverno.github.io/kyverno/
    repositoryName:   kyverno
    chartName:        kyverno/kyverno
    chartVersion:     v2.6.0
    releaseName:      kyverno-latest
    releaseNamespace: kyverno
    helmChartAction:  Install
```

## Deploy Kubernetes resources

Download this file

```bash
wget https://raw.githubusercontent.com/projectsveltos/demos/main/httproute/gateway-class.yaml
```

which contains:

- Namespace projectcontour to run the Gateway provisioner
- Contour CRDs
- Gateway API CRDs
- Gateway provisioner RBAC resources
- Gateway provisioner Deployment

and create a Secret in the management cluster containing content of that file.

```bash
kubectl create secret generic contour-gateway-provisioner-secret --from-file=contour-gateway-provisioner.yaml --type=addons.projectsveltos.io/cluster-profile
```

To deploy all those resources in any cluster with labels _env: fv_ create this ClusterProfile instance in the management cluster:

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
 name: gateway-configuration
spec:
 clusterSelector: env=fv
 syncMode: Continuous
 policyRefs:
 - name: contour-gateway-provisioner-secret
   namespace: default
   kind: Secret
```

## Deploy resources assembled with Kustomize

Sveltos can work along with Flux to deploy content of Kustomize directories.

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: flux-system
spec:
  clusterSelector: env=fv
  syncMode: Continuous
  kustomizationRefs:
  - namespace: flux-system
    name: flux-system
    kind: GitRepository
    path: ./helloWorld/
    targetNamespace: eng
```

Full examples can be found [here](addons.md#kustomize-with-flux-gitrepository).

ClusterProfile can reference:

1. GitRepository (synced with flux);
2. OCIRepository (synced with flux);
3. Bucket (synced with flux);
4. ConfigMap whose BinaryData section contains __kustomize.tar.gz__ entry with tar.gz of kustomize directory;
5. Secret (type addons.projectsveltos.io/cluster-profile) whose Data section contains __kustomize.tar.gz__ entry with tar.gz of kustomize directory;


## Express your add-ons as template

Helm chart values and resources contained in referenced ConfigMaps/Secrets can be defined as template. Such templates instantiation happens at time of deployment reading values from managament cluster.

When using templates, there are certain resources that are accessible by default. These resources include:

1. CAPI Cluster instance. Keyword is `Cluster`
2. CAPI Cluster infrastructure provider. Keyword is `InfrastructureProvider`
3. CAPI Cluster kubeadm provider. Keyword is `KubeadmControlPlane` 
4. For cluster registered with Sveltos, the SveltosCluster instance. Keyword is `SveltosCluster` 

Additionally, Sveltos can be set up to [retrieve any resource from the management cluster](template.md#variables) and make it available to the templates.

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: deploy-calico
spec:
  clusterSelector: env=fv
  helmCharts:
  - repositoryURL:    https://projectcalico.docs.tigera.io/charts
    repositoryName:   projectcalico
    chartName:        projectcalico/tigera-operator
    chartVersion:     v3.24.5
    releaseName:      calico
    releaseNamespace: tigera-operator
    helmChartAction:  Install
    values: |
      installation:
        calicoNetwork:
          ipPools:
          {{ range $cidr := .Cluster.spec.clusterNetwork.pods.cidrBlocks }}
            - cidr: {{ $cidr }}
              encapsulation: VXLAN
          {{ end }}
```

## Let Sveltos manage cluster labels (and so the add-ons)

To make things more complex, some of the time, the add-ons that you need to deploy depends on cluster run-time state.

For instance, you have deployed Calico v3.24 in a set of clusters. As those clusters get upgraded to Kubernetes v1.25, you want Calico to be upgraded to v3.25 as well.

If you are managing tens of such clusters, manually upgrading Calico when Kubernetes version is upgraded is not ideal. You need an automated solution for that.

**Sveltos cluster classification** offers a solution for such scenario. 
Define two ClusterProfiles:

1. one ClusterProfile instance will deploy calico v3.24.5 in any cluster with label kubernetes: v1–24
2. other ClusterProfile instance will deploy calico v3.25.0 in any cluster with label kubernetes: v1–25


<table>
<tr>
<td> Deploy Calico v1.24 </td> <td> Deploy Calico v1.25 </td>
</tr>
<tr>
<td>
```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: deploy-calico-v1-24
spec:
  clusterSelector: kubernetes=v1-24
  helmCharts:
  - repositoryURL:    https://projectcalico.docs.tigera.io/charts
    repositoryName:   projectcalico
    chartName:        projectcalico/tigera-operator
    chartVersion:     v3.24.5
    releaseName:      calico
    releaseNamespace: tigera-operator
    helmChartAction:  Install
    values: |
      installation:
        calicoNetwork:
          ipPools:
          {{ range $cidr := .Cluster.Spec.ClusterNetwork.Pods.CIDRBlocks }}
            - cidr: {{ $cidr }}
              encapsulation: VXLAN
          {{ end }}
```
</td>
<td>
```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: deploy-calico-v1-25
spec:
  clusterSelector: kubernetes=v1-25
  helmCharts:
  - repositoryURL:    https://projectcalico.docs.tigera.io/charts
    repositoryName:   projectcalico
    chartName:        projectcalico/tigera-operator
    chartVersion:     v3.25.0
    releaseName:      calico
    releaseNamespace: tigera-operator
    helmChartAction:  Install
    values: |
      installation:
        calicoNetwork:
          ipPools:
          {{ range $cidr := .Cluster.Spec.ClusterNetwork.Pods.CIDRBlocks }}
            - cidr: {{ $cidr }}
              encapsulation: VXLAN
          {{ end }}
```
</td>
</tr>
</table>

Then simply create following Classifier instances:

<table>
<tr>
<td> Classifier: k8s version v.1.24.x </td> <td> Classifier: k8s version v.1.25.x  </td>
</tr>
<tr>
<td>
```yaml
apiVersion: lib.projectsveltos.io/v1alpha1
kind: Classifier
metadata:
  name: kubernetes-v1-24
spec:
  classifierLabels:
  - key: kubernetes
    value: v1-24
  kubernetesVersionConstraints:
  - comparison: GreaterThanOrEqualTo
    version: 1.24.0
  - comparison: LessThan
    version: 1.25.0
```
</td>
<td>
```yaml
apiVersion: lib.projectsveltos.io/v1alpha1
kind: Classifier
metadata:
  name: kubernetes-v1-25
spec:
  classifierLabels:
  - key: kubernetes
    value: v1-25
  kubernetesVersionConstraints:
  - comparison: GreaterThanOrEqualTo
    version: 1.25.0
  - comparison: LessThan
    version: 1.26.0
```
</td>
</tr>
</table>

Above Classifier instances will have Sveltos manage Cluster labels by automatically adding:

1. label kubernetes: v1–24 to any cluster running Kubernetes version v1.24.x
1. label kubernetes: v1–25 to any cluster running Kubernetes version v1.25.x.

Because of those labels and the above ClusterProfile instances:

1. calico version v3.24.5 will be deployed in any cluster running Kubernetes version v1.24.x
1. calico version v3.25.0 will be deployed in any cluster running Kubernetes version v1.25.x

No action is required on your side. As clusters are upgraded, Sveltos will upgrade Calico as well.

## Define event and deploy add-ons as result of events

Things might get more complicated when the add-ons need to be deployed as result of an event in a managed cluster. For instance, any time a Service in certain namespace is created, adds an HTTPRoute to expose such a service via Gateway API.

**Sveltos Events** is an event-driven workflow automation framework for Kubernetes which helps you trigger K8s add-on deployments on various events.

1. Define what an Event is (Sveltos supports Lua script for that);
1. Define what add-ons to deploy when such an event happen. Add-ons can be expressed as template, and Sveltos will instantiate those at deployment time using information from managed clusters.

```yaml
apiVersion: lib.projectsveltos.io/v1alpha1
kind: EventSource
metadata:
 name: https-service
spec:
 collectResources: true
 group: ""
 version: "v1"
 kind: "Service"
 namespace: eng
 script: |
   function evaluate()
     hs = {}
     hs.matching = false
     if obj.spec.ports ~= nil then
       for _,p in pairs(obj.spec.ports) do
         if p.port == 443 or p.port == 8443 then
           hs.matching = true
         end
       end
     end
     return hs
   end
```

This EventSource is defining an event as the creation/deletion of a Service in the namespace eng exposing either port 443 or port 8443.
When such an event happens in a managed cluster, we want to deploy an HTTPRoute instance

```yaml
apiVersion: lib.projectsveltos.io/v1alpha1
kind: EventBasedAddOn
metadata:
 name: ingress-configuration
 namespace: default
spec:
 clusterSelector: env=fv
 eventSourceName: https-service
 oneForEvent: false
 policyRefs:
 - name: ingress
   namespace: default
   kind: ConfigMap
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ingress
  namespace: default
data:
  ingress.yaml: |
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: ingress
      namespace: default
      annotations:
        nginx.ingress.kubernetes.io/rewrite-target: /
    spec:
      ingressClassName: http-ingress
      rules:
        - http:
            paths:
            {{ range $resource := .Resources }}
            - path: /{{ .metadata.name }}
              pathType: Prefix
              backend:
                service:
                  name: {{ .metadata.name }}
                  port:
                    {{ range .spec.ports }}
                    {{ if or (eq .port 443 ) (eq .port 8443 ) }}
                    number: {{ .port }}
                    {{ end }}
                    {{ end }}
            {{ end }}
```

## And more 

Deploying add-on is just one of the many features Sveltos offers. Please consider reading full documentation how to cover more complex scenarios with Sveltos:

1. [configuration drift detection](configuration_drift.md): when Sveltos detects a configuration drift, it re-syncs the cluster state back to the state described in the management cluster;
2. [Dry run](dryrun.md) to preview effect of a change; 
3. [Notification](notifications.md): Sveltos can be configured to send notifications when for instance all add-ons are deployed in a cluster. Custom health checks can be passed to Sveltos in the form of [Lua script](notifications.md#healthcheck-crd);
4. [Multi-tenancy](multi-tenancy.md) allowing platform admin to easily grant permissions to tenant admins and have Sveltos enforces those;
5. [Techsupport](techsupport.md): collect tech support from managed clusters;
6. [Snapshot and Rollback](snapshot.md).
