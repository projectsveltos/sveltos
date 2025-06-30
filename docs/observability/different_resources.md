---
title: Viewing resources - Projectsveltos
description: Sveltos is an application designed to manage hundreds of clusters by providing declarative APIs to deploy Kubernetes add-ons across multiple clusters.
tags:
    - Kubernetes
    - add-ons
    - helm
    - clusterapi
    - multi-tenancy
    - Sveltos
    - Slack
authors:
    - Gianluca Mardente
---

HealthCheck can also look at resources of different types together.  This allows to perform more complex evaluations.
This can be useful for more sophisticated tasks, such as identifying resources that are related to each other or that have similar properties.
This HealthChech instance finds all Pods instances in all namespaces mounting Secrets. It identifies and reports any pods that are accessing Secrets that have been modified since the pod's creation. This is crucial for maintaining data integrity and security,  as it prevents pods from accessing potentially outdated or compromised secrets.

!!! example ""
    ```yaml
    # This HealthChech instance finds all Pods instances in all namespaces mounting Secrets.
    # It identifies and reports any pods that are accessing Secrets that have been modified
    # since the pod's creation.
    ---
    apiVersion: lib.projectsveltos.io/v1beta1
    kind: HealthCheck
    metadata:
        name: list-pods-with-outdated-secret-data
    spec:
        resourceSelectors:
        - kind: Pod
          group: ""
          version: v1
        - kind: Secret
          group: ""
          version: v1
        evaluateHealth: |
          function getKey(namespace, name)
            return namespace .. ":" .. name
          end

          --  Convert creationTimestamp "2023-12-12T09:35:56Z"
          function convertTimestampString(timestampStr)
            local convertedTimestamp = string.gsub(
              timestampStr,
              '(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)Z',
              function(y, mon, d, h, mi, s)
                return os.time({
                  year = tonumber(y),
                  month = tonumber(mon),
                  day = tonumber(d),
                  hour = tonumber(h),
                  min = tonumber(mi),
                  sec = tonumber(s)
                })
              end
            )
            return convertedTimestamp
          end

          function getLatestTime(times)
            local latestTime = nil
            for _, time in ipairs(times) do
              if latestTime == nil or os.difftime(tonumber(time), tonumber(latestTime)) > 0 then
                latestTime = time
              end
            end
            return latestTime
          end

          function getSecretUpdateTime(secret)
            local times = {}
            if secret.metadata.managedFields ~= nil then
              for _, mf in ipairs(secret.metadata.managedFields) do
                if mf.time ~= nil then
                  table.insert(times, convertTimestampString(mf.time))
                end
              end
            end

            return getLatestTime(times)
          end

          function isPodOlderThanSecret(podTimestamp, secretTimestamp)
            timeDifference = os.difftime(tonumber(podTimestamp), tonumber(secretTimestamp))
            return  timeDifference < 0
          end

          function hasOutdatedSecret(pod, secrets)
            podTimestamp = convertTimestampString(pod.metadata.creationTimestamp)

            if pod.spec.containers ~= nil then
              for _, container in ipairs(pod.spec.containers) do

                if container.env ~= nil then
                  for _, env in ipairs(container.env) do
                    if env.valueFrom ~= nil and env.valueFrom.secretKeyRef ~= nil then
                      key = getKey(pod.metadata.namespace, env.valueFrom.secretKeyRef.name)
                      if isPodOlderThanSecret(podTimestamp, secrets[key]) then
                        return true, "secret " .. key .. " has been updated after pod creation"
                      end
                    end
                  end
                end

                if  container.envFrom ~= nil then
                  for _, envFrom in ipairs(container.envFrom) do
                    if envFrom.secretRef ~= nil then
                      key = getKey(pod.metadata.namespace, envFrom.secretRef.name)
                      if isPodOlderThanSecret(podTimestamp, secrets[key]) then
                        return true, "secret " .. key .. " has been updated after pod creation"
                      end
                    end
                  end
                end
              end
            end

            if pod.spec.initContainers ~= nil then
              for _, initContainer in ipairs(pod.spec.initContainers) do
                if initContainer.env ~= nil then
                  for _, env in ipairs(initContainer.env) do
                    if env.valueFrom ~= nil and env.valueFrom.secretKeyRef ~= nil then
                      key = getKey(pod.metadata.namespace, env.valueFrom.secretKeyRef.name)
                      if isPodOlderThanSecret(podTimestamp, secrets[key]) then
                        return true, "secret " .. key .. " has been updated after pod creation"
                      end
                    end
                  end
                end
              end
            end

            if pod.spec.volumes ~= nil then
              for _, volume in ipairs(pod.spec.volumes) do
                if volume.secret ~= nil then
                  key = getKey(pod.metadata.namespace, volume.secret.secretName)
                  if isPodOlderThanSecret(podTimestamp, secrets[key]) then
                    return true, "secret " .. key .. " has been updated after pod creation"
                  end
                end

                if volume.projected ~= nil and volume.projected.sources ~= nil then
                  for _, projectedResource in ipairs(volume.projected.sources) do
                    if projectedResource.secret ~= nil then
                      key = getKey(pod.metadata.namespace, projectedResource.secret.name)
                      if isPodOlderThanSecret(podTimestamp, secrets[key]) then
                        return true, "secret " .. key .. " has been updated after pod creation"
                      end
                    end
                  end
                end
              end
            end

            return false
          end

          function evaluate()
            local hs = {}
            hs.message = ""

            local pods = {}
            local secrets = {}

            -- Separate secrets and pods
            for _, resource in ipairs(resources) do
              local kind = resource.kind
              if kind == "Secret" then
                key = getKey(resource.metadata.namespace, resource.metadata.name)
                updateTimestamp = getSecretUpdateTime(resource)
                secrets[key] = updateTimestamp
              elseif kind == "Pod" then
                table.insert(pods, resource)
              end
            end

            local podsWithOutdatedSecret = {}

            for _, pod in ipairs(pods) do
              outdatedData, message = hasOutdatedSecret(pod, secrets)
              if outdatedData then
                table.insert(podsWithOutdatedSecret, {resource= pod, status="Degraded", message = message})
              end
            end

            if #podsWithOutdatedSecret > 0 then
              hs.resources = podsWithOutdatedSecret
            end
            return hs
          end
    ```

Following is a report generated for above HealthCheck

```yaml
apiVersion: lib.projectsveltos.io/v1beta1
kind: HealthCheckReport
metadata:
  labels:
    projectsveltos.io/healthcheck-name: list-pods-with-outdated-secret-data
  name: list-pods-with-outdated-secret-data
  namespace: projectsveltos
  ...
spec:
  ...
  healthCheckName: list-pods-with-outdated-secret-data
  resourceStatuses:
  - healthStatus: Degraded
    message: secret foo:dotfile-secret has been updated after pod creation
    objectRef:
      apiVersion: v1
      kind: Pod
      name: secret-dotfiles-pod
      namespace: foo
...
```
