---
title: Project Sveltos - Connect to NATS, JetStream Server
description: Sveltos can connect to and respond to CloudEvents published over NATS and JetStream
tags:
    - Kubernetes
    - managed services
    - Sveltos
    - event driven
    - NATS
    - JetStream
    - CloudEvent
authors:
    - Gianluca Mardente
---

# Respond to CloudEvents published over NATS and JetStream

[NATS](https://nats.io) is a lightweight, high-performance messaging system designed for speed and scalability.  It excels at simple publish/subscribe communication. [JetStream](https://docs.nats.io/nats-concepts/jetstream) builds upon NATS, adding powerful streaming and data management capabilities like message persistence, flow control, and ordered delivery.  Together, NATS and JetStream provide a robust platform for building modern, distributed systems.

[CloudEvents](https://cloudevents.io) is a specification for describing event data in a consistent way, regardless of the underlying system or transport protocol.  It simplifies event handling by providing a common format that different systems can understand, enabling interoperability and reducing complexity.  Think of it as a universal language for events.

Sveltos can be configured to connect to and respond to CloudEvents published over NATS and JetStream.

## Connect to NATS and JetStream

To configure Sveltos to connect to NATS and/or JetStream within a managed cluster, create a Secret named `sveltos-nats` in the `projectsveltos` namespace.  This Secret's data should contain a key also named `sveltos-nats` with the connection details.

For example, to connect to a NATS server exposed as the `nats` service in the `nats` namespace on port 4222, with username/password authentication, and for Sveltos to subscribe to the __bar__ and __foo__ subjects, use the following configuration:

```json
{
  "nats":
   {
     "configuration":
        {
            "url": "nats://nats.nats.svc.cluster.local:4222",
            "subjects": [
                "test",
                "foo"
            ],
            "authorization": {
                "user": {
                    "user": "admin",
                    "password": "my-password"
                }
            }
        }
   }
}
```

then create a Secret with it

```bash
kubectl create secret generic -n projectsveltos sveltos-nats --from-file=sveltos-nats=nats-configuration
```

The *sveltos-agent* automatically detects and reacts to changes in this Secret. Take a look at [this](https://github.com/projectsveltos/sveltos-agent/blob/7f95fd41902b0be25904234f38947eceb9178900/pkg/evaluation/nats_evaluation.go#L78) to see full NATS/JetStream configuration options.

## Define an Event

When Sveltos receives a CloudEvent on a subscribed subject, it can trigger a specific operation known as an Event.  Define these Events using the [EventSource](https://github.com/projectsveltos/libsveltos/blob/main/api/v1beta1/eventsource_type.go) CRD.

For example, the following EventSource defines an Event triggered by any message received on the __user-login__ subject with a CloudEvent source of __auth.example.com/user-login__:

```yaml
apiVersion: lib.projectsveltos.io/v1beta1
kind: EventSource
metadata:
  name: user-login
spec:
  messagingMatchCriteria:
  - subject: "user-login"
    cloudEventSource: "auth.example.com/user-login"
```

Following criteria can be used to narrow down the events that Sveltos will react to:

- **Subject**: This field filters based on the NATS/JetStream subject the CloudEvent is received on.  It allows you to specify a particular subject or use regular expressions for pattern matching.  If left empty, the EventSource will consider CloudEvents from any of the subjects Sveltos is subscribed to.  This is useful for broadly catching events across various subjects.

- **CloudEventSource**: This filters CloudEvents based on the source attribute within the CloudEvent itself.  This allows you to distinguish events originating from different systems or components.  Like Subject, it supports regular expressions for flexible matching.

- **CloudEventType**:  This filters CloudEvents based on their type attribute.  The type attribute describes the kind of event that occurred (e.g., com.example.order.created).  Using this filter, you can target specific event types.  Regular expressions are also supported here.

- **CloudEventSubject**: This field filters CloudEvents based on the subject attribute within the CloudEvent, which is distinct from the NATS/JetStream subject.  This provides another layer of filtering based on the event's content. Regular expressions are supported.

## Define what to do in response to an Event

[EventTrigger](https://raw.githubusercontent.com/projectsveltos/event-manager/refs/heads/main/api/v1beta1/eventtrigger_types.go) is the CRD introduced to define what add-ons to deploy when an event happens.

Each EvenTrigger instance:

1. References an [EventSource](addon_event_deployment.md#eventsource) (which defines what the event is);
1. Has a _sourceClusterSelector_ selecting one or more managed clusters; [^1]
1. Contains a list of add-ons to deploy

The following example demonstrates how to trigger the creation of a Namespace when a user logs in.  It uses an *EventTrigger* referencing the `user-login` EventSource (defined previously) and a ConfigMap template.  Sveltos instantiates the ConfigMap template, creating a new Namespace. The Namespace's name is taken from the CloudEvent's subject, and a label is added based on the message within the CloudEvent's data.

```yaml
apiVersion: lib.projectsveltos.io/v1beta1
kind: EventTrigger
metadata:
  name: create-namespace
spec:
  sourceClusterSelector:
    matchLabels:
      env: fv
  eventSourceName: user-login
  oneForEvent: true
  cloudEventAction: Create
  policyRefs:
  - name: namespace
    namespace: default
    kind: ConfigMap
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: namespace
  namespace: default
  annotations:
    projectsveltos.io/instantiate: ok
data:
  namespace.yaml: |
    kind: Namespace
    apiVersion: v1
    metadata:
      name: {{ .CloudEvent.subject }} # .CloudEvent is the triggering CloudEvent
      labels:
        organization: {{ ( index .CloudEvent.data `organization` ) }}
```

## The Role of cloudEvent Source and Subject

Because CloudEvents describe events rather than actions, Sveltos uses the combination of **cloudEvent Source** and **cloudEvent Subject** to uniquely identify the resource associated with the event. This allows Sveltos to manage the lifecycle of resources even though CloudEvents don't have a built-in "delete" operation.

Let's say we want to automatically create a Namespace when a user logs in and delete that Namespace when they log off. We can achieve this by publishing CloudEvents to NATS subject __user-operation__.  Critically, to link login and logout events to the same user, the __cloudEvent Source__ and __cloudEvent Subject__ (which should contain a unique user identifier in this example) must be the same in both the login and logout CloudEvents. We then define following EventSource instance to trigger the appropriate actions.


```yaml
apiVersion: lib.projectsveltos.io/v1beta1
kind: EventSource
metadata:
  name: user-operation
spec:
  messagingMatchCriteria:
  - subject: "user-operation"
    cloudEventSource: "auth.example.com"
```

To complete the setup, we define the EventTrigger resource. The `EventTrigger.Spec.CloudEventAction` field is
defined as a template. When CloudEvent type is __com.example.auth.login__ its instantiated value is `Create`(causing the namespace to be created anytime a user logins). The instantiated value is otherwise `Delete`causing the namespace to be deleted upon a user logout.

```yaml hl_lines="7"
apiVersion: lib.projectsveltos.io/v1beta1
kind: EventTrigger
metadata:
  name: manage-namespace
spec:
  eventSourceName: user-operation
  cloudEventAction:  "{{ if eq .CloudEvent.type 'auth.example.com.logout' }}Delete{{ else }}Create{{ end }}" # can be espressed as a template and instantiated using CloudEvent
  policyRefs:
  - name: namespace
    namespace: default
    kind: ConfigMap
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: namespace
  namespace: default
  annotations:
    projectsveltos.io/instantiate: ok # ConfigMap contains a template and needs to be instantiated at run time
data:
  namespace.yaml: |
    kind: Namespace
    apiVersion: v1
    metadata:
      name: {{ .CloudEvent.subject }} # The CloudEvent is available and can be used to instantiate the template
```

### End to End Flow

Deploy NATS to all production clusters:

```yaml
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: nats
spec:
  clusterSelector:
    matchLabels:
      env: production
  helmCharts:
  - chartName: nats/nats
    chartVersion: 1.2.9
    helmChartAction: Install
    releaseName: nats
    releaseNamespace: nats
    repositoryName: nats
    repositoryURL: https://nats-io.github.io/k8s/helm/charts/
    values: |-
      config:
        merge:
          authorization:
            default_permissions:
              publish: [">"]
              subscribe:  [">"]
            users:
            - user: "admin"
              password: "my-password"
  syncMode: Continuous
```

Once NATS is deployed, create a Secret in each production cluster instructing Sveltos to connect to the NATS server[^2]:

```yaml
apiVersion: config.projectsveltos.io/v1beta1
kind: ClusterProfile
metadata:
  name: deploy-deploy-sveltos-nats-secret
spec:
  dependsOn:
  - nats
  clusterSelector:
    matchLabels:
      env: production
  policyRefs:
  - name: deploy-sveltos-nats-secret
    namespace: default
    kind: Secret
---
apiVersion: v1
data:
  sveltos-nats: YXBpVmVyc2lvbjogdjEKZGF0YToKICBzdmVsdG9zLW5hdHM6IGV3b2dJQ0p1WVhSeklqb0tJQ0FnZXdvZ0lDQWdJQ0pqYjI1bWFXZDFjbUYwYVc5dUlqb0tDWHNLQ1NBZ0lDQWlkWEpzSWpvZ0ltNWhkSE02THk5dVlYUnpMbTVoZEhNdWMzWmpMbU5zZFhOMFpYSXViRzlqWVd3Nk5ESXlNaUlzQ2drZ0lDQWdJbk4xWW1wbFkzUnpJam9nV3dvSkNTSjFjMlZ5TFc5d1pYSmhkR2x2YmlJS0NTQWdJQ0JkTEFvSklDQWdJQ0poZFhSb2IzSnBlbUYwYVc5dUlqb2dld29KQ1NKMWMyVnlJam9nZXdvSkNTQWdJQ0FpZFhObGNpSTZJQ0poWkcxcGJpSXNDZ2tKSUNBZ0lDSndZWE56ZDI5eVpDSTZJQ0p0ZVMxd1lYTnpkMjl5WkNJS0NRbDlDZ2tnSUNBZ2ZRb0pmUW9nSUNCOUNuMEsKa2luZDogU2VjcmV0Cm1ldGFkYXRhOgogIG5hbWU6IHN2ZWx0b3MtbmF0cwogIG5hbWVzcGFjZTogcHJvamVjdHN2ZWx0b3MKdHlwZTogT3BhcXVlCg==
kind: Secret
metadata:
  name: deploy-sveltos-nats-secret
  namespace: default
type: addons.projectsveltos.io/cluster-profile
```

Deploy following Sveltos configuration to create a namespace when a user login:

```yaml
apiVersion: lib.projectsveltos.io/v1beta1
kind: EventSource
metadata:
  name: user-operation
spec:
  messagingMatchCriteria:
  - subject: "user-operation"
    cloudEventSource: "auth.example.com"
---
apiVersion: lib.projectsveltos.io/v1beta1
kind: EventTrigger
metadata:
  name: manage-namespace
spec:
  sourceClusterSelector:
    matchLabels:
      env: production
  eventSourceName: user-operation
  oneForEvent: true
  syncMode: ContinuousWithDriftDetection
  cloudEventAction: '{{if eq .CloudEvent.type "auth.example.com.logout"}}Delete{{else}}Create{{end}}'
  policyRefs:
  - name: namespace
    namespace: default
    kind: ConfigMap
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: namespace
  namespace: default
  annotations:
    projectsveltos.io/instantiate: ok
data:
  namespace.yaml: |
    kind: Namespace
    apiVersion: v1
    metadata:
      name: {{ .CloudEvent.subject }}
```

Send now a CloudEvent representing user __mgianluc__ login:

```
CLOUDEVENT_JSON=$(cat << EOF
{
  "specversion": "1.0",
  "type": "auth.example.com.login",
  "source": "auth.example.com",
  "id": "10001",
  "subject": "mgianluc",
  "datacontenttype": "application/json",
  "data": {
    "message": "User mgianluc login"
  }
}
EOF
)
```

```
KUBECONFIG=<production cluster kubeconfig> kubectl exec -it deployment/nats-box -n nats -- nats pub user-operation $CLOUDEVENT_JSON --user=admin --password=my-password
```

Verify namespace is created:

```
sveltosctl show addons
+-----------------------------+---------------+----------------+--------------+---------+-------------------------------+--------------------------------------------------+
|           CLUSTER           | RESOURCE TYPE |   NAMESPACE    |     NAME     | VERSION |             TIME              |                     PROFILES                     |
+-----------------------------+---------------+----------------+--------------+---------+-------------------------------+--------------------------------------------------+
| default/clusterapi-workload | helm chart    | nats           | nats         | 1.2.9   | 2025-02-04 14:06:14 +0100 CET | ClusterProfile/nats                              |
| default/clusterapi-workload | :Secret       | projectsveltos | sveltos-nats | N/A     | 2025-02-04 14:06:36 +0100 CET | ClusterProfile/deploy-deploy-sveltos-nats-secret |
| default/clusterapi-workload | :Namespace    |                | mgianluc     | N/A     | 2025-02-04 14:12:03 +0100 CET | ClusterProfile/sveltos-gbv99bcdsk1aa04jkdzv      |
+-----------------------------+---------------+----------------+--------------+---------+-------------------------------+--------------------------------------------------+
```

We can now send a CloudEvent for the logout operation (note the CloudEvent type):

```
CLOUDEVENT_JSON=$(cat << EOF
{
  "specversion": "1.0",
  "type": "auth.example.com.logout",
  "source": "auth.example.com",
  "id": "10001",
  "subject": "mgianluc",
  "datacontenttype": "application/json",
  "data": {
    "message": "User mgianluc logout"
  }
}
EOF
)
```

```
KUBECONFIG=<production cluster kubeconfig> kubectl exec -it deployment/nats-box -n nats -- nats pub user-operation $CLOUDEVENT_JSON --user=admin --password=my-password
```

Verify the namespace has been deleted in response to the user logout CloudEvent:

```
sveltosctl show addons
+-----------------------------+---------------+----------------+--------------+---------+-------------------------------+--------------------------------------------------+
|           CLUSTER           | RESOURCE TYPE |   NAMESPACE    |     NAME     | VERSION |             TIME              |                     PROFILES                     |
+-----------------------------+---------------+----------------+--------------+---------+-------------------------------+--------------------------------------------------+
| default/clusterapi-workload | helm chart    | nats           | nats         | 1.2.9   | 2025-02-04 14:06:14 +0100 CET | ClusterProfile/nats                              |
| default/clusterapi-workload | :Secret       | projectsveltos | sveltos-nats | N/A     | 2025-02-04 14:06:36 +0100 CET | ClusterProfile/deploy-deploy-sveltos-nats-secret |
+-----------------------------+---------------+----------------+--------------+---------+-------------------------------+--------------------------------------------------+
```

[^1]: EventTrigger can also reference a [_ClusterSet_](../features/set.md) to select one or more managed clusters.
[^2]: Secret contains following configuration:
```
{
  "nats":
   {
     "configuration":
        {
            "url": "nats://nats.nats.svc.cluster.local:4222",
            "subjects": [
                "user-operation"
            ],
            "authorization": {
                "user": {
                    "user": "admin",
                    "password": "my-password"
                }
            }
        }
   }
}
```
