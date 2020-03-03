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
  address_space = [ "10.1.0.0/24" ]
  subnet {
    name = "web_servers"
    address_prefix = "10.1.1.0/25"
    security_group = azurerm_network_security_group.webservers_in.id
  }
  subnet {
    name = "db_servers"
    address_prefix = "10.1.2.0/25"
    security_group = azurerm_network_security_group.database_in.id
  }
}

resource "azurerm_network_security_group" "common" {
  location = azurerm_resource_group.hello_azure.location
  resource_group_name = azurerm_resource_group.hello_azure.name
  name = "webservers"

  security_rule {
    name      = "common"
    priority  = 100
    direction = "Inbound"
    access    = "Allow"
    protocol  = "Tcp"
    source_port_range = 22
    destination_port_range = 22
    source_address_prefix = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "database_in" {
  location = azurerm_resource_group.hello_azure.location
  resource_group_name = azurerm_resource_group.hello_azure.name
  name = "database"

  security_rule {
    name      = "database-in"
    priority  = 100
    direction = "Inbound"
    access    = "Allow"
    protocol  = "Tcp"
    source_port_range = 5432
    destination_port_range = 5432
    source_application_security_group_ids = [ azurerm_network_security_group.webservers.id ]
  }
}

// TODO: Have this NSG hook up to Azure LB instead of internet.
resource "azurerm_network_security_group" "webservers_in" {
  location = azurerm_resource_group.hello_azure.location
  resource_group_name = azurerm_resource_group.hello_azure.name
  name = "database"

  security_rule {
    name      = "web-in"
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
