provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "masa-rg" {
  name     = "masa-rg"
  location = "Japan East"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "masa-network"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.masa-rg.location
  resource_group_name = azurerm_resource_group.masa-rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.masa-rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [ "10.0.2.0/24" ]
}

resource "azurerm_public_ip" "public_ip" {
	name = "consul-ip"
	location = azurerm_resource_group.masa-rg.location
	resource_group_name = azurerm_resource_group.masa-rg.name
	allocation_method = "Static"
	domain_name_label = "masa"
	idle_timeout_in_minutes = 30
	
	tags = {
		environment = "consul test"
		Owner = "masa@hashicorp.com"
	}
}

resource "azurerm_network_interface" "nic" {
  name                = "masa-nic"
  location            = azurerm_resource_group.masa-rg.location
  resource_group_name = azurerm_resource_group.masa-rg.name

  ip_configuration {
    name                          = "consul-test"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address = "10.0.2.5"
		public_ip_address_id = azurerm_public_ip.public_ip.id
  }
}

resource "azurerm_linux_virtual_machine" "consul" {
  name                = "consul-server"
  resource_group_name = azurerm_resource_group.masa-rg.name
  location            = azurerm_resource_group.masa-rg.location
  size                = "Standard_F2"
  admin_username      = "masa"
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  admin_ssh_key {
    username   = "masa"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
}

data "azurerm_public_ip" "public_ip" {
  name                = azurerm_public_ip.public_ip.name
  resource_group_name = azurerm_resource_group.masa-rg.name
}

output "public_ip" {
	value = <<EOF

Data from azurerm_public_ip
	Public IP: ${data.azurerm_public_ip.public_ip.ip_address}
	FQDN: ${data.azurerm_public_ip.public_ip.fqdn}
EOF

}
