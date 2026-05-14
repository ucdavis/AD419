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

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('SQL admin login for SQL authentication.')
param sqlAdminLogin string

@secure()
@description('SQL admin password for SQL authentication.')
param sqlAdminPassword string

@description('SQL database name.')
param sqlDatabaseName string = appName

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

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
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

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  tags: resourceTags
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

module sql 'modules/sql.bicep' = {
  name: 'sql'
  params: {
    name: sqlServerName
    location: location
    tags: resourceTags
    adminLogin: sqlAdminLogin
    adminPassword: sqlAdminPassword
    databaseName: sqlDatabaseName
    skuName: sqlSkuName
    skuTier: sqlSkuTier
  }
}

var sqlServerHostnameSuffix = environment().suffixes.sqlServerHostname
var sqlServerFqdn = '${sqlServerName}${startsWith(sqlServerHostnameSuffix, '.') ? '' : '.'}${sqlServerHostnameSuffix}'
var sqlConnectionString = 'Server=tcp:${sqlServerFqdn},1433;Initial Catalog=${sqlDatabaseName};Persist Security Info=False;User ID=${sqlAdminLogin};Password=${sqlAdminPassword};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;'

module compute 'modules/compute.bicep' = {
  name: 'compute'
  params: {
    location: location
    tags: resourceTags
    webPlanName: webPlanName
    webAppName: webAppName
    webSkuName: webSkuName
    webSkuTier: webSkuTier
    sqlConnectionString: sqlConnectionString
    environmentName: env
    appInsightsConnectionString: appInsights.properties.ConnectionString
    appInsightsInstrumentationKey: appInsights.properties.InstrumentationKey
    notificationBaseUrl: empty(notificationBaseUrl) ? 'https://${webAppName}.azurewebsites.net' : notificationBaseUrl
  }
}

output appServiceDefaultHostName string = compute.outputs.defaultHostName
output appServicePrincipalId string = compute.outputs.principalId
output appInsightsName string = appInsights.name
output appInsightsConnectionString string = appInsights.properties.ConnectionString
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name
output sqlDatabaseName string = sqlDatabaseName
output sqlServerName string = sql.outputs.serverName
output webAppName string = compute.outputs.webAppName
