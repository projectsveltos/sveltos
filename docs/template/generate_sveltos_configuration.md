---
title: Self-Referential Templating Generating Sveltos Configurations with Sveltos
description: Discover how to use Sveltos templating to dynamically generate Sveltos configurations, empowering you to create flexible and reusable templates that adapt to various environments
tags:
    - Kubernetes
    - add-ons
    - helm
    - template
authors:
    - Gianluca Mardente
---

# Generating Sveltos configurations with Sveltos

Sveltos provides powerful templating capabilities that extend beyond simply deploying add-ons to clusters. 
This section dives into Sveltos' templating capabilities for generating Sveltos configurations themselves. 
This allows you to create reusable templates that adapt and generate child configurations based on defined variables.

1. The `deploy-clusterprofiles` ClusterProfile acts as the trigger. It selects the management cluster (identified by the label __type: mgmt__) 
and references a ConfigMap named `test`.

2. The referenced ConfigMap holds a template defined in the data section. 
This template utilizes a loop to dynamically generate two additional ClusterProfile resources: `keydb-services-production` and `keydb-services-staging`.

3. Each generated ClusterProfile targets managed clusters (identified by a label change to __purpose: edge__) and includes 
specific environment configurations for production and staging deployments.

!!!note
    The management cluster has __type: mgmt__ label

```yaml
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: deploy-clusterprofiles
spec:
  clusterSelector:
    matchLabels:      
      type: mgmt   # Select the management cluster
  policyRefs:
  - name: test
    namespace: default
    kind: ConfigMap
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: test
  namespace: default
  annotations:
    projectsveltos.io/template: ok
data:
  keydb_clusterprofile.yaml: |
    {{ $cluster := print "{{ .Cluster.metadata.name }}" }}
    {{- range $env := (list "production" "staging") }}
    ---
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: keydb-services-{{ $env }}
    spec:
      clusterSelector:
        matchLabels:
          purpose: edge # Select managed cluster
      helmCharts:
      - repositoryURL:    https://raw.githubusercontent.com/finkinfridom/charts/main/charts/
        repositoryName:   finkinfridom
        chartName:        finkinfridom/keydb
        chartVersion:     "0.48.3"
        releaseName:      keydb
        releaseNamespace: {{ $env }}
        helmChartAction:  Install
        values: |
          imageTag: "x86_64_v6.3.2"
          multiMaster: "yes"
          activeReplicas: "yes"
          service:
            annotations:
              tailscale.com/expose: "true"
              tailscale.com/hostname: {{ $cluster }}-keydb-{{ $env }}
    {{- end }}
```

After applying this configuration, you'll end up with a total of three ClusterProfiles:

```
kubectl get clusterprofile                                 
NAME                        AGE
deploy-resources            18m
keydb-services-production   18m
keydb-services-staging      18m
```

Note this variable definition

```
{{ $cluster := print "{{ .Cluster.metadata.name }}" }}
``` 

It's important to capture it as a string to prevent further templating within the `deploy-clusterprofiles` ClusterProfile itself.

The generated ClusterProfiles (`keydb-services-production` and `keydb-services-staging`) define Helm chart deployments tailored for
their respective environments. 
For example, the production configuration utilizes the following Helm chart details:


```yaml hl_lines="16"
  helmCharts:
  - chartName: finkinfridom/keydb
    chartVersion: 0.48.3
    helmChartAction: Install
    releaseName: keydb
    releaseNamespace: production
    repositoryName: finkinfridom
    repositoryURL: https://raw.githubusercontent.com/finkinfridom/charts/main/charts/
    values: |
      imageTag: "x86_64_v6.3.2"
      multiMaster: "yes"
      activeReplicas: "yes"
      service:
        annotations:
          tailscale.com/expose: "true"
          tailscale.com/hostname: {{ .Cluster.metadata.name }}-keydb-production
```

Here, you can see how `{{ .Cluster.metadata.name }}` will be dynamically resolved with the actual managed cluster name when the Helm chart deploys on that cluster.

