To install Sveltos simply run:

```
kubectl apply -f https://raw.githubusercontent.com/projectsveltos/sveltos/main/manifest/manifest.yaml
```

It will install Sveltos CRD and resources.

Sveltos uses the git-flow branching model. The base branch is dev. If you are looking for latest features, please use the dev branch. If you are looking for a stable version, please use the main branch or tags labeled as v0.x.x.

### Get Status​

Get sveltos status and verify all pods are up and running

```
projectsveltos                      access-manager-6f7fcdd95d-qwkwc                                  2/2     Running   0          2m2s
projectsveltos                      classifier-manager-79b4485978-dz2xs                              2/2     Running   0          2m2s
projectsveltos                      fm-controller-manager-74558b7dd9-xjjrr                           2/2     Running   0          7m6s
projectsveltos                      sveltoscluster-manager-55f999f55d-4thzd                          2/2     Running   0          2m2s
```