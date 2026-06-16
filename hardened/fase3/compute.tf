resource "azurerm_public_ip" "c2_public_ip" {
  name                = "pip-caldera-c2"
  location            = azurerm_resource_group.tfg_rg.location
  resource_group_name = azurerm_resource_group.tfg_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "c2_nic" {
  name                = "nic-caldera-c2"
  location            = azurerm_resource_group.tfg_rg.location
  resource_group_name = azurerm_resource_group.tfg_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.management_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.c2_public_ip.id
  }
}

# =====================================================================
# LÓGICA DE INYECCIÓN DINÁMICA DE DEPENDENCIAS (TFG)
# =====================================================================
locals {
  script_base = file("${path.module}/caldera-install.sh")
  
  script_r1 = replace(local.script_base, "__IP_WEB_VICTIMA__", azurerm_public_ip.pip_web_victim.ip_address)
  # HARDENING FASE 2 - Simulamos que el atacante intenta adivinar un nombre antiguo de 4 bytes
  script_r2 = replace(local.script_r1, "__NOMBRE_AML_STORAGE__", "stamlws1234abcd")
  script_r3 = replace(local.script_r2, "__NOMBRE_DATALAKE__", azurerm_storage_account.datalake.name)
  script_final = replace(local.script_r3, "__TENANT_DOMAIN__", "<DOMINIOAZURE>.onmicrosoft.com")
}

resource "azurerm_linux_virtual_machine" "c2_vm" {
  name                  = "vm-caldera-c2"
  resource_group_name   = azurerm_resource_group.tfg_rg.name
  location              = azurerm_resource_group.tfg_rg.location
  size                  = "Standard_D2s_v3"
  admin_username        = "azureuser"

  network_interface_ids = [ azurerm_network_interface.c2_nic.id ]
  
  admin_ssh_key {
    username   = "azureuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  # Terraform inyecta el script con todas las variables ya reemplazadas
  custom_data = base64encode(local.script_final)
}