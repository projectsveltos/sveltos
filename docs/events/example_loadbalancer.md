---
title: Example Loadbalancer - Project Sveltos
description: This guide demonstrates how to automate load balancer configuration for Kubernetes services using Sveltos ```EventTrigger``` and ```EventSource```.
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
    - Sveltos
    - event driven
    - loadbalancer
    - subressources
authors:
    - Kevin Klopfenstein
---
This guide demonstrates how to automate load balancer configuration for Kubernetes services using Sveltos ```EventTrigger``` and ```EventSource```.

## Architecutre Overview

![Architecutre Overview](../assets/event_loadbalancer.png)
There are two clusters involved: a "MGMT Cluster" and a "Managed Cluster" (cluster-a). Cluster-a hosts two services: ```svc-a``` and ```svc-b```.
```yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    lb.buttah.cloud/class: internet
  name: svc-a
  namespace: test
spec:
  type: LoadBalancer
  ports:
  - name: test
    port: 1234
    protocol: TCP
    targetPort: test
  selector:
    app.kubernetes.io/name: test
```
The "MGMT Cluster" runs a CNI that implements a load balancer for services of type LoadBalancer. This implementation supports the ```lb.buttah.cloud/class``` label with values ```intern``` or ```internet```.

## EventSource

To implement the load balancer solution, an ```EventSource``` is required to listen for new services. This example filters only for ```Services``` with the label ```lb.buttah.cloud/class```.
```yaml
# deploy on MGMT Cluster
apiVersion: lib.projectsveltos.io/v1beta1
kind: EventSource
metadata:
  name: loadbalancer-class-handler
spec:
  collectResources: true
  resourceSelectors:
  - group: ""
    version: "v1"
    kind: "Service"
    evaluate: |
      function evaluate()
        hs = {}
        hs.matching = false
        if obj.metadata.labels["lb.buttah.cloud/class"] ~= nil then
          hs.matching = true
          return hs
        end
        return hs
      end
```

## EventTriger
After deploying an ```EventSource```, an ```EventTrigger``` is needed. The ```EventTrigger``` listens to a specific ```EventSource``` and can produce new resources based on the event. This is achieved through ```EventTrigger.spec.policyRefs```.

In this case, two new resources are created based on the content of two ```ConfigMaps```: ```loadbalancer-class-handler-svc``` and ```loadbalancer-class-handler-cp```. The ```ConfigMap``` ```loadbalancer-class-handler-svc``` will create a new ```Service``` by copying the ```Service.spec``` from the resource that triggered the ```EventTrigger``` (this example of svc-a from cluster-a). This can be done using the variable ```{{ .Resource }}```.

To deploy the new resource to the "MGMT Cluster", set ```EventTrigger.spec.policyRefs[].deploymentType``` to Local. The new resource should be deployed in the associated namespace of the "Managed Cluster" using the variable ```{{ .Cluster }}```.

