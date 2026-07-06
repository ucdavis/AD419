@description('SQL server name.')
param name string

@description('Azure region for SQL resources.')
param location string

@description('Tags to apply to SQL resources.')
param tags object

@description('SQL admin login for SQL authentication.')
param adminLogin string

@secure()
@description('SQL admin password for SQL authentication.')
param adminPassword string

@description('Application SQL database name.')
param appDatabaseName string

@description('Data SQL database name.')
param dataDatabaseName string

@description('SQL database SKU name.')
param skuName string = 'S0'

@description('SQL database SKU tier.')
param skuTier string = 'Standard'

@description('Whether to allow Azure services/resources to access this SQL server.')
param allowAzureServices bool = true

resource sqlServer 'Microsoft.Sql/servers@2023-08-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    administratorLogin: adminLogin
    administratorLoginPassword: adminPassword
    minimalTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

resource allowAzureServicesFirewallRule 'Microsoft.Sql/servers/firewallRules@2023-08-01' = if (allowAzureServices) {
  name: 'AllowAzureServices'
  parent: sqlServer
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource appDatabase 'Microsoft.Sql/servers/databases@2023-08-01' = {
  name: appDatabaseName
  parent: sqlServer
  location: location
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
  }
}

resource dataDatabase 'Microsoft.Sql/servers/databases@2023-08-01' = {
  name: dataDatabaseName
  parent: sqlServer
  location: location
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
  }
}

output appDatabaseName string = appDatabase.name
output dataDatabaseName string = dataDatabase.name
output serverName string = sqlServer.name
