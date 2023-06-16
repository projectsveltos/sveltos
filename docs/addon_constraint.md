---
title: Kubernetes add-on constraint - Project Sveltos
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative APIs to deploy Kubernetes add-ons across multiple clusters.
tags:
    - Kubernetes
    - add-ons
    - constraints
    - openapi
authors:
    - Gianluca Mardente
---

Sveltos offers the capability to deploy Kubernetes add-ons across multiple clusters, providing support for various deployment methods such as helm charts, kustomize resources, and resource YAMLs. It allows fetching these add-ons from diverse sources.

When deploying add-ons programmatically using Sveltos, it becomes crucial to ensure that the deployed add-ons meet specific constraints. These constraints may vary depending on the clusters, for instance production clusters typically have more rigorous requirements compared to clusters used for testing purposes.

Svelots supports defining constraints for a group of clusters and enforcing that add-ons (does not matter whether Helm charts, Kustomize or YAMLs) satisfy those constraints.
Sveltos uses [OpenAPI](https://swagger.io/specification/) for that. OpenAPI validations allow you to define and enforce a schema for the APIs exposed by your Kubernetes add-ons. By validating the incoming requests against the defined schema, you can ensure that the data is correctly formatted and structured. This helps catch errors early and prevents invalid data from being processed or propagated through your system.

## AddonConstratint CRD

A new Custom Resource Definition is introduced: [AddonConstraint](https://raw.githubusercontent.com/projectsveltos/libsveltos/main/api/v1alpha1/addonconstraint_type.go).

```yaml
apiVersion: lib.projectsveltos.io/v1alpha1
kind: AddonConstraint
metadata:
 name: depl-replica
spec:
  clusterSelector: env=production
  openAPIValidationRefs:
  - namespace: default
    name: openapi-deployment
    kind: ConfigMap
```

Above instance is definining a set of constraints (contained in the referenced ConfigMap) which needs to be enforced in any managed cluster matching the clusterSelector field.
ClusterSelector field is just a pure Kuberntes label selector. So any cluster with label `env: production` will be a match.

The referenced ConfigMap contain an openAPI validation, which is enforcing that any deployment in any namespace must have at least 3 replicas.

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: openapi-deployment
  namespace: default
data:
  openapi.yaml: |
    openapi: 3.0.0
    info:
      title: Kubernetes Replica Validation
      version: 1.0.0

    paths:
      /apis/apps/v1/namespaces/{namespace}/deployments:
        post:
          parameters:
            - in: path
              name: namespace
              required: true
              schema:
                type: string
                minimum: 1
              description: The namespace of the resource
          summary: Create/Update a new deployment
          requestBody:
            required: true
            content:
              application/json:
                schema:
                  $ref: '#/components/schemas/Deployment'
          responses:
            '200':
              description: OK

    components:
      schemas:
        Deployment:
          type: object
          properties:
            metadata:
              type: object
              properties:
                name:
                  type: string
            spec:
              type: object
              properties:
                replicas:
                  type: integer
                  minimum: 3
```

## Sveltos implementation details

There are two main components involved:

1. The Sveltos addon-controller: It is responsible for deploying add-ons to managed clusters. You can find more information about it on the [addon-controller GitHub page](https://github.com/projectsveltos/addon-controller).
2. The Sveltos addon-constraint-controller: It is responsible for identifying all the constraints for each cluster. More details can be found on the [addon-constraint-controller GitHub page](https://github.com/projectsveltos/addon-constraint-controller).

These two controllers work together using a synchronization mechanism. When a new cluster is created, the controllers ensure that all the existing constraints for that cluster are discovered before any add-on is deployed.

When Sveltos needs to deploy an add-on in a managed cluster, it follows these steps:

1. It collects all the constraints currently associated with the cluster.
1. It validates each resource against the current constraints one by one.
1. If a resource fails to satisfy any of the constraints, an error is thrown, and the corresponding error is reported.

The [Kubernetes API](https://kubernetes.io/docs/reference/using-api/api-concepts/) is a programmatic interface provided via HTTP, which operates on resources using a RESTful approach. Before deploying a resource, Sveltos validates it against all the constraints associated with the cluster.

For example, when deploying a deployment resource, Sveltos builds the URI based on the desired action using the openapi policy. The following URIs illustrate the structure (using deployments as an example, but the pattern applies to other resource types as well):

```
/apis/apps/v1/namespaces/{namespace}/deployments
POST: create a Deployment

/apis/apps/v1/namespaces/{namespace}/deployments/{name}
PATCH: partially update the specified Deployment
PUT: replace the specified Deployment

/apis/apps/v1/namespaces/{namespace}/deployments/{name}/scale
PATCH: partially update scale of the specified Deployment
PUT: replace scale of the specified Deployment

/apis/apps/v1/namespaces/{namespace}/deployments/{name}/status
PATCH: partially update status of the specified Deployment
PUT: replace status of the specified Deployment
```

These URIs provide examples of the various actions that can be performed on a deployment resource within the Kubernetes API. When creating an openAPI policy for Sveltos to use, it is important to ensure that the paths defined in the policy align with the schema illustrated above. This will help maintain consistency and compatibility with the expected URI structure for deploying and managing resources within Kubernetes.


![Add-on constraints in action](assets/addon_constraint.gif)


```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: kyverno
spec:
  clusterSelector: env=production
  syncMode: Continuous
  helmCharts:
  - repositoryURL:    https://kyverno.github.io/kyverno/
    repositoryName:   kyverno
    chartName:        kyverno/kyverno
    chartVersion:     v3.0.1
    releaseName:      kyverno-latest
    releaseNamespace: kyverno
    helmChartAction:  Install
    values: |
      admissionController:
        replicas: 1
```

Following error is reported back

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterSummary
...
status:
  featureSummaries:
  - failureMessage: |
      OpenAPI validation depl-replica-ConfigMap:default/openapi-deployment-0 failed request body has an error: doesn't match schema #/components/schemas/Deployment: Error at "/spec/replicas": number must be at least 3
      Schema:
        {
          "minimum": 3,
          "type": "integer"
        }

      Value:
        1
    featureID: Helm
```

Changing the replicas to 3, will make sure Kyverno helm chart satisfies all constraints and helm chart is deployed:

```yaml
apiVersion: config.projectsveltos.io/v1alpha1
kind: ClusterProfile
metadata:
  name: kyverno
spec:
  clusterSelector: env=production
  helmCharts:
  - chartName: kyverno/kyverno
    chartVersion: v3.0.1
    helmChartAction: Install
    releaseName: kyverno-latest
    releaseNamespace: kyverno
    repositoryName: kyverno
    repositoryURL: https://kyverno.github.io/kyverno/
    values: |
      admissionController:
        replicas: 3
      backgroundController:
        replicas: 3
      cleanupController:
        replicas: 3
      reportsController:
        replicas: 3
```

```bash
➜  addon-controller git:(dev) ✗ kubectl exec -it -n projectsveltos  sveltosctl-0    -- /sveltosctl show addons
+-------------------------------------+---------------+-----------+----------------+---------+-------------------------------+------------------+
|               CLUSTER               | RESOURCE TYPE | NAMESPACE |      NAME      | VERSION |             TIME              | CLUSTER PROFILES |
+-------------------------------------+---------------+-----------+----------------+---------+-------------------------------+------------------+
| default/sveltos-management-workload | helm chart    | kyverno   | kyverno-latest | 3.0.1   | 2023-06-14 02:57:12 -0700 PDT | kyverno          |
+-------------------------------------+---------------+-----------+----------------+---------+-------------------------------+------------------+
```

## Choosing this Approach over Using an Admission Controller

Let's explore the advantages of choosing this approach instead of relying on an admission controller like Kyverno or OPA.

One immediate benefit is that you won't need to deploy additional services in your managed clusters. By opting for this approach, you can simplify your cluster architecture and reduce the complexity associated with extra services.

However, there are more significant advantages to consider:

1. **Synchronization without Hassle**: When using an admission controller, you must ensure that no add-ons are deployed until the controller is up and running. This requires a synchronization mechanism to ensure everything is in order. With this approach, Sveltos takes care of this for you. When a new cluster is discovered, the add-on controller patiently waits for the add-on constraint controller to load all existing constraints specific to that cluster. This guarantees a smooth and orderly deployment process.
2. **Consistency in Resource Deployment**: Another important aspect is the behavior regarding resource deployment. In the case of an Helm chart, it often deploys multiple resources together. With this approach, a strict rule applies: either all resources are valid and satisfy the existing constraints, or none of them are deployed. This ensures consistency and avoids partial or incomplete deployments, providing a reliable and predictable deployment process.

By considering these advantages, you can make an informed decision when choosing between this approach and utilizing an admission controller for your cluster management and add-on deployment needs.

## Validating your OpenAPI policies

If you want to validate your OpenAPI policies:

1. clone sveltos addon-controller repo: git clone  git@github.com:projectsveltos/addon-controller.git
2. cd controllers/validate_openapi
3. Create your own directory within the `validate_openapi` directory. Inside this directory, create the following files:
- `openapi_policy.yaml`: This file should contain your OpenAPI policy.
- `valid_resource.yaml`: This file should contain a resource that satisfies the OpenAPI policy.
- `invalid_resource.yaml`: This file should contain a resource that does not satisfy the OpenAPI policy.
4. run `make test` from repo directory.


Running `make test` will initiate the validation process, which thoroughly tests your OpenAPI policies against the provided resource files. This procedure ensures that your defined policy is not only syntactically correct but also functionally accurate. By executing the validation tests, you can gain confidence in the correctness and reliability of your OpenAPI policies.
By following these steps, you can easily validate your OpenAPI policies using the Sveltos addon-controller repository.
