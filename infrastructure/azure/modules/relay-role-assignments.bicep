targetScope = 'resourceGroup'

@description('Object ID of the GitHub deployment identity receiving relay access.')
param principalId string

@description('Existing Relay namespace in this resource group.')
param relayNamespaceName string

@description('Existing datamart Hybrid Connection.')
param relayConnectionName string

@description('Existing Send-only authorization rule whose keys deployment may read.')
param relaySenderRuleName string

var readerRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')

resource relayNamespace 'Microsoft.Relay/namespaces@2024-01-01' existing = {
  name: relayNamespaceName
}

resource relayConnection 'Microsoft.Relay/namespaces/hybridConnections@2024-01-01' existing = {
  parent: relayNamespace
  name: relayConnectionName
}

resource relaySenderRule 'Microsoft.Relay/namespaces/hybridConnections/authorizationRules@2024-01-01' existing = {
  parent: relayConnection
  name: relaySenderRuleName
}

resource senderKeyReaderRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid(resourceGroup().id, 'ad419-hybrid-connection-send-key-reader')
  properties: {
    roleName: 'AD419 Hybrid Connection Send Key Reader ${uniqueString(resourceGroup().id)}'
    description: 'Allows deployment to retrieve keys for an existing Hybrid Connection authorization rule. Assign only on the Send-only rule.'
    type: 'CustomRole'
    assignableScopes: [
      resourceGroup().id
    ]
    permissions: [
      {
        actions: [
          'Microsoft.Relay/namespaces/HybridConnections/authorizationRules/listkeys/action'
        ]
        notActions: []
        dataActions: []
        notDataActions: []
      }
    ]
  }
}

resource relayReaderAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(relayConnection.id, principalId, readerRoleDefinitionId)
  scope: relayConnection
  properties: {
    roleDefinitionId: readerRoleDefinitionId
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

resource senderKeyReaderAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(relaySenderRule.id, principalId, senderKeyReaderRole.id)
  scope: relaySenderRule
  properties: {
    roleDefinitionId: senderKeyReaderRole.id
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

output relayReaderRoleAssignmentId string = relayReaderAssignment.id
output senderKeyReaderRoleAssignmentId string = senderKeyReaderAssignment.id