```yaml
# deploy on MGMT Cluster
apiVersion: lib.projectsveltos.io/v1beta1
kind: EventTrigger
metadata:
  name: loadbalancer-class-handler
spec:
  sourceClusterSelector:
    matchLabels:
      env: prod
  eventSourceName: loadbalancer-class-handler
  oneForEvent: true
  policyRefs:
  - kind: ConfigMap
    name: loadbalancer-class-handler-svc
    namespace: projectsveltos
    deploymentType: Local
  - kind: ConfigMap
    name: loadbalancer-class-handler-cp
    namespace: projectsveltos
    deploymentType: Local
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: loadbalancer-class-handler-svc
  namespace: projectsveltos
  annotations:
    projectsveltos.io/instantiate: "true"
data:
  service.yaml: |
    kind: Service
    apiVersion: v1
    metadata:
      name: "lb-{{ cat .Resource.metadata.name .Resource.metadata.namespace .Cluster.metadata.name | sha1sum }}"
      namespace: "{{ .Cluster.metadata.namespace }}"
      labels:
        lb.buttah.cloud/class: "{{ get .Resource.metadata.labels `lb.buttah.cloud/class` }}"
        lb.buttah.cloud/cluster: "{{ .Cluster.metadata.name }}"
      annotations:
        lb.buttah.cloud/name: "{{ .Resource.metadata.name }}"
        lb.buttah.cloud/namespace: "{{ .Resource.metadata.namespace }}"
    spec:
      ports:
        {{- range $port := .Resource.spec.ports }}
        - name: "{{ $port.name }}"
          port: {{ $port.port }}
          protocol: "{{ $port.protocol }}"
          targetPort: {{ $port.nodePort }}
        {{- end }}
      selector:
        cluster.x-k8s.io/cluster-name: "{{ .Cluster.metadata.name }}"
      type: LoadBalancer
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: loadbalancer-class-handler-cp
  namespace: projectsveltos
  annotations:
    projectsveltos.io/instantiate: "true"
data:
  cp.yaml: |
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: "lbs-{{ cat .Resource.metadata.name .Resource.metadata.namespace .Cluster.metadata.name | sha1sum }}"
      annotations:
        lb.buttah.cloud/name: "{{ .Resource.metadata.name }}"
        lb.buttah.cloud/namespace: "{{ .Resource.metadata.namespace }}"
    spec:
      clusterRefs:
      - apiVersion: lib.projectsveltos.io/v1beta1
        kind: SveltosCluster
        name: "{{ .Cluster.metadata.name }}"
        namespace: "{{ .Cluster.metadata.namespace }}"
      templateResourceRefs:
      - identifier: UpstreamLB
        resource:
          apiVersion: v1
          kind: Service
          name: "lb-{{ cat .Resource.metadata.name .Resource.metadata.namespace .Cluster.metadata.name | sha1sum }}"
          namespace: "{{ .Cluster.metadata.namespace }}"
      policyRefs:
      - kind: ConfigMap
        name: loadbalancer-class-handler-status
        namespace: projectsveltos
        deploymentType: Remote
```

Here is an example ```ClusterProfile``` and ```ConfigMaps``` which are generated for svc-a from the obove ```EventTrigger``` in order to deploy the Service on the "MGMT Cluster".
These ```ClusterProfile``` are then normally executed by the addon-manager.

```yaml
#  generated Ressource on MGMT Cluster from EventTrigger
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: sveltos-2z2p8p7olrro79biygp8
spec:
  clusterRefs:
  - apiVersion: lib.projectsveltos.io/v1beta1
    kind: SveltosCluster
    name: a
    namespace: cluster-a
  policyRefs:
  - deploymentType: Local
    kind: ConfigMap
    name: sveltos-8dem6v44g95u8lh5oi55
    namespace: projectsveltos
  - deploymentType: Local
    kind: ConfigMap
    name: sveltos-uad8ick2n9mrde65usds
    namespace: projectsveltos
status:
  matchingClusters:
  - apiVersion: lib.projectsveltos.io/v1beta1
    kind: SveltosCluster
    name: a
    namespace: cluster-a
---
apiVersion: v1
data:
  service.yaml: |
    kind: Service
    apiVersion: v1
    metadata:
      name: "lb-894cbba1a1a9a95d0bdb13e08dbbeb6db3f2e672"
      namespace: "cluster-a"
      labels:
        lb.buttah.cloud/class: "internet"
        lb.buttah.cloud/cluster: "a"
      annotations:
        lb.buttah.cloud/name: "svc-a"
        lb.buttah.cloud/namespace: "default"
    spec:
      ports:
        - name: "test"
          port: 1234
          protocol: "TCP"
          targetPort: 1111
      selector:
          cluster.x-k8s.io/cluster-name: "a"
      type: LoadBalancer
kind: ConfigMap
metadata:
  name: sveltos-8dem6v44g95u8lh5oi55
---
apiVersion: v1
data:
  cp.yaml: |
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: "lbs-894cbba1a1a9a95d0bdb13e08dbbeb6db3f2e672"
      annotations:
        lb.buttah.cloud/name: "svc-a"
        lb.buttah.cloud/namespace: "default"
    spec:
      clusterRefs:
      - apiVersion: lib.projectsveltos.io/v1beta1
        kind: SveltosCluster
        name: "a"
        namespace: "cluster-a"
      templateResourceRefs:
      - identifier: UpstreamLB
        resource:
          apiVersion: v1
          kind: Service
          name: "lb-894cbba1a1a9a95d0bdb13e08dbbeb6db3f2e672"
          namespace: "cluster-a"
      policyRefs:
      - kind: ConfigMap
        name: loadbalancer-class-handler-status
        namespace: projectsveltos
        deploymentType: Remote
kind: ConfigMap
metadata:
  name: sveltos-uad8ick2n9mrde65usds
```

