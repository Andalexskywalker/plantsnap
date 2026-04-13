param location string = 'swedencentral'
param projectName string = 'plantsnap'

// CosmosDB
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: '${projectName}-cosmos'
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    locations: [
      {
        locationName: location
        failoverPriority: 0
      }
    ]
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
  }
}

// CosmosDB Database
resource cosmosDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-04-15' = {
  parent: cosmosAccount
  name: 'plantsnap-db'
  properties: {
    resource: {
      id: 'plantsnap-db'
    }
  }
}

// CosmosDB Container
resource cosmosContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-04-15' = {
  parent: cosmosDatabase
  name: 'plants'
  properties: {
    resource: {
      id: 'plants'
      partitionKey: {
        paths: ['/userId']
        kind: 'Hash'
      }
    }
  }
}

// Storage Account (BLOB)
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: '${projectName}storage'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

// BLOB Container
resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-01-01' = {
  name: '${storageAccount.name}/default/plant-images'
  properties: {
    publicAccess: 'None'
  }
}

// App Service Plan
resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: '${projectName}-plan'
  location: location
  sku: {
    name: 'B1'
    tier: 'Basic'
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

// App Service
resource appService 'Microsoft.Web/sites@2022-09-01' = {
  name: '${projectName}-app'
  location: location
  properties: {
    serverFarmId: appServicePlan.id
    siteConfig: {
      linuxFxVersion: 'DOCKER|${projectName}-backend:latest'
      appSettings: [
        {
          name: 'COSMOS_ENDPOINT'
          value: cosmosAccount.properties.documentEndpoint
        }
        {
          name: 'STORAGE_ACCOUNT_NAME'
          value: storageAccount.name
        }
      ]
    }
  }
}

// Azure Function - Storage Account
resource functionStorage 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: '${projectName}funcstore'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

// Azure Function App
resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: '${projectName}-functions'
  location: location
  kind: 'functionapp,linux'
  properties: {
    siteConfig: {
      linuxFxVersion: ''
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionStorage.name};AccountKey=${functionStorage.listKeys().keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
      ]
    }
  }
}

output cosmosEndpoint string = cosmosAccount.properties.documentEndpoint
output storageAccountName string = storageAccount.name
output appServiceUrl string = 'https://${appService.properties.defaultHostName}'