locals {
  machine_user_name = "azure-user"
  azure_storage_account_name = "helloazureimages"
  azure_resource_group_name = "helloAzureWebsite"
}

terraform {
  backend "azurerm" {}
  required_version = ">= 0.12.23"
}

provider "azurerm" {
  features {}
}

variable "default_azure_location" {}

resource "tls_private_key" "common" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "random_string" "postgres_user" {
  length = 16
  special = false
}

resource "random_string" "postgres_password" {
  length = 64
  special = true
  override_special = "!@$%&*()-_=+[]{}<>:?"
}

resource "azurerm_resource_group" "packer" {
  name = "packerBuilder"
  location = var.default_azure_location
}

resource "azurerm_resource_group" "hello_azure" {
  name = local.azure_resource_group_name
  location = var.default_azure_location
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

data "azurerm_image" "webserver" {
  name = ".*-webservers$"
  resource_group_name = azurerm_resource_group.packer.name
}

data "azurerm_image" "database" {
  name = ".*-databases$"
  resource_group_name = azurerm_resource_group.packer.name
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
  source_image_id = data.azurerm_image.webserver.id
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
  source_image_id = data.azurerm_image.database.id
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

resource "azurerm_storage_account" "images" {
  location = azurerm_resource_group.hello_azure.location
  resource_group_name = azurerm_resource_group.hello_azure.name
  name = local.azure_storage_account_name
  account_tier = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_storage_container" "images" {
  storage_account_name = azurerm_storage_account.images.name
  name = "app-images"
  container_access_type = "blob"
}

data "azurerm_public_ip" "webserver" {
  depends_on = [ azurerm_resource_group.hello_azure ]
  resource_group_name = azurerm_resource_group.hello_azure.name
  name = azurerm_public_ip.webserver.name
}

data "azurerm_public_ip" "database" {
  depends_on = [ azurerm_resource_group.hello_azure ]
  resource_group_name = azurerm_resource_group.hello_azure.name
  name = azurerm_public_ip.database.name
}

output "packer_resource_group" {
  value = azurerm_resource_group.packer.name
}

output "webservers" {
  value = try(data.azurerm_public_ip.webserver.ip_address, "none")
}

output "databases" {
  value = try(data.azurerm_public_ip.database.ip_address, "none")
}

output "common_private_key" {
  value = tls_private_key.common.private_key_pem
}

output "postgres_user" {
  value = random_string.postgres_user.result
}

output "postgres_password" {
  value = random_string.postgres_password.result
}

output "azure_storage_account_name" {
  value = local.azure_storage_account_name
}

output "azure_storage_account_key" {
  value = azurerm_storage_account.images.primary_access_key
}

output "azure_storage_endpoint" {
  value = azurerm_storage_account.images.primary_blob_endpoint
}

output "machine_user" {
  value = local.machine_user_name
}
