// Copyright 2026, Microsoft
// Licensed under the Apache License, Version 2.0.
//
// GitOps activation: AKS-native Flux extension plus the cluster-scoped
// GitRepository + Kustomization that Flux will reconcile against.
//
// Deployed twice by the CLI on AKS Automatic:
//   1. Extension-only so Azure creates the protected flux-system namespace.
//   2. Full GitOps activation after the CLI writes the ConfigMaps/secrets
//      consumed by postBuild substitutions and HelmRelease valuesFrom.

targetScope = 'resourceGroup'

@description('AKS cluster name; Flux is installed as a cluster-scoped extension.')
param clusterName string

@description('Git repository URL (GitHub-style HTTPS).')
param repoUrl string

@description('Branch Flux should track.')
param repoBranch string = 'main'

@description('Profile path segment under software/stacks/osdu/profiles (e.g., "core").')
param profile string = 'core'

@description('Ingress mode path segment under software/stacks/osdu/ingress (azure, dns, or ip).')
param ingressMode string = 'azure'

@description('Name of the fluxConfigurations resource on the cluster.')
param configurationName string = 'osdu-spi-stack-system-v2'

@description('Create the fluxConfigurations GitOps resource. Set false to install only the Flux extension and namespace.')
param activateGitOps bool = true

@description('Namespace for SPI-owned GitRepository, Kustomizations, HelmReleases, and bootstrap ConfigMaps.')
param gitopsNamespace string = 'flux-system'

@description('Optional local Kubernetes Secret name for private Git repository auth.')
param gitRepositoryLocalAuthRef string = ''

@secure()
@description('Optional SSH private key for private Git repository auth.')
param gitRepositorySshPrivateKey string = ''

@secure()
@description('Optional SSH known_hosts content for private Git repository auth.')
param gitRepositoryKnownHosts string = ''

var gitRepositoryBase = {
  url: repoUrl
  repositoryRef: {
    branch: repoBranch
  }
  syncIntervalInSeconds: 600
  timeoutInSeconds: 600
}

var gitRepositoryAuth = !empty(gitRepositoryLocalAuthRef) ? {
  localAuthRef: gitRepositoryLocalAuthRef
} : {}

var protectedSettings = !empty(gitRepositorySshPrivateKey) ? {
  sshPrivateKey: gitRepositorySshPrivateKey
  known_hosts: gitRepositoryKnownHosts
} : {}

resource aks 'Microsoft.ContainerService/managedClusters@2024-10-01' existing = {
  name: clusterName
}

resource fluxExtension 'Microsoft.KubernetesConfiguration/extensions@2024-11-01' = {
  name: 'flux'
  scope: aks
  properties: {
    extensionType: 'microsoft.flux'
    autoUpgradeMinorVersion: true
    releaseTrain: 'Stable'
    scope: {
      cluster: {
        releaseNamespace: 'flux-system'
      }
    }
  }
}

resource gitopsConfig 'Microsoft.KubernetesConfiguration/fluxConfigurations@2024-11-01' = if (activateGitOps) {
  name: configurationName
  scope: aks
  properties: {
    scope: 'cluster'
    namespace: gitopsNamespace
    sourceKind: 'GitRepository'
    configurationProtectedSettings: protectedSettings
    gitRepository: union(gitRepositoryBase, gitRepositoryAuth)
    kustomizations: {
      inputs: {
        path: './software/generated/bootstrap-inputs'
        prune: true
        syncIntervalInSeconds: 600
        timeoutInSeconds: 300
      }
      stack: {
        path: './software/stacks/osdu/profiles/${profile}'
        dependsOn: [
          'inputs'
        ]
        prune: true
        syncIntervalInSeconds: 600
        timeoutInSeconds: 1800
      }
      ingress: {
        path: './software/stacks/osdu/ingress/${ingressMode}'
        dependsOn: [
          'inputs'
        ]
        prune: true
        syncIntervalInSeconds: 600
        timeoutInSeconds: 1800
      }
    }
  }
  dependsOn: [
    fluxExtension
  ]
}

output configurationName string = activateGitOps ? gitopsConfig.name : ''
output extensionName string = fluxExtension.name
