resource "random_id" "storage_id" {
  byte_length = 4
}

data "azurerm_client_config" "current" {}

locals {
  authorized_ips = [
    chomp(data.http.deployer_ip.response_body),
    azurerm_public_ip.c2_public_ip.ip_address
  ]
}

# =====================================================================
# IDENTIDADES Y ROLES 
# =====================================================================
resource "azuread_user" "contractor_compromised" {
  user_principal_name   = "ext-contractor@<DOMINIOAZURE>.onmicrosoft.com" 
  display_name          = "External Contractor (Compromised Identity)"
  password              = "Inf0st3al3r_L3ak_2024_!$"
  force_password_change = false
}

resource "azurerm_user_assigned_identity" "admin_identity" {
  name                = "id-tfg-admin"
  resource_group_name = azurerm_resource_group.tfg_rg.name
  location            = azurerm_resource_group.tfg_rg.location
}

# =====================================================================
# STORAGE 1: AML PREDECIBLE (OBJETIVO DE CVE-2026-2473)
# =====================================================================
resource "azurerm_storage_account" "aml_storage_predictable" {
  name                          = "stamlws${random_id.storage_id.hex}"
  resource_group_name           = azurerm_resource_group.tfg_rg.name
  location                      = azurerm_resource_group.tfg_rg.location
  account_tier                  = "Standard"
  account_replication_type      = "LRS"
  public_network_access_enabled = true 

  network_rules {
    default_action             = "Deny"
    ip_rules                   = local.authorized_ips
    virtual_network_subnet_ids = [ azurerm_subnet.dmz_subnet.id, azurerm_subnet.management_subnet.id ]
  }
}

resource "azurerm_role_assignment" "contractor_aml_storage_access" {
  scope                = azurerm_storage_account.aml_storage_predictable.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_user.contractor_compromised.object_id
}

resource "azurerm_role_assignment" "attacker_aml_storage_contributor" {
  scope                = azurerm_storage_account.aml_storage_predictable.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_role_assignment" "victim_aml_storage_reader" {
  scope                = azurerm_storage_account.aml_storage_predictable.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_linux_virtual_machine.web_victim.identity[0].principal_id
}

# =====================================================================
# STORAGE 2: DATA LAKE (OBJETIVO DE UNC5537)
# =====================================================================
resource "azurerm_storage_account" "datalake" {
  name                     = "stdatalake${random_id.storage_id.hex}"
  resource_group_name      = azurerm_resource_group.tfg_rg.name
  location                 = azurerm_resource_group.tfg_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  network_rules {
    default_action             = "Deny"
    ip_rules                   = local.authorized_ips
    virtual_network_subnet_ids = [ azurerm_subnet.dmz_subnet.id, azurerm_subnet.management_subnet.id ]
  }
}

resource "azurerm_storage_container" "clients_data" {
  name                  = "clients"
  storage_account_name  = azurerm_storage_account.datalake.name
  container_access_type = "private"
}

resource "azurerm_storage_blob" "pwned_unc5537" {
  name                   = "pwned_unc5537.txt"
  storage_account_name   = azurerm_storage_account.datalake.name
  storage_container_name = azurerm_storage_container.clients_data.name
  type                   = "Block"
  source_content         = "FLAG: ¡UNC5537 Exfiltracion completada! Has accedido a los datos confidenciales del Data Lake."
}

resource "azurerm_role_assignment" "contractor_datalake_access" {
  scope                = azurerm_storage_account.datalake.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azuread_user.contractor_compromised.object_id
}