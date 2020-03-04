locals {
  machine_user_name = "azure-user"
}

terraform {
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

resource "tls_private_key" "common" {
  algorithm = "RSA"
  rsa_bits = 4096
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
}


// Even though azurerm_virtual_network supports inline subnet
// definitions, it is easier to do it this way so we can reference
// subnets from other resources more easily.
resource "azurerm_subnet" "webservers" {
  resource_group_name = azurerm_resource_group.hello_azure.name
  virtual_network_name = azurerm_virtual_network.website.name
  name = "web_servers"
  address_prefix = "10.1.1.0/24"
}

resource "azurerm_subnet" "databases" {
  resource_group_name = azurerm_resource_group.hello_azure.name
  virtual_network_name = azurerm_virtual_network.website.name
  name = "db_servers"
  address_prefix = "10.1.2.0/24"
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

resource "azurerm_public_ip" "webserver" {
  location = azurerm_resource_group.hello_azure.location
  resource_group_name = azurerm_resource_group.hello_azure.name
  name = "webserverPublicIp"
  allocation_method = "Dynamic"
}

resource "azurerm_public_ip" "database" {
  location = azurerm_resource_group.hello_azure.location
  resource_group_name = azurerm_resource_group.hello_azure.name
  name = "databasePublicIp"
  allocation_method = "Dynamic"
}

resource "azurerm_network_interface" "webserver" {
  location = azurerm_resource_group.hello_azure.location
  resource_group_name = azurerm_resource_group.hello_azure.name
  name = "webserver-nic"

  ip_configuration {
    name = "webserversIpConfiguration"
    subnet_id = azurerm_subnet.webservers.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.webserver.id
  }
}

resource "azurerm_network_interface" "database" {
  location = azurerm_resource_group.hello_azure.location
  resource_group_name = azurerm_resource_group.hello_azure.name
  name = "database-nic"

  ip_configuration {
    name = "webserversIpConfiguration"
    subnet_id = azurerm_subnet.databases.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = azurerm_public_ip.database.id
  }
}

resource "azurerm_linux_virtual_machine" "webserver" {
  location = azurerm_resource_group.hello_azure.location
  resource_group_name = azurerm_resource_group.hello_azure.name
  name = "web_server"
  network_interface_ids = [ azurerm_network_interface.webserver.id ]
  size = "Standard_B1s"
  computer_name = "webserver"
  admin_username = local.machine_user_name
  disable_password_authentication = true
  source_image_reference {
    publisher = "Canonical"
    offer = "UbuntuServer"
    sku = "19.04"
    version = "latest"
  }
  admin_ssh_key {
    username = local.machine_user_name
    public_key = tls_private_key.common.public_key_openssh
  }
  os_disk {
    storage_account_type = "Standard_LRS"
    caching = "ReadOnly"
  }
}

resource "azurerm_linux_virtual_machine" "database" {
  location = azurerm_resource_group.hello_azure.location
  resource_group_name = azurerm_resource_group.hello_azure.name
  name = "database_server"
  network_interface_ids = [ azurerm_network_interface.database.id ]
  size = "Standard_B1s"
  computer_name = "database"
  admin_username = local.machine_user_name
  disable_password_authentication = true
  source_image_reference {
    publisher = "Canonical"
    offer = "UbuntuServer"
    sku = "19.04"
    version = "latest"
  }
  admin_ssh_key {
    username = local.machine_user_name
    public_key = tls_private_key.common.public_key_openssh
  }
  os_disk {
    name = "osdisk-database"
    storage_account_type = "Standard_LRS"
    caching = "ReadOnly"
  }
}


data "azurerm_public_ip" "webserver" {
  resource_group_name = azurerm_resource_group.hello_azure.name
  name = azurerm_public_ip.webserver.name
}

data "azurerm_public_ip" "database" {
  resource_group_name = azurerm_resource_group.hello_azure.name
  name = azurerm_public_ip.database.name
}

output "webserver_ip_address" {
  value = data.azurerm_public_ip.webserver.ip_address
}

output "database_ip_address" {
  value = data.azurerm_public_ip.database.ip_address
}

output "common_private_key" {
  value = tls_private_key.common.private_key_pem
}
