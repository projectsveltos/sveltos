---
title: Event Driven Addon Distribution - Project Sveltos
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative APIs to deploy Kubernetes add-ons across multiple clusters.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
    - Sveltos
    - event driven
    - cross cluster configuration
authors:
    - Gianluca Mardente
---

Sveltos by default will deploy add-ons in the very same cluster an [event](addon_event_deployment.md) is detected.
Sveltos though can also be configured for cross-cluster configuration: watch for events in a cluster and deploy add-ons in a set of different clusters.

EventBasedAddOn CRD has a field called __destinationClusterSelector__, a Kubernetes label selector.
This field is optional and not set by default. In such a case, Sveltos default behavior is to deploy add-ons in the same cluster where the event was detected.

If this field is set, Sveltos behavior will change. When an event is detected in a cluster, add-ons will be deployed in all the clusters matching the label selector __destinationClusterSelector__.

We can see this in action with an example of cross-cluster service discovery.

We have two clusters:

1. GKE cluster (labels env: production) registered with sveltos;
2. a cluster-api cluster (label dep: eng) provisioned by docker.
 
In the management cluster, we create:

1. an EventSource instance that identies as a match any Service with a load balancer IP:
```yaml
apiVersion: lib.projectsveltos.io/v1alpha1
kind: EventSource
metadata:
 name: load-balancer-service
spec:
 collectResources: true
 group: ""
 version: "v1"
 kind: "Service"
 script: |
  function evaluate()
    hs = {}
    hs.matching = false
    hs.message = ""
    if obj.status.loadBalancer.ingress ~= nil then
      hs.matching = true
    end
    return hs
  end
```
1. an EventBasedAddOn instance that references EventSource defined above (and so watches for load balancer services in any cluster with label env:production, which in our example matches the GKE cluster) and deploys selector-less Service and corresponding Endpoints in any cluster matching _destinationClusterSelector_ (in our example the cluster-api provisioned cluster)
```yaml
apiVersion: lib.projectsveltos.io/v1alpha1
kind: EventBasedAddOn
metadata:
 name: service-policy
spec:
 sourceClusterSelector: env=production
 destinationClusterSelector: dep=eng
 eventSourceName: load-balancer-service
 oneForEvent: true
 policyRefs:
 - name: service-policy
   namespace: default
   kind: ConfigMap
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: service-policy
  namespace: default
data:
  service.yaml: |
    kind: Service
    apiVersion: v1
    metadata:
      name: external-{{ .Resource.metadata.name }}
      namespace: external
    spec:
      selector: {}
      ports:
        {{ range $port := .Resource.spec.ports }}
        - port: {{ $port.port }}
          protocol: {{ $port.protocol }}
          targetPort: {{ $port.targetPort }}
        {{ end }}
  endpoint.yaml: |
    kind: Endpoints
    apiVersion: v1
    metadata:
       name: external-{{ .Resource.metadata.name }}
       namespace: external
    subsets:
    - addresses:
      - ip: {{ (index .Resource.status.loadBalancer.ingress 0).ip }}
      ports:
        {{ range $port := .Resource.spec.ports }}
        - port: {{ $port.port }}
        {{ end }}
```

As mentioned above, we are passing Sveltos a selector-less Service and we are then specifying our own Endpoints.
The Service and Endpoints are defined as template and will be instantiated by Sveltos using information taken from load-balancer service matching the EventSource (__Resource__ in this context represent a resource matching EventSource).

Now in the GKE cluster, we can create a deployment and a service of type *LoadBalancer*. 

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-deployment-50001
spec:
  selector:
    matchLabels:
      app: products
      department: sales
  replicas: 3
  template:
    metadata:
      labels:
        app: products
        department: sales
    spec:
      containers:
      - name: hello
        image: "us-docker.pkg.dev/google-samples/containers/gke/hello-app:2.0"
        env:
        - name: "PORT"
          value: "50001"
```

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-lb-service
spec:
  type: LoadBalancer
  selector:
    app: products
    department: sales
  ports:
  - protocol: TCP
    port: 60000
    targetPort: 50001
```

The Service will be assigned an IP address

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-lb-service
  namespace: test
  ...
spec:
  ...
status:
  loadBalancer:
    ingress:
    - ip: 34.172.32.172
```
 
and it will match the EventSource. As result Sveltos will deploy the selector-less Service and Endpoints in the other cluster, the cluster-api provisioned cluster. 
The Endpoints IP address is set to the one assigned to the load balancer Service in the GKE cluster.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: external-my-lb-service
  namespace: external
  ...
spec:
  ports:
  - port: 60000
    protocol: TCP
    targetPort: 50001
  type: ClusterIP
status:
  loadBalancer: {}
```

```yaml 
apiVersion: v1
kind: Endpoints
metadata:
  name: external-my-lb-service
  namespace: external
  ...
subsets:
- addresses:
  - ip: 34.172.32.172
  ports:
  - port: 60000
    protocol: TCP
```

So at this point now a pod in the cluster-api provisioned cluster can reach the service in the GKE cluster.

Let's create namespace policy-demo and a busybox pod in the cluster-api provisioned cluster:

```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: busybox
  name: busybox
  namespace: policy-demo
spec:
  containers:
  - args:
    - /bin/sh
    - -c
    - sleep 360000
    image: busybox:1.28
    imagePullPolicy: Always
    name: busybox
  nodeSelector:
    kubernetes.io/os: linux
```

Then reach the service in the GKE cluster from the busybox pod in the cluster-api provisioned cluster"

```bash 
KUBECONFIG=<KIND CLUSTER> kubectl run --namespace=policy-demo access --rm -ti --image busybox /bin/sh
/ # 
/ # wget -q external-my-lb-service.external:60000 -O -
Hello, world!
Version: 2.0.0
Hostname: my-deployment-50001-6664b685bc-db728
```

![Cross cluster configuration](assets/event_based_cross_cluster.gif)
