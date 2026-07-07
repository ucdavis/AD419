targetScope = 'resourceGroup'

@description('Base name used for resources.')
param appName string = 'ad419'

@allowed([
  'dev'
  'test'
  'prod'
])
@description('Deployment environment name.')
param env string = 'dev'

@description('Expected Azure subscription ID for non-dev deployments. Required for test and prod deployments.')
param expectedSubscriptionId string = ''

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('SQL admin login for SQL authentication.')
param sqlAdminLogin string

@secure()
@description('SQL admin password for SQL authentication.')
param sqlAdminPassword string

@description('Application SQL database name.')
param sqlDatabaseName string = appName

@description('Data SQL database name.')
param dataSqlDatabaseName string = '${appName}-data'

@description('Additional resource tags to apply.')
param tags object = {}

@minValue(30)
@maxValue(730)
@description('Application Insights retention in days.')
param appInsightsRetentionInDays int = 30

@description('Optional notification base URL. Defaults to the App Service hostname.')
param notificationBaseUrl string = ''

var appNameSafe = toLower(replace(replace(appName, ' ', ''), '_', ''))
var nameToken = substring(uniqueString(resourceGroup().id, appName, env), 0, 6)
var expectedResourceGroupSuffix = '-${env}'
var normalizedExpectedSubscriptionId = toLower(expectedSubscriptionId)
var normalizedCurrentSubscriptionId = toLower(subscription().subscriptionId)
var deploymentGuardPassed = env == 'dev' || (!empty(expectedSubscriptionId) && normalizedCurrentSubscriptionId == normalizedExpectedSubscriptionId && endsWith(resourceGroup().name, expectedResourceGroupSuffix))

var sqlServerName = toLower('sql-${appNameSafe}-${env}-${nameToken}')
var webPlanName = toLower('asp-${appNameSafe}-${env}-${nameToken}')
var webAppName = toLower('web-${appNameSafe}-${env}-${nameToken}')
var appInsightsName = toLower('appi-${appNameSafe}-${env}-${nameToken}')
var logAnalyticsWorkspaceName = toLower('log-${appNameSafe}-${env}-${nameToken}')
var sqlSkuName = env == 'prod' ? 'S0' : 'Basic'
var sqlSkuTier = env == 'prod' ? 'Standard' : 'Basic'
var webSkuName = env == 'prod' ? 'B1' : 'B1'
var webSkuTier = env == 'prod' ? 'Basic' : 'Basic'

var resourceTags = union(tags, {
  environment: env
  application: appName
})

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = if (deploymentGuardPassed) {
  name: logAnalyticsWorkspaceName
  location: location
  tags: resourceTags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: appInsightsRetentionInDays
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = if (deploymentGuardPassed) {
  name: appInsightsName
  location: location
  kind: 'web'
  tags: resourceTags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace!.id
  }
}

module sql 'modules/sql.bicep' = if (deploymentGuardPassed) {
  name: 'sql'
  params: {
    name: sqlServerName
    location: location
    tags: resourceTags
    adminLogin: sqlAdminLogin
    adminPassword: sqlAdminPassword
    appDatabaseName: sqlDatabaseName
    dataDatabaseName: dataSqlDatabaseName
    skuName: sqlSkuName
    skuTier: sqlSkuTier
  }
}

var sqlServerHostnameSuffix = environment().suffixes.sqlServerHostname
var sqlServerFqdn = '${sqlServerName}${startsWith(sqlServerHostnameSuffix, '.') ? '' : '.'}${sqlServerHostnameSuffix}'
var sqlConnectionString = 'Server=tcp:${sqlServerFqdn},1433;Initial Catalog=${sqlDatabaseName};Persist Security Info=False;User ID=${sqlAdminLogin};Password=${sqlAdminPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'
var dataSqlConnectionString = 'Server=tcp:${sqlServerFqdn},1433;Initial Catalog=${dataSqlDatabaseName};Persist Security Info=False;User ID=${sqlAdminLogin};Password=${sqlAdminPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'

module compute 'modules/compute.bicep' = if (deploymentGuardPassed) {
  name: 'compute'
  params: {
    location: location
    tags: resourceTags
    webPlanName: webPlanName
    webAppName: webAppName
    webSkuName: webSkuName
    webSkuTier: webSkuTier
    sqlConnectionString: sqlConnectionString
    dataSqlConnectionString: dataSqlConnectionString
    environmentName: env
    appInsightsConnectionString: appInsights!.properties.ConnectionString
    appInsightsInstrumentationKey: appInsights!.properties.InstrumentationKey
    notificationBaseUrl: empty(notificationBaseUrl) ? 'https://${webAppName}.azurewebsites.net' : notificationBaseUrl
  }
  dependsOn: [
    sql
  ]
}

output appServiceDefaultHostName string = deploymentGuardPassed ? compute!.outputs.defaultHostName : ''
output appServicePrincipalId string = deploymentGuardPassed ? compute!.outputs.principalId : ''
output appInsightsName string = deploymentGuardPassed ? appInsights!.name : ''
output appInsightsConnectionString string = deploymentGuardPassed ? appInsights!.properties.ConnectionString : ''
output logAnalyticsWorkspaceName string = deploymentGuardPassed ? logAnalyticsWorkspace!.name : ''
output sqlDatabaseName string = sqlDatabaseName
output dataSqlDatabaseName string = dataSqlDatabaseName
output sqlServerName string = deploymentGuardPassed ? sql!.outputs.serverName : ''
output webAppName string = deploymentGuardPassed ? compute!.outputs.webAppName : ''
output deploymentGuardPassed bool = deploymentGuardPassed