After the addon-manager executes both ```ClusterProfiles```, the following resources are deployed on the "MGMT Cluster." The load balancer implementation on the "MGMT Cluster" will assign an IP to the service, in this case, 1.1.1.1. Another ```ClusterProfile``` is responsible for reporting the IP back to the "Managed Clusters" (cluster-a). To patch the IP back, the ```ClusterProfile``` uses a ConfigMap with the annotation ```projectsveltos.io/subresources``` set to ```status```, indicating to the addon-manager to patch this on the subresource status on the Kubernetes API on the "Managed Clusters" (cluster-a). The field ```EventTrigger.spec.templateResourceRefs``` is used to add a depended object which Information can be used in the ```ConfigMap``` in this example you can access the deployed the ```Service``` on the MGMT Cluster status using variable ```UpstreamLB```.
```yaml
# Service Deployed on MGMT Cluster from addon-manager
apiVersion: v1
kind: Service
metadata:
  labels:
    lb.buttah.cloud/class: internet
  name: lb-894cbba1a1a9a95d0bdb13e08dbbeb6db3f2e672
  namespace: cluster-a
spec:
  type: LoadBalancer
  ports:
  - name: test
      port: 1234
      protocol: TCP
      targetPort: test
  selector:
      cluster.x-k8s.io/cluster-name: "cluster-a"
status:
  loadBalancer:
    ingress:
    - ip: 1.1.1.1
---
# ClusterProfile deployed on MGMT CLuster from addon-manager
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: "lbs-894cbba1a1a9a95d0bdb13e08dbbeb6db3f2e672"
  annotations:
    lb.buttah.cloud/name: "svc-a"
    lb.buttah.cloud/namespace: "default"
spec:
  clusterRefs:
  - apiVersion: lib.projectsveltos.io/v1beta1
    kind: SveltosCluster
    name: "cluster-a"
    namespace: "cluster-a"
  templateResourceRefs:
  - identifier: UpstreamLB
    resource:
      apiVersion: v1
      kind: Service
      name: "lb-894cbba1a1a9a95d0bdb13e08dbbeb6db3f2e672"
      namespace: "cluster-a"
  policyRefs:
  - kind: ConfigMap
    name: loadbalancer-class-handler-status
    namespace: projectsveltos
    deploymentType: Remote
---
# ConfigMap with Patch definition to be deployed on cluster-a
apiVersion: v1
kind: ConfigMap
metadata:
  name: loadbalancer-class-handler-status
  namespace: projectsveltos
  annotations:
    projectsveltos.io/template: "true"
    projectsveltos.io/subressources: "status"
data:
  service.yaml: |
    kind: Service
    apiVersion: v1
    metadata:
      name: {{ get (getResource "UpstreamLB").metadata.annotations `lb.buttah.cloud/name` }}
      namespace: {{ get (getResource "UpstreamLB").metadata.annotations `lb.buttah.cloud/namespace` }}
    status:
      loadBalancer:
        ingress:
          {{- range $ingress := (getResource "UpstreamLB").status.loadBalancer.ingress }}
          - ip: "{{ $ingress.ip }}"
          {{- end }}

```

## Data Path

![Data Path](../assets/event_loadbalancer-datapath.png)

At the end the ```Service``` svc-a on the MGMT Cluster will announce the IP 1.1.1.1 to the outside world. Thus a Client can access it. The backend Service for svc-a on the MGMT Cluster is set to the nodes for cluster-a. Thus the traffic gets forwarded to these nodes using the node-port defined in the svc-a on cluster-a.

## Full Code to deploy

