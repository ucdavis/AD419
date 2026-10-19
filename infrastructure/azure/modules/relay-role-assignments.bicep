targetScope = 'resourceGroup'

@description('Object ID of the GitHub deployment identity receiving relay access.')
param principalId string

@description('Existing Relay namespace in this resource group.')
param relayNamespaceName string

@description('Existing datamart Hybrid Connection.')
param relayConnectionName string

@description('Existing sender authorization rule on which deployment receives Azure Relay Owner.')
param relaySenderRuleName string

var readerRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')
var relayOwnerRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '2787bf04-f1f5-4bfe-8383-c8a24483ee38')

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

resource relayReaderAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(relayConnection.id, principalId, readerRoleDefinitionId)
  scope: relayConnection
  properties: {
    roleDefinitionId: readerRoleDefinitionId
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

resource senderRuleOwnerAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(relaySenderRule.id, principalId, relayOwnerRoleDefinitionId)
  scope: relaySenderRule
  properties: {
    roleDefinitionId: relayOwnerRoleDefinitionId
    principalId: principalId
    principalType: 'ServicePrincipal'
  }
}

output relayReaderRoleAssignmentId string = relayReaderAssignment.id
output senderRuleOwnerRoleAssignmentId string = senderRuleOwnerAssignment.id
