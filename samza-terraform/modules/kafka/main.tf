locals {
  virtual_machine_name = "${var.prefix}-${var.kafka-prefix}-vm"
}

resource "azurerm_public_ip" "kafka_public_ip" {
  name                = "${var.prefix}-${var.kafka-prefix}-publicip"
  resource_group_name = "${data.azurerm_resource_group.resource_group.name}"
  location            = "${data.azurerm_resource_group.resource_group.location}"
  allocation_method   = "Static" # TODO: Use Dynamic (Blocker: for some reason remote-exec fails to pick up IP with set to Dynamic)
}


resource "azurerm_network_interface" "kafka_nic" {
  name                      = "${var.prefix}-${var.kafka-prefix}-nic"
  location                  = "${data.azurerm_resource_group.resource_group.location}"
  resource_group_name       = "${data.azurerm_resource_group.resource_group.name}"
  network_security_group_id = "${data.azurerm_network_security_group.kafka_nsg.id}"

  ip_configuration {
    name                          = "configuration"
    subnet_id                     = "${data.azurerm_subnet.kafka_subnet.id}"
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.kafka_public_ip.id}" # TODO: Figure out a way not to use public IPs
  }
}

resource "azurerm_virtual_machine" "kafka_instance" {
  name                  = "${local.virtual_machine_name}"
  location              = "${data.azurerm_resource_group.resource_group.location}"
  resource_group_name   = "${data.azurerm_resource_group.resource_group.name}"
  network_interface_ids = ["${azurerm_network_interface.kafka_nic.id}"]
  vm_size               = "${var.vm_size}" # TODO: Replace this with a var

  # This means the OS Disk will be deleted when Terraform destroys the Virtual Machine
  # NOTE: This may not be optimal in all cases.
  delete_os_disk_on_termination = true

  storage_image_reference {
    publisher = var.storage_image_publisher
    offer     = var.storage_image_offer
    sku       = var.storage_image_sku
    version   = var.storage_image_version
  }

  storage_os_disk {
    name              = "${var.prefix}-${var.kafka-prefix}-osdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "${local.virtual_machine_name}"
    admin_username = "${var.username}"
    admin_password = "${var.password}"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }

  provisioner "file" {
    connection {
      user     = "${var.username}"
      password = "${var.password}"
      host = "${azurerm_public_ip.kafka_public_ip.ip_address}"
    }

    source      = "${path.module}/bin/kafka.sh"
    destination = "kafka.sh"
  }

  provisioner "file" {
    connection {
      user     = "${var.username}"
      password = "${var.password}"
      host = "${azurerm_public_ip.kafka_public_ip.ip_address}"
    }

    content = "${data.template_file.kafka_config.rendered}"
    destination = "server.properties"
  }

  provisioner "remote-exec" {
    connection {
      user     = "${var.username}"
      password = "${var.password}"
      host = "${azurerm_public_ip.kafka_public_ip.ip_address}"
    }

    inline = [
      "echo ${var.password} | sudo -S yum install -y java-1.8.0-openjdk-headless",
      "sudo yum install -y nc",
      "chmod +x kafka.sh",
      "bash kafka.sh start"
    ]
  }
}