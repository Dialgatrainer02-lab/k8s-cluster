output "inventory" {
  value = local.inventory
}

output "controlplanes" {
  value = module.controlplane
}

output "workers" {
  value = module.worker
}