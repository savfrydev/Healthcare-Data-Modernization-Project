############################################
# main.tf — Healthcare Data Modernization
############################################

########################
# Resource Group
########################
resource "azurerm_resource_group" "rg" {
  name     = var.project_rg
  location = var.location
  tags     = local.tags
}

########################
# Storage Account (Function package)
########################
resource "azurerm_storage_account" "sa" {
  name                               = replace("st${var.app_name}", "-", "")
  resource_group_name                = azurerm_resource_group.rg.name
  location                           = azurerm_resource_group.rg.location
  account_tier                       = "Standard"
  account_replication_type           = "LRS"
  min_tls_version                    = "TLS1_2"
  infrastructure_encryption_enabled  = true
  tags                               = local.tags
}

########################
# App Service Plan (Linux Functions)
# Y1 = Consumption. Use EP1/B1/etc for VNet integration needs.
########################
resource "azurerm_service_plan" "plan" {
  name                = "asp-${var.app_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = "Y1" # Consumption Plan
  tags                = local.tags
}

########################
# Key Vault + demo secret
########################
data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "kv" {
  name                       = "kv-${var.app_name}"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  tags                       = local.tags

  # Allow the current ARM principal (pipeline/service connection) to set the first secret
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    secret_permissions = ["Get", "List", "Set"]
  }

  # The Function's managed identity policy is added below via a separate resource,
  # since we don't know the principal_id until after the Function exists.
}

resource "azurerm_key_vault_secret" "demo" {
  name         = "demo-secret"
  value        = "demo-placeholder"
  key_vault_id = azurerm_key_vault.kv.id
  tags         = local.tags
}

########################
# Linux Function App
########################
resource "azurerm_linux_function_app" "func" {
  name                       = var.app_name
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = azurerm_resource_group.rg.location
  service_plan_id            = azurerm_service_plan.plan.id
  storage_account_name       = azurerm_storage_account.sa.name
  storage_account_access_key = azurerm_storage_account.sa.primary_access_key

  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      python_version = "3.11"
    }
    # hardening & perf hints (Consumption ignores always_on)
    ftps_state          = "Disabled"
    minimum_tls_version = "1.2"
    http2_enabled       = true
    use_32_bit_worker   = false
  }

  app_settings = {
    FUNCTIONS_EXTENSION_VERSION = "~4"
    FUNCTIONS_WORKER_RUNTIME    = "python"
    WEBSITE_RUN_FROM_PACKAGE    = "1"
    # Key Vault reference (managed identity must have get/list)
    DEMO_SECRET = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.demo.id})"
  }

  tags = local.tags
}

# Grant the Function's managed identity access to Key Vault secrets
resource "azurerm_key_vault_access_policy" "func_identity" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_function_app.func.identity[0].principal_id

  secret_permissions = ["Get", "List"]
}

########################
# Governance — Tag policy + Storage public access
########################

# Require Environment/Owner/CostCenter tags (custom)
resource "azurerm_policy_definition" "require_tags" {
  name         = "pd-require-tags-${var.project_rg}"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Require standard tags (Environment/Owner/CostCenter)"

  policy_rule = jsonencode({
    if = {
      allOf = [
        { field = "type", notEquals = "Microsoft.Resources/subscriptions/resourceGroups" }
      ]
    }
    then = {
      effect = local.policy_effect_tags_required
      details = {
        existenceCondition = {
          allOf = [
            { field = "tags['Environment']", notEquals = null },
            { field = "tags['Owner']",       notEquals = null },
            { field = "tags['CostCenter']",  notEquals = null }
          ]
        }
      }
    }
  })
}

resource "azurerm_policy_assignment" "require_tags_rg" {
  name                 = "pa-require-tags-${var.project_rg}"
  scope                = azurerm_resource_group.rg.id
  policy_definition_id = azurerm_policy_definition.require_tags.id
  display_name         = "Require Tags (RG scope)"
}

# Audit or Deny storage accounts with public blobs enabled
resource "azurerm_policy_definition" "storage_public_access" {
  name         = "pd-storage-public-${var.project_rg}"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Storage accounts should have blob public access disabled"

  policy_rule = jsonencode({
    if = {
      allOf = [
        { field = "type", equals = "Microsoft.Storage/storageAccounts" },
        { field = "Microsoft.Storage/storageAccounts/allowBlobPublicAccess", equals = true }
      ]
    }
    then = { effect = local.policy_effect_storage_public }
  })
}

resource "azurerm_policy_assignment" "storage_public_access_rg" {
  name                 = "pa-storage-public-${var.project_rg}"
  scope                = azurerm_resource_group.rg.id
  policy_definition_id = azurerm_policy_definition.storage_public_access.id
  display_name         = "Audit/Deny Storage Public Access (RG scope)"
}

########################
# Optional Networking (toggle on with enable_networking = true)
########################

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  count               = var.enable_networking ? 1 : 0
  name                = "vnet-${var.app_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.20.0.0/16"]
  tags                = local.tags
}

# Subnet for Private Endpoints
resource "azurerm_subnet" "snet_private_endpoints" {
  count                                      = var.enable_networking ? 1 : 0
  name                                       = "snet-pe"
  resource_group_name                        = azurerm_resource_group.rg.name
  virtual_network_name                       = azurerm_virtual_network.vnet[0].name
  address_prefixes                           = ["10.20.2.0/24"]
  private_endpoint_network_policies = "Disabled"
}

# Private DNS for Storage (blob)
resource "azurerm_private_dns_zone" "blob" {
  count               = var.enable_networking ? 1 : 0
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob_link" {
  count                 = var.enable_networking ? 1 : 0
  name                  = "blob-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.blob[0].name
  virtual_network_id    = azurerm_virtual_network.vnet[0].id
  registration_enabled  = false
}

# Private Endpoint for Storage (blob)
resource "azurerm_private_endpoint" "sa_blob_pe" {
  count               = var.enable_networking ? 1 : 0
  name                = "pe-${azurerm_storage_account.sa.name}-blob"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.snet_private_endpoints[0].id
  tags                = local.tags

  private_service_connection {
    name                           = "sa-blob-connection"
    private_connection_resource_id = azurerm_storage_account.sa.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "blob-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob[0].id]
  }
}