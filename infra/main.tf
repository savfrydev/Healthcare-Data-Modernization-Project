resource "azurerm_resource_group" "rg" {
  name     = var.project_rg
  location = var.location
  tags     = local.tags
}

resource "azurerm_storage_account" "sa" {
  name                     = replace("st${var.app_name}", "-", "")
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  tags                     = local.tags
}

resource "azurerm_linux_function_app" "func" {
  name                       = var.app_name
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = azurerm_resource_group.rg.location
  service_plan_id            = azurerm_service_plan.plan.id
  storage_account_name       = azurerm_storage_account.sa.name
  storage_account_access_key = azurerm_storage_account.sa.primary_access_key
  identity { type = "SystemAssigned" }

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "python"
    WEBSITE_RUN_FROM_PACKAGE = "1"
    DEMO_SECRET = "@Microsoft.KeyVault(SecretUri=${azurerm_key_vault_secret.demo.id})"
  }

  tags = local.tags
}

resource "azurerm_policy_definition" "require_tags" {
  name         = "pd-require-tags-${var.project_rg}"
  policy_type  = "Custom"
  mode         = "All"
  display_name = "Require standard tags"
  policy_rule = jsonencode({
    if = { field = "type", notEquals = "Microsoft.Resources/subscriptions/resourceGroups" }
    then = {
      effect = local.policy_effect_tags_required
      details = {
        existenceCondition = {
          allOf = [
            { field = "tags['Environment']", notEquals = null },
            { field = "tags['Owner']", notEquals = null },
            { field = "tags['CostCenter']", notEquals = null }
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
}
# --- Optional Networking (toggle on with enable_networking=true) ---

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  count               = var.enable_networking ? 1 : 0
  name                = "vnet-${var.app_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.20.0.0/16"]
  tags                = local.tags
}

# Subnet for Function VNet Integration
resource "azurerm_subnet" "snet_integration" {
  count                = var.enable_networking ? 1 : 0
  name                 = "snet-integration"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet[0].name
  address_prefixes     = ["10.20.1.0/24"]
  delegation {
    name = "funcapp"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
  tags = local.tags
}

# Subnet for Private Endpoints
resource "azurerm_subnet" "snet_private_endpoints" {
  count                = var.enable_networking ? 1 : 0
  name                 = "snet-pe"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet[0].name
  address_prefixes     = ["10.20.2.0/24"]
  enforce_private_link_endpoint_network_policies = true
  tags = local.tags
}

# Function App VNet Integration
resource "azurerm_app_service_virtual_network_swift_connection" "func_integration" {
  count          = var.enable_networking ? 1 : 0
  app_service_id = azurerm_linux_function_app.func.id
  subnet_id      = azurerm_subnet.snet_integration[0].id
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
