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
  location = "France Central"
}

# CosmosDB
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

# Storage Account
resource "azurerm_storage_account" "plantsnap" {
  name                     = "plantsnapsa"
  resource_group_name      = azurerm_resource_group.plantsnap.name
  location                 = azurerm_resource_group.plantsnap.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Container Registry
resource "azurerm_container_registry" "plantsnap" {
  name                = "plantsnapcr"
  resource_group_name = azurerm_resource_group.plantsnap.name
  location            = azurerm_resource_group.plantsnap.location
  sku                 = "Basic"
  admin_enabled       = true
}

# App Service Plan
resource "azurerm_service_plan" "plantsnap" {
  name                = "plantsnap-plan"
  resource_group_name = azurerm_resource_group.plantsnap.name
  location            = azurerm_resource_group.plantsnap.location
  os_type             = "Linux"
  sku_name            = "B1"
}

# Web App
resource "azurerm_linux_web_app" "plantsnap" {
  name                = "plantsnap-app"
  resource_group_name = azurerm_resource_group.plantsnap.name
  location            = azurerm_resource_group.plantsnap.location
  service_plan_id     = azurerm_service_plan.plantsnap.id

  site_config {
    container_registry_use_managed_identity = false
  }
}

# Function App Storage
resource "azurerm_storage_account" "functions" {
  name                     = "plantsnapfuncsa"
  resource_group_name      = azurerm_resource_group.plantsnap.name
  location                 = azurerm_resource_group.plantsnap.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Function App Plan
resource "azurerm_service_plan" "functions" {
  name                = "plantsnap-func-plan"
  resource_group_name = azurerm_resource_group.plantsnap.name
  location            = azurerm_resource_group.plantsnap.location
  os_type             = "Linux"
  sku_name            = "Y1"
}

# Function App
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

# Communication Services
resource "azurerm_communication_service" "plantsnap" {
  name                = "plantsnap-communication"
  resource_group_name = azurerm_resource_group.plantsnap.name
  data_location       = "Europe"
}