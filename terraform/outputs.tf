output "resource_group_name" {
  value = data.azurerm_resource_group.main.name
}

output "kubernetes_cluster_name" {
  value = azurerm_kubernetes_cluster.k8s.name
}

output "cluster_ca_certificate" {
  value     = azurerm_kubernetes_cluster.k8s.kube_config[0].cluster_ca_certificate
  sensitive = true
}

output "kube_config" {
  value     = azurerm_kubernetes_cluster.k8s.kube_config_raw
  sensitive = true
}

output "kubernetes_cluster_name_prod" {
  value = azurerm_kubernetes_cluster.k8s_prod.name
}

output "cluster_ca_certificate_prod" {
  value     = azurerm_kubernetes_cluster.k8s_prod.kube_config[0].cluster_ca_certificate
  sensitive = true
}

output "kube_config_prod" {
  value     = azurerm_kubernetes_cluster.k8s_prod.kube_config_raw
  sensitive = true
}
