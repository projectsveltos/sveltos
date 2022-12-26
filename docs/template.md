Helm chart values and resources contained in referenced ConfigMaps/Secrets can be defined as template. Such templates instantiation happens at time of deployment reading values from managament cluster.

For instance, following *ClusterProfile* will deploy calico in any matching CAPI powered cluster fetching Pod CIDRs from CAPI Cluster instance.

```yaml
---
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
          {{ range $cidr := .Cluster.Spec.ClusterNetwork.Pods.CIDRBlocks }}
            - cidr: {{ $cidr }}
              encapsulation: VXLAN
          {{ end }}
```

Any resource contained in ConfigMap/Secret can also be defined as a template. In order to optmize deployment time, to be treated as template such resource need to have following annotation `projectsveltos.io/template` added.

## Variables

Templates have access to the following variables:

1. CAPI Cluster instance. Keyword is `Cluster`
2. CAPI Cluster infrastructure provider. Keyword is `InfrastructureProvider`
3. CAPI Cluster kubeadm provider. Keyword is `KubeadmControlPlane` 
4. For cluster registered with Sveltos, the SveltosCluster instance. Keyword is `SveltosCluster` 

### Confidential data

Sometimes, confidential information is needed when deploying an helm release `SecretRef`. In this case Sveltos allows storing the information in a Secret. Sveltos will fetch it at deployment time.

Let's say we need to store username and password. We can create a Secret with those information. Then in the ClusterProfile.Spec.HelmCharts section we can instructs Sveltos on which Secret contains the information we need and how to fetch it.

```
    secretRef:
      name: <SECRET NAME>
      namespace: <SECRET NAMESPACE>
    values: |
      password: "{{ printf "%s" .SecretRef.Data.PASSWORD | b64dec }}"
      username: "{{ printf "%s" .SecretRef.Data.USERNAME | b64dec }}
```
