output "username" {
  value = local.username
}
output "controlplanes" {
  value = module.controlplane
}

output "workers" {
  value = module.worker
}