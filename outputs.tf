output "vm_external_ips" {
  description = "External IP addresses of the VMs"
  value       = [for vm in yandex_compute_instance.nginx-vm : vm.network_interface.0.nat_ip_address]
}

output "load_balancer_ip" {
  description = "External IP address of the load balancer"
  value       = one([for listener in yandex_lb_network_load_balancer.nginx-balancer.listener : one(listener.external_address_spec).address])
}

output "target_group_id" {
  description = "ID of the target group"
  value       = yandex_lb_target_group.nginx-target-group.id
}
