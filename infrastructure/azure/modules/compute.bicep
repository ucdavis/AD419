@description('Azure region for compute resources.')
param location string

@description('Tags to apply to compute resources.')
param tags object

@description('App Service plan name for the web app.')
param webPlanName string

@description('Web App name for the web app.')
param webAppName string

@description('App Service plan SKU name.')
param webSkuName string = 'B1'

@description('App Service plan SKU tier.')
param webSkuTier string = 'Basic'

@description('Linux App Service runtime stack.')
param linuxFxVersion string = 'DOTNETCORE|10.0'

@secure()
@description('SQL connection string.')
param sqlConnectionString string

@description('Environment name for app settings.')
param environmentName string

@description('Application Insights connection string.')
param appInsightsConnectionString string

@description('Application Insights instrumentation key.')
param appInsightsInstrumentationKey string

@description('Base URL used in generated notification emails.')
param notificationBaseUrl string

resource webPlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: webPlanName
  location: location
  kind: 'linux'
  sku: {
    name: webSkuName
    tier: webSkuTier
    size: webSkuName
    capacity: 1
  }
  tags: tags
  properties: {
    reserved: true
  }
}

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: location
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  tags: tags
  properties: {
    serverFarmId: webPlan.id
    httpsOnly: true
    siteConfig: {
      alwaysOn: true
      ftpsState: 'FtpsOnly'
      healthCheckPath: '/health'
      http20Enabled: true
      linuxFxVersion: linuxFxVersion
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'ASPNETCORE_ENVIRONMENT'
          value: environmentName
        }
        {
          name: 'DB_CONNECTION'
          value: sqlConnectionString
        }
        {
          name: 'Notification__BaseUrl'
          value: notificationBaseUrl
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsightsConnectionString
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsightsInstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_AGENT_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
      ]
    }
  }
}

output defaultHostName string = webApp.properties.defaultHostName
output principalId string = webApp.identity.principalId
output webAppName string = webApp.name
