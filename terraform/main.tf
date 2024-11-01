data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

resource "azurerm_kubernetes_cluster" "k8s" {
  location            = data.azurerm_resource_group.main.location
  name                = "${var.aks_name_prefix}-staging"
  resource_group_name = data.azurerm_resource_group.main.name
  dns_prefix          = "${var.aks_name_prefix}-staging"

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name       = "agentpool"
    vm_size    = "Standard_D2_v2"
    node_count = var.node_count
  }

  linux_profile {
    admin_username = var.username

    ssh_key {
      key_data = file("~/.ssh/id_rsa.pub")
    }
  }

  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"
  }
}

resource "azurerm_kubernetes_cluster" "k8s_prod" {
  location            = data.azurerm_resource_group.main.location
  name                = "${var.aks_name_prefix}-production"
  resource_group_name = data.azurerm_resource_group.main.name
  dns_prefix          = "${var.aks_name_prefix}-production"

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name       = "agentpool"
    vm_size    = "Standard_D2_v2"
    node_count = var.node_count
  }

  linux_profile {
    admin_username = var.username

    ssh_key {
      key_data = file("~/.ssh/id_rsa.pub")
    }
  }

  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"
  }
}
