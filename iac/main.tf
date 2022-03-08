# Warning! Using 3.0 beta resources and so the following is required 
# $env:ARM_THREEPOINTZERO_BETA_RESOURCES = "true"

terraform {
  required_version = "=1.1.7"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=2.98.0"
    }
    random = "=3.1.0"
  }

  backend "azurerm" {
    resource_group_name  = "common"
    storage_account_name = "intellitectcommon"
    container_name       = "tfstate"
    key                  = "intellitect-com.tfstate"
  }
}


provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "intellitect_com" {
  name     = "intellitect-com"
  location = "westus2"
}

########################
# network
########################

resource "azurerm_virtual_network" "vnet" {
  name                = "intellitect-com-vnet"
  location            = azurerm_resource_group.intellitect_com.location
  resource_group_name = azurerm_resource_group.intellitect_com.name
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "mysqlsubnet" {
  name                 = "mysql-sn"
  resource_group_name  = azurerm_resource_group.intellitect_com.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.1.2.0/24"]
  service_endpoints    = ["Microsoft.Storage"]
  delegation {
    name = "fs"
    service_delegation {
      name = "Microsoft.DBforMySQL/flexibleServers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

########################
# storage
########################

# resource "azurerm_subnet" "storagesubnet" {
# }

resource "azurerm_storage_account" "sa" {
  name                     = "intellitectcomwpcontent"
  resource_group_name      = azurerm_resource_group.intellitect_com.name
  location                 = azurerm_resource_group.intellitect_com.location
  account_kind             = "StorageV2"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
    environment = "prod"
  }

}

resource "azurerm_storage_share" "sashare" {
  name                 = "wpcontent"
  storage_account_name = azurerm_storage_account.sa.name
  quota                = 50
}

########################
# mysql
########################

resource "azurerm_private_dns_zone" "dnszone" {
  name                = "intellitectcom.mysql.database.azure.com"
  resource_group_name = azurerm_resource_group.intellitect_com.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "vnetlink" {
  name                  = "mysqlvnetzone.com"
  private_dns_zone_name = azurerm_private_dns_zone.dnszone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  resource_group_name   = azurerm_resource_group.intellitect_com.name
}

resource "azurerm_mysql_flexible_server" "mysql" {
  name                   = "intellitect-com-mysql-fs"
  resource_group_name    = azurerm_resource_group.intellitect_com.name
  location               = azurerm_resource_group.intellitect_com.location
  administrator_login    = var.mysql_admin
  administrator_password = var.mysql_admin_password
  backup_retention_days  = 7
  delegated_subnet_id    = azurerm_subnet.mysqlsubnet.id
  private_dns_zone_id    = azurerm_private_dns_zone.dnszone.id
  sku_name               = "GP_Standard_D2ds_v4"
  zone = "1"

  depends_on = [azurerm_private_dns_zone_virtual_network_link.vnetlink]
}

########################
# virtual machine
########################

resource "azurerm_subnet" "internal_sn" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.intellitect_com.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.1.1.0/24"]
}

resource "azurerm_network_interface" "nic" {
  name                = "vm-nic"
  location            = azurerm_resource_group.intellitect_com.location
  resource_group_name = azurerm_resource_group.intellitect_com.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.internal_sn.id
    private_ip_address_allocation = "Dynamic"
  }
}

data "azurerm_ssh_public_key" "util_vm_key" {
  name                = "util-vm-key"
  resource_group_name = azurerm_resource_group.intellitect_com.name
}


resource "azurerm_linux_virtual_machine" "vm" {
  name                = "util-vm"
  resource_group_name = azurerm_resource_group.intellitect_com.name
  location            = azurerm_resource_group.intellitect_com.location
  size                = "Standard_F2"
  admin_username      = var.vm_admin
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  admin_ssh_key {
    username   = var.vm_admin
    public_key = data.azurerm_ssh_public_key.util_vm_key.public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

### todo: Bastion
# subnet
# bastion service

########################
# linux app
########################

# linux app service

resource "azurerm_app_service_plan" "app_plan" {
  name                = "intellitect-com-plan"
  location            = azurerm_resource_group.intellitect_com.location
  resource_group_name = azurerm_resource_group.intellitect_com.name
  kind                = "Linux"
  reserved            = true

  sku {
    tier = "Standard"
    size = "S1"
  }
}

# php app service
resource "azurerm_linux_web_app" "intellitect_com" {
  name                = "intellitect-com"
  location            = azurerm_resource_group.intellitect_com.location
  resource_group_name = azurerm_resource_group.intellitect_com.name
  service_plan_id = azurerm_app_service_plan.app_plan.id

  site_config {
    application_stack {
      docker_image = "appsvc/wordpress-alpine-php"
      docker_image_tag = "latest"
    }
  }

  storage_account {
    name = "wpcontent2"
    type = "AzureFiles"
    account_name = azurerm_storage_account.sa.name
    access_key = azurerm_storage_account.sa.primary_access_key
    share_name = azurerm_storage_share.sashare.name 
    mount_path = "/home/site/wwwroot/wp-content"
  }

  app_settings = {
    "DATABASE_HOST"                       = azurerm_mysql_flexible_server.mysql.name
    "DATABASE_NAME"                       = var.db_name
    "DATABASE_PASSWORD"                   = var.mysql_admin
    "DATABASE_USERNAME"                   = var.mysql_admin_password
    "DOCKER_REGISTRY_SERVER_URL"          = "https://mcr.microsoft.com"
    "WEBSITES_CONTAINER_START_TIME_LIMIT" = 900
    "WEBSITES_ENABLE_APP_SERVICE_STORAGE" = true
    "WORDPRESS_ADMIN_EMAIL"               = var.wp_admin_email
    "WORDPRESS_ADMIN_PASSWORD"            = var.wp_admin_password
    "WORDPRESS_ADMIN_USER"                = var.wp_admin_user
    "WORDPRESS_TITLE"                     = var.wp_admin_title
  }

}

###  https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/app_service_source_control#container_configuration
# resource "azurerm_app_service_source_control" "deploy" {
#   app_id = azurerm_app_service.intellitect_com.id
#   repo_url = ""
#   branch = ""

#   container_configuration {
#     image_name = "appsvc/wordpress-alpine-php:latest"
#     registry_url = "https://mcr.microsoft.com"
#   }
# }  


resource "azurerm_subnet" "app_subnet" {
  name                 = "webapp"
  resource_group_name  = azurerm_resource_group.intellitect_com.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.1.4.0/24"]
  delegation {
    name = "webapp"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

resource "azurerm_app_service_virtual_network_swift_connection" "app_subnet_connection" {
  app_service_id = azurerm_linux_web_app.intellitect_com.id
  subnet_id      = azurerm_subnet.app_subnet.id
}


