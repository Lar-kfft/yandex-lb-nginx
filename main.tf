# Используем существующую подсеть по умолчанию
data "yandex_vpc_subnet" "default" {
  name = "default-ru-central1-a"
}

# Создание двух идентичных виртуальных машин с использованием count
resource "yandex_compute_instance" "nginx-vm" {
  count = 2
  
  name        = "nginx-vm-${count.index + 1}"
  platform_id = "standard-v3"
  zone        = "ru-central1-a"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd827b91d99psvq5fjit" # Ubuntu 22.04 LTS
      size     = 10
    }
  }

  network_interface {
    subnet_id = data.yandex_vpc_subnet.default.id
    nat       = true
  }

  metadata = {
    ssh-keys = "ubuntu:${file(var.ssh_public_key)}"
    user-data = <<-EOT
      #cloud-config
      package_update: true
      package_upgrade: true
      packages:
        - nginx
      runcmd:
        - systemctl enable nginx
        - systemctl start nginx
        - echo "<html><body><h1>Hello from VM ${count.index + 1} - $(hostname)</h1></body></html>" > /var/www/html/index.html
        - systemctl restart nginx
    EOT
  }

  scheduling_policy {
    preemptible = true
  }
}

# Создание целевой группы
resource "yandex_lb_target_group" "nginx-target-group" {
  name      = "nginx-target-group"
  region_id = "ru-central1"

  dynamic "target" {
    for_each = yandex_compute_instance.nginx-vm
    content {
      subnet_id = target.value.network_interface.0.subnet_id
      address   = target.value.network_interface.0.ip_address
    }
  }
}

# Создание сетевого балансировщика нагрузки
resource "yandex_lb_network_load_balancer" "nginx-balancer" {
  name = "nginx-network-balancer"

  listener {
    name = "nginx-listener"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.nginx-target-group.id

    healthcheck {
      name = "http-healthcheck"
      timeout = 1
      interval = 2
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}
