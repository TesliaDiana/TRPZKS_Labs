terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

resource "libvirt_cloudinit_disk" "commoninit" {
  name      = "commoninit.iso"
  user_data = templatefile("${path.module}/cloud_init.cfg", {
    ssh_key = trimspace(file("/home/teacher/.ssh/id_rsa.pub"))
  })

  network_config = <<EOF
version: 2
ethernets:
  enp1s0:
    dhcp4: true
  ens3:
    dhcp4: true
EOF

  pool = "default"
}

resource "libvirt_volume" "ubuntu-qcow2" {
  name   = "ubuntu-qcow2"
  pool   = "default"
  source = "${path.module}/noble-server-cloudimg-amd64.img"
  format = "qcow2"
}

resource "libvirt_domain" "worker-node" {
  name   = "worker-node"
  memory = "1024"
  vcpu   = 1

  cloudinit = libvirt_cloudinit_disk.commoninit.id

  network_interface {
    network_name   = "default"
    wait_for_lease = false
  }

  disk {
    volume_id = libvirt_volume.ubuntu-qcow2.id
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
  }
}