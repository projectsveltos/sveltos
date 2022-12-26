## Cluster label management

Sveltos can also be configured to automatically update cluster labels based on cluster runtime state. 

The core idea of Sveltos is to give users the ability to programmatically decide which addons should be deployed where by utilizing a ClusterSelector that selects all clusters with labels matching the selector.

Sometimes the versions of required addons and/or what addons are needed depend on the cluster runtime state. For instance, when a cluster is upgraded, some addons need to be upgraded as well. 

In such cases it is convenient to instruct Sveltos to manage cluster labels so that:

1. as cluster runtime state changes, cluster labels are automatically updated;
2. when cluster labels change, ClusterProfile instances matched by a cluster change;
3. as cluster starts matching new ClusterProfile instances, new set of add-ons are deployed.

Sveltos introduced Classifier for this goal. Once a Classifier instance has been deployed in the management cluster, it gets distributed to each cluster. A Sveltos operator running in each managed cluster continues to monitor the cluster runtime state. Information is transmitted back to the management cluster after determining a cluster runtime state match. The cluster labels will then be appropriately updated by Sveltos. As soon as cluster labels are changed, the cluster might begin to match a new ClusterProfle, which leads to an automatic upgrade of Kubernetes addons.
When combining Classifier with ClusterProfiles,

-	Sveltos monitors the runtime status for each cluster.
-	Sveltos updates cluster labels when the cluster runtime state changes.
-	Sveltos deploys and upgrades Kubernetes addons.

![Classifier in action](assets/classifier.gif)

## More examples

1. Classify clusters based on their Kubernetes version [classifier.yaml](https://raw.githubusercontent.com/projectsveltos/classifier/main/examples/kubernetes_version.yaml)
2. Classify clusters based on number of namespaces [classifier.yaml](https://raw.githubusercontent.com/projectsveltos/classifier/main/examples/resources.yaml)
3. Classify clusters based on their Kubernetes version and resources [classifier.yaml](https://raw.githubusercontent.com/projectsveltos/classifier/main/examples/multiple_constraints.yaml)
