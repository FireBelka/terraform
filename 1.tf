terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }
}
provider "azurerm" {
  features {}
}

data "azurerm_public_ip" "lb_pip" {
  name                = "lb_pip"
  resource_group_name = "web-RG"
}
data "azurerm_resource_group" "myterraformgroup" {
  name = "web-RG"
}

/*
# Create a resource group if it doesn't exist
resource "azurerm_resource_group" "myterraformgroup" {
  name     = "web-RG"
  location = "eastus"
  lifecycle {
    prevent_destroy = true
  }
  tags = {
    environment = "Terraform Demo"
  }
}
*/


# Create virtual network
resource "azurerm_virtual_network" "myterraformnetwork" {
  name                = "myVnet"
  address_space       = ["10.0.0.0/16"]
  location            = "eastus"
  resource_group_name = data.azurerm_resource_group.myterraformgroup.name

  tags = {
    environment = "Terraform Demo"
  }
}

# Create subnet
resource "azurerm_subnet" "myterraformsubnet1" {
  name                 = "mySubnet"
  resource_group_name  = data.azurerm_resource_group.myterraformgroup.name
  virtual_network_name = azurerm_virtual_network.myterraformnetwork.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IPs
/*
resource "azurerm_public_ip" "myterraformpublicip" {
  name                = "myPublicIP"
  location            = "eastus"
  resource_group_name = azurerm_resource_group.myterraformgroup.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    environment = "Terraform Demo"
  }
}
resource "azurerm_public_ip" "myterraformpublicip2" {
  name                = "myPublicIP2"
  location            = "eastus"
  resource_group_name = azurerm_resource_group.myterraformgroup.name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = {
    environment = "Terraform Demo"
  }
}
*/

/*
resource "azurerm_public_ip" "lb_pip" {
  name                = "lb_pip"
  location            = "eastus"
  resource_group_name = azurerm_resource_group.myterraformgroup.name
  allocation_method   = "Static"
  sku                 = "Standard"
  lifecycle {
    prevent_destroy = true
  }
  tags = {
    environment = "Terraform Demo"
  }
}
*/

# lb config
resource "azurerm_lb" "mylb" {
  resource_group_name = data.azurerm_resource_group.myterraformgroup.name
  name                = "web-lb"
  location            = "eastus"
  sku                 = "Standard"
  frontend_ip_configuration {
    name                 = "lb_ipconfig"
    public_ip_address_id = data.azurerm_public_ip.lb_pip.id
  }
}
#lb backend pool
resource "azurerm_lb_backend_address_pool" "lb_backend_pool" {
  resource_group_name = data.azurerm_resource_group.myterraformgroup.name
  loadbalancer_id     = azurerm_lb.mylb.id
  name                = "Backend-pool"
}
#lb probe
resource "azurerm_lb_probe" "probe1" {
  resource_group_name = data.azurerm_resource_group.myterraformgroup.name
  loadbalancer_id     = azurerm_lb.mylb.id
  name                = "probe1"
  protocol            = "tcp"
  port                = 80
  interval_in_seconds = 5
  number_of_probes    = 3
}
resource "azurerm_lb_probe" "probe2" {
  resource_group_name = data.azurerm_resource_group.myterraformgroup.name
  loadbalancer_id     = azurerm_lb.mylb.id
  name                = "probe2"
  protocol            = "tcp"
  port                = 443
  interval_in_seconds = 5
  number_of_probes    = 3
}
#azure lb rule
resource "azurerm_lb_rule" "lb_rule1" {
  resource_group_name            = data.azurerm_resource_group.myterraformgroup.name
  loadbalancer_id                = azurerm_lb.mylb.id
  name                           = "lb-rule1"
  protocol                       = "tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "lb_ipconfig"
  enable_floating_ip             = false
  backend_address_pool_id        = azurerm_lb_backend_address_pool.lb_backend_pool.id
  idle_timeout_in_minutes        = 5
  probe_id                       = azurerm_lb_probe.probe1.id
}
resource "azurerm_lb_rule" "lb_rule2" {
  resource_group_name            = data.azurerm_resource_group.myterraformgroup.name
  loadbalancer_id                = azurerm_lb.mylb.id
  name                           = "lb-rule2"
  protocol                       = "tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "lb_ipconfig"
  enable_floating_ip             = false
  backend_address_pool_id        = azurerm_lb_backend_address_pool.lb_backend_pool.id
  idle_timeout_in_minutes        = 5
  probe_id                       = azurerm_lb_probe.probe2.id
}

#link netw-interface with backend pool
resource "azurerm_network_interface_backend_address_pool_association" "network_interface_backend_address_pool_association1" {
  network_interface_id    = azurerm_network_interface.myterraformnic1.id
  ip_configuration_name   = "web-ni-conf-1"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb_backend_pool.id
}

resource "azurerm_network_interface_backend_address_pool_association" "network_interface_backend_address_pool_association2" {
  network_interface_id    = azurerm_network_interface.myterraformnic2.id
  ip_configuration_name   = "web-ni-conf-2"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lb_backend_pool.id
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "myterraformnsg" {
  name                = "NSG-web-1"
  location            = "eastus"
  resource_group_name = data.azurerm_resource_group.myterraformgroup.name

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "Http"
    priority                   = 900
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "https_port"
    priority                   = 998
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  tags = {
    environment = "Terraform Demo"
  }
}


# create av set
resource "azurerm_availability_set" "av-set-1" {
  name                = "aset-1"
  location            = data.azurerm_resource_group.myterraformgroup.location
  resource_group_name = data.azurerm_resource_group.myterraformgroup.name
  tags = {
    environment = "Production"
  }
}
# Create network interface
resource "azurerm_network_interface" "myterraformnic1" {
  name                = "myNIC1"
  location            = "eastus"
  resource_group_name = data.azurerm_resource_group.myterraformgroup.name

  ip_configuration {
    name                          = "web-ni-conf-1"
    subnet_id                     = azurerm_subnet.myterraformsubnet1.id
    private_ip_address            = "10.0.1.4"
    private_ip_address_allocation = "Static"
    #public_ip_address_id          = azurerm_public_ip.myterraformpublicip.id
  }

  tags = {
    environment = "Terraform Demo"
  }
}

resource "azurerm_network_interface" "myterraformnic2" {
  name                = "myNIC2"
  location            = "eastus"
  resource_group_name = data.azurerm_resource_group.myterraformgroup.name

  ip_configuration {
    name                          = "web-ni-conf-2"
    subnet_id                     = azurerm_subnet.myterraformsubnet1.id
    private_ip_address            = "10.0.1.5"
    private_ip_address_allocation = "Static"
    #  public_ip_address_id          = azurerm_public_ip.myterraformpublicip2.id
  }

  tags = {
    environment = "Terraform Demo"
  }
}




# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.myterraformnic1.id
  network_security_group_id = azurerm_network_security_group.myterraformnsg.id
}
resource "azurerm_network_interface_security_group_association" "example2" {
  network_interface_id      = azurerm_network_interface.myterraformnic2.id
  network_security_group_id = azurerm_network_security_group.myterraformnsg.id
}


# Generate random text for a unique storage account name
resource "random_id" "randomId" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = data.azurerm_resource_group.myterraformgroup.name
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mystorageaccount" {
  name                     = "diag${random_id.randomId.hex}"
  resource_group_name      = data.azurerm_resource_group.myterraformgroup.name
  location                 = "eastus"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "Terraform Demo"
  }
}



