@description('App Service plan region used by the web app.')
param webAppLocation string

@description('Tags to apply to compute resources.')
param tags object

@description('Resource ID of the existing App Service plan.')
param webPlanId string

@description('Web App name for the web app.')
param webAppName string

@description('Linux App Service runtime stack.')
param linuxFxVersion string = 'DOTNETCORE|10.0'

@secure()
@description('SQL connection string.')
param sqlConnectionString string

@secure()
@description('Data SQL database connection string.')
param dataSqlConnectionString string

@description('Environment name for app settings.')
param environmentName string

@description('Application Insights connection string.')
param appInsightsConnectionString string

@description('Application Insights instrumentation key.')
param appInsightsInstrumentationKey string

@description('Base URL used in generated notification emails.')
param notificationBaseUrl string

@description('Attach the existing datamart Hybrid Connection. Disabled for dev.')
param datamartRelayEnabled bool

@description('Resource group containing the existing Relay namespace in this subscription.')
param relayResourceGroup string

@description('Existing Relay namespace name.')
param relayNamespaceName string

@description('Existing datamart Hybrid Connection name.')
param relayConnectionName string

@description('Existing Send-only authorization rule used by App Service.')
param relaySenderRuleName string

@description('Hybrid Connection endpoint hostname; must match DATAMART_CONNECTION.')
param relayHostname string

@description('Hybrid Connection endpoint TCP port; must match DATAMART_CONNECTION.')
param relayPort int

resource relayNamespace 'Microsoft.Relay/namespaces@2024-01-01' existing = {
  name: relayNamespaceName
  scope: resourceGroup(relayResourceGroup)
}

resource relayConnection 'Microsoft.Relay/namespaces/hybridConnections@2024-01-01' existing = {
  parent: relayNamespace
  name: relayConnectionName
}

resource relaySenderRule 'Microsoft.Relay/namespaces/hybridConnections/authorizationRules@2024-01-01' existing = {
  parent: relayConnection
  name: relaySenderRuleName
}

resource webApp 'Microsoft.Web/sites@2023-12-01' = {
  name: webAppName
  location: webAppLocation
  kind: 'app,linux'
  identity: {
    type: 'SystemAssigned'
  }
  tags: tags
  properties: {
    serverFarmId: webPlanId
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
          name: 'DATA_DB_CONNECTION'
          value: dataSqlConnectionString
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

resource datamartRelay 'Microsoft.Web/sites/hybridConnectionNamespaces/relays@2023-12-01' = if (datamartRelayEnabled) {
  name: '${webApp.name}/${relayNamespaceName}/${relayConnectionName}'
  properties: {
    hostname: relayHostname
    port: relayPort
    relayArmUri: relayConnection.id
    relayName: relayConnectionName
    serviceBusNamespace: relayNamespaceName
    // App Service defaults the relay suffix to .servicebus.windows.net.
    sendKeyName: relaySenderRuleName
    // ARM can evaluate listKeys even on a skipped resource; guard the call itself.
    sendKeyValue: datamartRelayEnabled ? relaySenderRule.listKeys().primaryKey : ''
  }
}

output defaultHostName string = webApp.properties.defaultHostName
output principalId string = webApp.identity.principalId
output webAppName string = webApp.name
