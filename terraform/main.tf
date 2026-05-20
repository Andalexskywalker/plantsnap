terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "d7e3c0ac-aa2a-407e-82a8-f765ab060c79"
}

# Resource Group
resource "azurerm_resource_group" "plantsnap" {
  name     = "plantsnap-rg"
  location = "Sweden Central"
}

# CosmosDB Account
resource "azurerm_cosmosdb_account" "plantsnap" {
  name                = "plantsnap-cosmos"
  location            = azurerm_resource_group.plantsnap.location
  resource_group_name = azurerm_resource_group.plantsnap.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.plantsnap.location
    failover_priority = 0
  }
}

# CosmosDB SQL Database
resource "azurerm_cosmosdb_sql_database" "plantsnap" {
  name                = "plantsnap"
  resource_group_name = azurerm_resource_group.plantsnap.name
  account_name        = azurerm_cosmosdb_account.plantsnap.name
}

# CosmosDB SQL Container
resource "azurerm_cosmosdb_sql_container" "plants" {
  name                = "plants"
  resource_group_name = azurerm_resource_group.plantsnap.name
  account_name        = azurerm_cosmosdb_account.plantsnap.name
  database_name       = azurerm_cosmosdb_sql_database.plantsnap.name
  partition_key_path  = "/userId"
}

# Storage Account para imagens (BLOB)
resource "azurerm_storage_account" "plantsnap" {
  name                     = "plantsnapstorage"
  resource_group_name      = azurerm_resource_group.plantsnap.name
  location                 = azurerm_resource_group.plantsnap.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  allow_nested_items_to_be_public = true
}

# BLOB Container para imagens das plantas
resource "azurerm_storage_container" "plant_images" {
  name                  = "plant-images"
  storage_account_name  = azurerm_storage_account.plantsnap.name
  container_access_type = "blob"
}

# Azure Container Registry
resource "azurerm_container_registry" "plantsnap" {
  name                = "plantsnapregistry"
  resource_group_name = azurerm_resource_group.plantsnap.name
  location            = azurerm_resource_group.plantsnap.location
  sku                 = "Basic"
  admin_enabled       = true
}

# App Service Plan (para Web App)
resource "azurerm_service_plan" "plantsnap" {
  name                = "plantsnap-plan"
  resource_group_name = azurerm_resource_group.plantsnap.name
  location            = azurerm_resource_group.plantsnap.location
  os_type             = "Linux"
  sku_name            = "B1"
}

# Web App (Docker Container)
resource "azurerm_linux_web_app" "plantsnap" {
  name                = "plantsnap-app"
  resource_group_name = azurerm_resource_group.plantsnap.name
  location            = azurerm_resource_group.plantsnap.location
  service_plan_id     = azurerm_service_plan.plantsnap.id

  site_config {
    container_registry_use_managed_identity = false
    application_stack {
      docker_image_name   = "plantsnap:latest"
      docker_registry_url = "https://${azurerm_container_registry.plantsnap.login_server}"
    }
  }
}

# Storage Account para Azure Functions
resource "azurerm_storage_account" "functions" {
  name                     = "plantsnapfuncstore"
  resource_group_name      = azurerm_resource_group.plantsnap.name
  location                 = azurerm_resource_group.plantsnap.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# App Service Plan para Functions (Consumption - Serverless)
resource "azurerm_service_plan" "functions" {
  name                = "plantsnap-func-plan"
  resource_group_name = azurerm_resource_group.plantsnap.name
  location            = azurerm_resource_group.plantsnap.location
  os_type             = "Linux"
  sku_name            = "Y1"
}

# Azure Function App (Serverless - Watering Reminders)
resource "azurerm_linux_function_app" "plantsnap" {
  name                       = "plantsnap-functions"
  resource_group_name        = azurerm_resource_group.plantsnap.name
  location                   = azurerm_resource_group.plantsnap.location
  service_plan_id            = azurerm_service_plan.functions.id
  storage_account_name       = azurerm_storage_account.functions.name
  storage_account_access_key = azurerm_storage_account.functions.primary_access_key

  site_config {
    application_stack {
      python_version = "3.11"
    }
  }
}

# Azure Communication Services (para envio de emails)
resource "azurerm_communication_service" "plantsnap" {
  name                = "plantsnap-communication"
  resource_group_name = azurerm_resource_group.plantsnap.name
  data_location       = "Europe"
}