# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.65"
    }
  }

  required_version = ">= 0.14.9"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "projProd"
  location = "southeastasia"
}

# VnetTest

# Create a virtual network
resource "azurerm_virtual_network" "vnet1" {
  name                = "projVnet1Prod"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}


resource "azurerm_virtual_network" "vnet2" {
  name                = "projVnet2Prod"
  address_space       = ["10.1.0.0/16"]
  location            = "eastasia"
  resource_group_name = azurerm_resource_group.rg.name
}

# Create a subnet vnet1
resource "azurerm_subnet" "snetpr1" {
  name                 = "privateSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_subnet" "snetpu1" {
  name                 = "PublicSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet1.name
  address_prefixes     = ["10.0.1.0/24"]
}
# Create a subnet vnet2
resource "azurerm_subnet" "snetpr2" {
  name                 = "privateSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet2.name
  address_prefixes     = ["10.1.0.0/24"]
}

resource "azurerm_subnet" "snetpu2" {
  name                 = "PublicSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet2.name
  address_prefixes     = ["10.1.1.0/24"]
}

# Create a Public route table vnet1
resource "azurerm_route_table" "rt1" {
  name                          = "Vnet1PublicSubnetsRoutes"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  disable_bgp_route_propagation = false

  route {
    name           = "localRoute"
    address_prefix = "10.0.0.0/16"
    next_hop_type  = "vnetlocal"
  }

  route {
    name           = "internetRoute"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "Internet"
  }
}
resource "azurerm_subnet_route_table_association" "strta1" {
  subnet_id      = azurerm_subnet.snetpu1.id
  route_table_id = azurerm_route_table.rt1.id
}

# Create a Private route table vnet1
resource "azurerm_route_table" "rt3" {
  name                          = "Vnet1PrivateSubnetsRoutes"
  location                      = azurerm_resource_group.rg.location
  resource_group_name           = azurerm_resource_group.rg.name
  disable_bgp_route_propagation = false

  route {
    name           = "localRoute"
    address_prefix = "10.0.0.0/16"
    next_hop_type  = "vnetlocal"
  }
}
resource "azurerm_subnet_route_table_association" "strta3" {
  subnet_id      = azurerm_subnet.snetpr1.id
  route_table_id = azurerm_route_table.rt1.id
}


# Create a Public route table vnet2
resource "azurerm_route_table" "rt2" {
  name                          = "Vnet2PublicSubnetsRoutes"
  location                      = "eastasia"
  resource_group_name           = azurerm_resource_group.rg.name
  disable_bgp_route_propagation = false

  route {
    name           = "localRoute"
    address_prefix = "10.1.0.0/16"
    next_hop_type  = "vnetlocal"
  }

  route {
    name           = "internetRoute"
    address_prefix = "0.0.0.0/0"
    next_hop_type  = "Internet"
  }
}
resource "azurerm_subnet_route_table_association" "strta2" {
  subnet_id      = azurerm_subnet.snetpu2.id
  route_table_id = azurerm_route_table.rt2.id
}

# Create a Private route table vnet2
resource "azurerm_route_table" "rt4" {
  name                          = "Vnet2PrivateSubnetsRoutes"
  location                      = "eastasia"
  resource_group_name           = azurerm_resource_group.rg.name
  disable_bgp_route_propagation = false

  route {
    name           = "localRoute"
    address_prefix = "10.1.0.0/16"
    next_hop_type  = "vnetlocal"
  }
}
resource "azurerm_subnet_route_table_association" "strta4" {
  subnet_id      = azurerm_subnet.snetpr2.id
  route_table_id = azurerm_route_table.rt2.id
}

# nat gateway vnet1 & subnet nat gatway 
resource "azurerm_nat_gateway" "natg1" {
  name                = "Vnet1PrivateSubnetsNatGateway"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "Standard"
  zones               = ["1"]
}

resource "azurerm_subnet_nat_gateway_association" "snatg1" {
  subnet_id      = azurerm_subnet.snetpr1.id
  nat_gateway_id = azurerm_nat_gateway.natg1.id
}

# enable global peering between the two virtual network
resource "azurerm_virtual_network_peering" "vnetpeering" {
  name                         = "VnetGlobalPeering"
  resource_group_name          = azurerm_resource_group.rg.name
  virtual_network_name         = azurerm_virtual_network.vnet1.name
  remote_virtual_network_id    = azurerm_virtual_network.vnet2.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
}

# network security group for vnet1 public subnet
resource "azurerm_network_security_group" "nsgpu1" {
  name                = "Vnet1PublicSubnetNetworkSecurityGroup"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Web180"
    priority                   = 201
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "TCP"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "10.0.1.0/24"
    destination_port_range     = "80"
  }

  security_rule {
    name                       = "alls"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "TCP"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
resource "azurerm_subnet_network_security_group_association" "snetnsg1" {
  subnet_id                 = azurerm_subnet.snetpu1.id
  network_security_group_id = azurerm_network_security_group.nsgpu1.id
}

# network security group for vnet2 public subnet
resource "azurerm_network_security_group" "nsgpu2" {
  name                = "Vnet2PublicSubnetNetworkSecurityGroup"
  location            = "eastasia"
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Inbound"
    priority                   = 201
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "TCP"
    source_port_range          = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "10.1.1.0/24"
    destination_port_range     = "80"
  }

  security_rule {
    name                       = "Outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "TCP"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
resource "azurerm_subnet_network_security_group_association" "snetnsg2" {
  subnet_id                 = azurerm_subnet.snetpu2.id
  network_security_group_id = azurerm_network_security_group.nsgpu2.id
}

# network security group for vnet1 Private subnet
resource "azurerm_network_security_group" "nsgpr1" {
  name                = "Vnet1PrivateSubnetNetworkSecurityGroup"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "inbound"
    priority                   = 201
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "TCP"
    source_port_range          = "*"
    source_address_prefix      = "10.1.0.0/24"
    destination_address_prefix = "10.0.0.0/24"
    destination_port_range     = "80"
  }

  security_rule {
    name                       = "outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "TCP"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
resource "azurerm_subnet_network_security_group_association" "snetnsg3" {
  subnet_id                 = azurerm_subnet.snetpr1.id
  network_security_group_id = azurerm_network_security_group.nsgpr1.id
}

# network security group for vnet2 Private subnet
resource "azurerm_network_security_group" "nsgpr2" {
  name                = "Vnet2PrivateSubnetNetworkSecurityGroup"
  location            = "eastasia"
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "inbound"
    priority                   = 201
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "TCP"
    source_port_range          = "*"
    source_address_prefix      = "10.0.0.0/24"
    destination_address_prefix = "10.1.0.0/24"
    destination_port_range     = "80"
  }

  security_rule {
    name                       = "outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "TCP"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
resource "azurerm_subnet_network_security_group_association" "snetnsg4" {
  subnet_id                 = azurerm_subnet.snetpr2.id
  network_security_group_id = azurerm_network_security_group.nsgpr2.id
}

#AppServiceTest
resource "azurerm_app_service_plan" "appapi" {
  name                = "appserviceplan-api"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "FunctionApp"
  sku {
    tier = "Dynamic"
    size = "Y1"
  }
  tags = {
    key = "AppServicePlan"
  }
}

#FunctionApp
resource "azurerm_function_app" "webftapp" {
  name                      = "web625functionapp"
  location                  = azurerm_resource_group.rg.location
  resource_group_name       = azurerm_resource_group.rg.name
  storage_connection_string = azurerm_storage_account.websa.primary_connection_string
  app_service_plan_id       = azurerm_app_service_plan.appapi.id
  version                   = "~3"

  app_settings = {
    FUNCTIONS_WORKER_RUNTIME     = "node"
    WEBSITE_NODE_DEFAULT_VERSION = "~14"
    WEBSITE_RUN_FROM_PACKAGE     = "https://websaccount.blob.core.windows.net/code/zips/app.zip"
  }
  tags = {
    key = "FunctionApp"
  }
}


#ApplicationInsightTest
resource "azurerm_log_analytics_workspace" "accwp" {
  name                = "acctest-01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  retention_in_days   = 30
}
resource "azurerm_application_insights" "example" {
  name                = "tf-test-appinsights"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  workspace_id        = azurerm_log_analytics_workspace.accwp.id
  application_type    = "other"
  retention_in_days   = 30
  tags = {
    key = "ApplicationInsights"
  }
}

#storage_accountTest
resource "azurerm_storage_account" "loisa" {
  name                     = "losaaccount"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = "southeastasia"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  allow_blob_public_access = true

  tags = {
    usage = "logic"
  }
}

resource "azurerm_storage_account" "websa" {
  name                     = "websaccount"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = "eastasia"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  allow_blob_public_access = false

  tags = {
    usage = "StaticWeb"
  }
}