```yaml
apiVersion: lib.projectsveltos.io/v1beta1
kind: EventSource
metadata:
  name: loadbalancer-class-handler
spec:
  collectResources: true
  resourceSelectors:
  - group: ""
    version: "v1"
    kind: "Service"
    evaluate: |
      function evaluate()
        hs = {}
        hs.matching = false
        if obj.metadata.labels["lb.buttah.cloud/class"] ~= nil  then
          hs.matching = true
          return hs
        end
        return hs
      end
---
apiVersion: lib.projectsveltos.io/v1beta1
kind: EventTrigger
metadata:
  name: loadbalancer-class-handler
spec:
  sourceClusterSelector:
    matchLabels:
      env: prod
  eventSourceName: loadbalancer-class-handler
  oneForEvent: true
  policyRefs:
  - kind: ConfigMap
    name: loadbalancer-class-handler-svc
    namespace: projectsveltos
    deploymentType: Local
  - kind: ConfigMap
    name: loadbalancer-class-handler-cp
    namespace: projectsveltos
    deploymentType: Local
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: loadbalancer-class-handler-svc
  namespace: projectsveltos
  annotations:
    projectsveltos.io/instantiate: "true"
data:
  service.yaml: |
    kind: Service
    apiVersion: v1
    metadata:
      name: "lb-{{ cat .Resource.metadata.name .Resource.metadata.namespace .Cluster.metadata.name | sha1sum }}"
      namespace: "{{ .Cluster.metadata.namespace }}"
      labels:
        lb.buttah.cloud/class: "{{ get .Resource.metadata.labels `lb.buttah.cloud/class` }}"
        lb.buttah.cloud/cluster: "{{ .Cluster.metadata.name }}"
      annotations:
        lb.buttah.cloud/name: "{{ .Resource.metadata.name }}"
        lb.buttah.cloud/namespace: "{{ .Resource.metadata.namespace }}"
    spec:
      ports:
        {{- range $port := .Resource.spec.ports }}
        - name: "{{ $port.name }}"
          port: {{ $port.port }}
          protocol: "{{ $port.protocol }}"
          targetPort: {{ $port.nodePort }}
        {{- end }}
      selector:
        cluster.x-k8s.io/cluster-name: "{{ .Cluster.metadata.name }}"
      type: LoadBalancer
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: loadbalancer-class-handler-cp
  namespace: projectsveltos
  annotations:
    projectsveltos.io/instantiate: "true"
data:
  cp.yaml: |
    apiVersion: config.projectsveltos.io/v1beta1
    kind: ClusterProfile
    metadata:
      name: "lbs-{{ cat .Resource.metadata.name .Resource.metadata.namespace .Cluster.metadata.name | sha1sum }}"
      annotations:
        lb.buttah.cloud/name: "{{ .Resource.metadata.name }}"
        lb.buttah.cloud/namespace: "{{ .Resource.metadata.namespace }}"
    spec:
      clusterRefs:
      - apiVersion: lib.projectsveltos.io/v1beta1
        kind: SveltosCluster
        name: "{{ .Cluster.metadata.name }}"
        namespace: "{{ .Cluster.metadata.namespace }}"
      templateResourceRefs:
      - identifier: UpstreamLB
        resource:
          apiVersion: v1
          kind: Service
          name: "lb-{{ cat .Resource.metadata.name .Resource.metadata.namespace .Cluster.metadata.name | sha1sum }}"
          namespace: "{{ .Cluster.metadata.namespace }}"
      policyRefs:
      - kind: ConfigMap
        name: loadbalancer-class-handler-status
        namespace: projectsveltos
        deploymentType: Remote
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: loadbalancer-class-handler-status
  namespace: projectsveltos
  annotations:
    projectsveltos.io/template: "true"
    projectsveltos.io/subressources: "status"
data:
  service.yaml: |
    kind: Service
    apiVersion: v1
    metadata:
      name: {{ get (getResource "UpstreamLB").metadata.annotations `lb.buttah.cloud/name` }}
      namespace: {{ get (getResource "UpstreamLB").metadata.annotations `lb.buttah.cloud/namespace` }}
    status:
      loadBalancer:
        ingress:
          {{- range $ingress := (getResource "UpstreamLB").status.loadBalancer.ingress }}
          - ip: "{{ $ingress.ip }}"
          {{- end }}
```
