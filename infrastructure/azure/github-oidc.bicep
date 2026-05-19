targetScope = 'subscription'

extension microsoftGraphV1_0

@description('GitHub repository in owner/name format.')
param repository string = 'ucdavis/AD419'

@description('Azure region for the deployment resource groups.')
param location string = deployment().location

@allowed([
  'test'
  'prod'
])
@description('GitHub/Azure deployment environment to bootstrap in the current subscription.')
param env string

@description('Expected Azure subscription ID for this environment.')
param expectedSubscriptionId string

@description('Azure resource group assigned to this deployment identity.')
param resourceGroupName string = 'rg-ad419-${env}'

@description('Display name for this deployment app registration.')
param applicationName string = 'ad419-github-${env}-deploy'

@description('Assign Contributor on each target resource group. Requires Owner or User Access Administrator at the target scopes.')
param assignRbac bool = true

var githubIssuer = 'https://token.actions.githubusercontent.com'
var azureTokenExchangeAudience = 'api://AzureADTokenExchange'
var contributorRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c')
var normalizedExpectedSubscriptionId = toLower(expectedSubscriptionId)
var normalizedCurrentSubscriptionId = toLower(subscription().subscriptionId)
var expectedResourceGroupSuffix = '-${env}'
var deploymentGuardPassed = normalizedCurrentSubscriptionId == normalizedExpectedSubscriptionId && endsWith(resourceGroupName, expectedResourceGroupSuffix)

resource environmentResourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = if (deploymentGuardPassed) {
  name: resourceGroupName
  location: location
}

resource application 'Microsoft.Graph/applications@v1.0' = if (deploymentGuardPassed) {
  uniqueName: applicationName
  displayName: applicationName
  signInAudience: 'AzureADMyOrg'

  resource federatedCredential 'federatedIdentityCredentials@v1.0' = {
    name: '${applicationName}/github-environment-${env}'
    issuer: githubIssuer
    subject: 'repo:${repository}:environment:${env}'
    audiences: [
      azureTokenExchangeAudience
    ]
  }
}

resource servicePrincipal 'Microsoft.Graph/servicePrincipals@v1.0' = if (deploymentGuardPassed) {
  appId: application!.appId
}

module contributorAssignment 'modules/role-assignment.bicep' = if (deploymentGuardPassed && assignRbac) {
  name: '${env}-contributor-assignment'
  scope: environmentResourceGroup
  params: {
    principalId: servicePrincipal!.id
    roleDefinitionId: contributorRoleDefinitionId
  }
}

output deploymentGuardPassed bool = deploymentGuardPassed
output clientId string = deploymentGuardPassed ? application!.appId : ''
output principalId string = deploymentGuardPassed ? servicePrincipal!.id : ''
output resourceGroupName string = deploymentGuardPassed ? environmentResourceGroup!.name : ''
