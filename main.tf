terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "0.107.0"
    }
    local = {
      source = "hashicorp/local"
      version = "2.4.0"
    }
  }
}

variable "yc_iam_token" {}
variable "yc_cloud_id" {}
variable "yc_folder_id" {}

variable "yc_network_name" {
  default = "default"
}

variable "yc_zone_id" {
  default = "ru-central1-a"
}

provider yandex {
  token     = var.yc_iam_token
  cloud_id  = var.yc_cloud_id
  folder_id = var.yc_folder_id
}

data yandex_compute_image ubuntu {
  family = "ubuntu-2204-lts"
}

resource yandex_iam_service_account vpn_sa {
  name = "vpn-sa"
}

resource yandex_resourcemanager_folder_iam_member vpn_sa_iam_member {
  role      = "editor"
  member    = "serviceAccount:${yandex_iam_service_account.vpn_sa.id}"
  folder_id = "${var.yc_folder_id}"
}

data yandex_vpc_subnet subnet {
  name      = "${var.yc_network_name}-${var.yc_zone_id}"
  folder_id = "${var.yc_folder_id}"
}

resource yandex_vpc_address vpn_public_address {
  name        = "vpn-public-address"

  external_ipv4_address {
    zone_id                  = "${var.yc_zone_id}"
  }
}

resource yandex_compute_instance_group vpn_instance_group {
  depends_on          = [yandex_resourcemanager_folder_iam_member.vpn_sa_iam_member]
  name                = "vpn-instance-group"
  service_account_id  = "${yandex_iam_service_account.vpn_sa.id}"
  instance_template {
    platform_id = "standard-v3"

    resources {
      memory        = 2
      cores         = 2
      core_fraction = 50
    }

    boot_disk {
      initialize_params {
        image_id = "${data.yandex_compute_image.ubuntu.id}"
        size     = 8
      }
    }

    network_interface {
      network_id     = "${data.yandex_vpc_subnet.subnet.network_id}"
      subnet_ids     = ["${data.yandex_vpc_subnet.subnet.id}"]
      nat            = true
      nat_ip_address = "${yandex_vpc_address.vpn_public_address.external_ipv4_address[0].address}"
    }

    scheduling_policy {
      preemptible = true
    }

    metadata = {
      ssh-keys = "ubuntu:${file("~/.ssh/id_rsa.pub")}"
    }
  }

  scale_policy {
    fixed_scale {
      size = 1
    }
  }

  allocation_policy {
    zones = ["ru-central1-a"]
  }

  deploy_policy {
    max_unavailable = 3
    max_creating    = 3
    max_expansion   = 3
    max_deleting    = 3
  }
}

resource local_file ansible_inventory {
  filename = "inventory"
  content  = "${yandex_vpc_address.vpn_public_address.external_ipv4_address[0].address} ansible_user=ubuntu"
}
