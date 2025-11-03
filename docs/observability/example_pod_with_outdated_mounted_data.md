---
title: Notifications - Projectsveltos
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

This `HealthCheck` resource implements a sophisticated, **cross-resource** check to identify a common Kubernetes issue: a running Pod using stale configuration because the referenced Secret was updated after the Pod was created. Since Kubernetes does not automatically restart Pods for every Secret change (especially when used as environment variables), this check provides critical cluster hygiene status.

```yaml
apiVersion: lib.projectsveltos.io/v1beta1
kind: HealthCheck
metadata:
  name: pods-with-outdated-secret-data
  annotations:
    projectsveltos.io/deployed-by-sveltos: ok
spec:
  collectResources: true
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

    function isSecretRecentlyUpdated(secretTimestamp)
      local currentTime = os.time()
      local timeSinceUpdate = os.difftime(currentTime, tonumber(secretTimestamp))
      return timeSinceUpdate < 60  -- Less than 60 seconds
    end

    function isPodOlderThanSecret(podTimestamp, secretTimestamp)
      timeDifference = os.difftime(tonumber(podTimestamp), tonumber(secretTimestamp))
      return  timeDifference < 0
    end

    function getPodTimestamp(pod)
      if pod.status ~= nil and pod.status.conditions ~= nil then
        for _,condition in ipairs(pod.status.conditions) do
          if condition.type == "PodReadyToStartContainers" and condition.status == "True" then
            return convertTimestampString(condition.lastTransitionTime)
          end
        end
      end
      return convertTimestampString(pod.metadata.creationTimestamp)
    end

    function hasOutdatedSecret(pod, secrets)
      podTimestamp = getPodTimestamp(pod)

      if pod.spec.containers ~= nil then
        for _, container in ipairs(pod.spec.containers) do

          if container.env ~= nil then
            for _, env in ipairs(container.env) do
              if env.valueFrom ~= nil and env.valueFrom.secretKeyRef ~= nil then
                key = getKey(pod.metadata.namespace, env.valueFrom.secretKeyRef.name)
                if isPodOlderThanSecret(podTimestamp, secrets[key]) then
                  return true, "secret " .. key .. " has been updated after pod creation", secrets[key]
                end
              end
            end
          end

          if  container.envFrom ~= nil then
            for _, envFrom in ipairs(container.envFrom) do
              if envFrom.secretRef ~= nil then
                key = getKey(pod.metadata.namespace, envFrom.secretRef.name)
                if isPodOlderThanSecret(podTimestamp, secrets[key]) then
                  return true, "secret " .. key .. " has been updated after pod creation", secrets[key]
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
                  return true, "secret " .. key .. " has been updated after pod creation", secrets[key]
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
              return true, "secret " .. key .. " has been updated after pod creation", secrets[key]
            end
          end

          if volume.projected ~= nil and volume.projected.sources ~= nil then
            for _, projectedResource in ipairs(volume.projected.sources) do
              if projectedResource.secret ~= nil then
                key = getKey(pod.metadata.namespace, projectedResource.secret.name)
                if isPodOlderThanSecret(podTimestamp, secrets[key]) then
                  return true, "secret " .. key .. " has been updated after pod creation", secrets[key]
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
        outdatedData, message, secretTimestamp = hasOutdatedSecret(pod, secrets)
        if outdatedData then
          -- Check if secret was updated less than a minute ago
          if isSecretRecentlyUpdated(secretTimestamp) then
            local podInfo = {resource= pod, reEvaluate = true, status = "Healthy"}
            table.insert(podsWithOutdatedSecret, podInfo)
          else
            status = "Degraded"
            local podInfo = {resource= pod, message = message, status = status}
            table.insert(podsWithOutdatedSecret, podInfo)
          end
        end
      end

      if #podsWithOutdatedSecret > 0 then
        hs.resources = podsWithOutdatedSecret
      end
      return hs
    end
```

1. **resourceSelectors**: Collects all Pods and all Secrets across the cluster.
2. **getSecretUpdateTime**: Determines the timestamp of the last modification for each Secret using metadata.managedFields.
3. **isPodOlderThanSecret**: Compares the Pod's effective start time (from its status or creation) to the Secret's update time.
4. **isSecretRecentlyUpdated**: A time-based guardrail. If the Pod is stale, this checks if the Secret update happened within a small window (e.g., 60 seconds).
5. **reEvaluate** = true (Critical Flag): If a stale Pod is found, but the Secret was just updated, we mark the Pod as Progressing and set reEvaluate to true. This prevents a false-alarm Degraded status while a Deployment controller (or a tool like Reloader) is in the process of restarting the Pod. If the Pod is not updated within a short period, the check will eventually report Degraded.