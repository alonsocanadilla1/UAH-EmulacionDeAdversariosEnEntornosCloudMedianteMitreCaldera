data "http" "deployer_ip" {
  url = "https://ifconfig.me/ip"
}

resource "azurerm_virtual_network" "tfg_vnet" {
  name                = "vnet-tfg"
  location            = azurerm_resource_group.tfg_rg.location
  resource_group_name = azurerm_resource_group.tfg_rg.name
  address_space       = [ "10.0.0.0/16" ]
}

resource "azurerm_subnet" "management_subnet" {
  name                 = "snet-management"
  resource_group_name  = azurerm_resource_group.tfg_rg.name
  virtual_network_name = azurerm_virtual_network.tfg_vnet.name
  address_prefixes     = [ "10.0.1.0/24" ]
  service_endpoints    = [ "Microsoft.Storage" ]
}

resource "azurerm_subnet" "dmz_subnet" {
  name                 = "snet-dmz"
  resource_group_name  = azurerm_resource_group.tfg_rg.name
  virtual_network_name = azurerm_virtual_network.tfg_vnet.name
  address_prefixes     = [ "10.0.2.0/24" ]
  service_endpoints    = [ "Microsoft.Storage" ]
}

resource "azurerm_network_security_group" "management_nsg" {
  name                = "nsg-management"
  location            = azurerm_resource_group.tfg_rg.location
  resource_group_name = azurerm_resource_group.tfg_rg.name

  security_rule {
    name                       = "Allow-SSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = [ chomp(data.http.deployer_ip.response_body), "10.0.0.0/16" ]
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-Caldera-Web"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "8888"
    source_address_prefixes    = [ chomp(data.http.deployer_ip.response_body), "10.0.0.0/16" ]
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "dmz_nsg" {
  name                = "nsg-dmz"
  location            = azurerm_resource_group.tfg_rg.location
  resource_group_name = azurerm_resource_group.tfg_rg.name

  security_rule {
    name                       = "Allow-HTTP-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefixes    = [ chomp(data.http.deployer_ip.response_body), azurerm_public_ip.c2_public_ip.ip_address, "10.0.0.0/16" ]
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "Allow-SSH-From-Management"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefixes    = [ chomp(data.http.deployer_ip.response_body), "10.0.1.0/24" ]
    destination_address_prefix = "*"
  }
# HARDENING FASE 3 DETECTADO: Token rechazado por diseño  
#  # HARDENING FASE 2: Microsegmentacion Zero Trust
#  security_rule {
#  name                       = "Deny-Legacy-API-From-Management"
#  priority                   = 105
#  direction                  = "Inbound"
#  access                     = "Deny"
#  protocol                   = "Tcp"
#  source_port_range          = "*"
#  destination_port_range     = "8080"
#  source_address_prefix      = "10.0.1.0/24" # Bloquea a la red C2
#  destination_address_prefix = "*"
#}
}

resource "azurerm_subnet_network_security_group_association" "management_nsg_assoc" {
  subnet_id                 = azurerm_subnet.management_subnet.id
  network_security_group_id = azurerm_network_security_group.management_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "dmz_nsg_assoc" {
  subnet_id                 = azurerm_subnet.dmz_subnet.id
  network_security_group_id = azurerm_network_security_group.dmz_nsg.id
}