# Create (and display) an SSH key
data "tls_public_key" "example_ssh" {
  private_key_pem = file("~/.ssh/id_rsa")
}
output "tls_private_key" {
  value = data.tls_public_key.example_ssh.public_key_openssh
}



# Create virtual machine
resource "azurerm_linux_virtual_machine" "myterraformvm1" {
  name                  = "myVM1"
  location              = "eastus"
  resource_group_name   = data.azurerm_resource_group.myterraformgroup.name
  network_interface_ids = [azurerm_network_interface.myterraformnic1.id]
  size                  = "Standard_DS1_v2"
  availability_set_id   = azurerm_availability_set.av-set-1.id
  os_disk {
    name                 = "myOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }
  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  custom_data                     = base64encode(file("init.sh"))
  computer_name                   = "myvm1"
  admin_username                  = "azureuser"
  disable_password_authentication = true
  admin_ssh_key {
    username   = "azureuser"
    public_key = data.tls_public_key.example_ssh.public_key_openssh
  }
}

resource "azurerm_linux_virtual_machine" "myterraformvm2" {
  name                  = "myVM2"
  location              = "eastus"
  resource_group_name   = data.azurerm_resource_group.myterraformgroup.name
  network_interface_ids = [azurerm_network_interface.myterraformnic2.id]
  size                  = "Standard_DS1_v2"
  availability_set_id   = azurerm_availability_set.av-set-1.id

  os_disk {
    name                 = "myOsDisk2"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
  custom_data                     = base64encode(file("init2.sh"))
  computer_name                   = "myvm2"
  admin_username                  = "azureuser"
  disable_password_authentication = true
  admin_ssh_key {
    username   = "azureuser"
    public_key = data.tls_public_key.example_ssh.public_key_openssh
  }
}
