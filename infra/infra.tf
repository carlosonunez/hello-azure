terraform {
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "hello_azure" {
  name = "helloAzureWebsite"
  location = "South Central US"
}

resource "azurerm_virtual_network" "website" {
  resource_group_name = azurerm_resource_group.hello_azure.name
  location = azurerm_resource_group.hello_azure.location
  name = "hello-azure-vnet"
  address_space = [ "10.1.0.0/16" ]
  subnet {
    name = "web_servers"
    address_prefix = "10.1.1.0/24"
    security_group = azurerm_network_security_group.webservers_in.id
  }
  subnet {
    name = "db_servers"
    address_prefix = "10.1.2.0/24"
    security_group = azurerm_network_security_group.database_in.id
  }
}

// These are needed so that we can map NSGs to VMs without having to use
// CIDRs.
resource "azurerm_application_security_group" "common" {
  location = azurerm_resource_group.hello_azure.location
  resource_group_name = azurerm_resource_group.hello_azure.name
  name = "common"
}

resource "azurerm_application_security_group" "database" {
  location = azurerm_resource_group.hello_azure.location
  resource_group_name = azurerm_resource_group.hello_azure.name
  name = "database"
}

resource "azurerm_application_security_group" "webservers" {
  location = azurerm_resource_group.hello_azure.location
  resource_group_name = azurerm_resource_group.hello_azure.name
  name = "webservers"
}

// And here are our security groups.
resource "azurerm_network_security_group" "common" {
  location = azurerm_resource_group.hello_azure.location
  resource_group_name = azurerm_resource_group.hello_azure.name
  name = "common"

  security_rule {
    name      = "common-allow-ssh"
    priority  = 100
    direction = "Inbound"
    access    = "Allow"
    protocol  = "Tcp"
    source_port_range = 22
    destination_port_range = 22
    source_address_prefix = "*"
    destination_application_security_group_ids = [ azurerm_application_security_group.common.id ]
  }
}

resource "azurerm_network_security_group" "database_in" {
  location = azurerm_resource_group.hello_azure.location
  resource_group_name = azurerm_resource_group.hello_azure.name
  name = "database"

  security_rule {
    name      = "database-ingress-from-webservers"
    priority  = 100
    direction = "Inbound"
    access    = "Allow"
    protocol  = "Tcp"
    source_port_range = 5432
    destination_port_range = 5432
    source_application_security_group_ids = [ azurerm_application_security_group.webservers.id ]
    destination_application_security_group_ids = [ azurerm_application_security_group.database.id ]
  }
}

// TODO: Have this NSG hook up to Azure LB instead of internet.
resource "azurerm_network_security_group" "webservers_in" {
  location = azurerm_resource_group.hello_azure.location
  resource_group_name = azurerm_resource_group.hello_azure.name
  name = "webservers"

  security_rule {
    name      = "allow-internet-ingress"
    priority  = 100
    direction = "Inbound"
    access    = "Allow"
    protocol  = "Tcp"
    source_port_range = 80
    destination_port_range = 80
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }
}
