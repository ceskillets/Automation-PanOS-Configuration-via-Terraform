provider "panos" {
  hostname = "${var.panos_hostname}"
  username = "${var.panos_username}"
  password = "${var.panos_password}"
}

resource "panos_ethernet_interface" "eth1" {
  name       = "ethernet1/1"
  vsys       = "vsys1"
  mode       = "layer3"
  static_ips = ["192.168.55.20/24"]
}

resource "panos_ethernet_interface" "eth2" {
  name       = "ethernet1/2"
  vsys       = "vsys1"
  mode       = "layer3"
  static_ips = ["192.168.45.20/24"]
}

resource "panos_ethernet_interface" "eth3" {
  name       = "ethernet1/3"
  vsys       = "vsys1"
  mode       = "layer3"
  static_ips = ["192.168.35.20/24"]
}

resource "panos_zone" "untrust" {
  name       = "untrust"
  mode       = "layer3"
  interfaces = ["${panos_ethernet_interface.eth1.name}"]
}

resource "panos_zone" "web" {
  name       = "web"
  mode       = "layer3"
  interfaces = ["${panos_ethernet_interface.eth2.name}"]
}

resource "panos_zone" "db" {
  name       = "db"
  mode       = "layer3"
  interfaces = ["${panos_ethernet_interface.eth3.name}"]
}

resource "panos_virtual_router" "default" {
  name = "default"

  interfaces = [
    "${panos_ethernet_interface.eth1.name}",
    "${panos_ethernet_interface.eth2.name}",
    "${panos_ethernet_interface.eth3.name}",
  ]
}

resource "panos_static_route_ipv4" "default" {
  name           = "default"
  virtual_router = "${panos_virtual_router.default.name}"
  destination    = "0.0.0.0/0"
  next_hop       = "192.168.55.2"
}

resource "panos_address_object" "web-srv" {
  name  = "web-srv"
  value = "192.168.45.5"
}

resource "panos_address_object" "db-srv" {
  name  = "db-srv"
  value = "192.168.35.5"
}

resource "panos_service_object" "service-tcp-221" {
  name             = "service-tcp-221"
  protocol         = "tcp"
  destination_port = "221"
}

resource "panos_service_object" "service-tcp-222" {
  name             = "service-tcp-222"
  protocol         = "tcp"
  destination_port = "222"
}

resource "panos_security_policy" "rulebase" {
  rule {
    name                  = "Allow ping"
    source_zones          = ["any"]
    source_addresses      = ["any"]
    source_users          = ["any"]
    hip_profiles          = ["any"]
    destination_zones     = ["any"]
    destination_addresses = ["any"]
    applications          = ["ping"]
    services              = ["application-default"]
    categories            = ["any"]
  }

  rule {
    name                  = "SSH inbound"
    source_zones          = ["${panos_zone.untrust.name}"]
    source_addresses      = ["any"]
    source_users          = ["any"]
    hip_profiles          = ["any"]
    destination_zones     = ["${panos_zone.web.name}", "${panos_zone.db.name}"]
    destination_addresses = ["any"]
    applications          = ["ping", "ssh"]

    services = [
      "${panos_service_object.service-tcp-221.name}",
      "${panos_service_object.service-tcp-222.name}",
    ]

    categories = ["any"]
  }

  rule {
    name                  = "Web inbound"
    source_zones          = ["${panos_zone.untrust.name}"]
    source_addresses      = ["any"]
    source_users          = ["any"]
    hip_profiles          = ["any"]
    destination_zones     = ["${panos_zone.web.name}"]
    destination_addresses = ["any"]
    applications          = ["any"]
    services              = ["service-http"]
    categories            = ["any"]
  }

  rule {
    name                  = "Web to DB"
    source_zones          = ["any"]
    source_addresses      = ["${panos_address_object.web-srv.name}"]
    source_users          = ["any"]
    hip_profiles          = ["any"]
    destination_zones     = ["any"]
    destination_addresses = ["${panos_address_object.db-srv.name}"]
    applications          = ["mysql"]
    services              = ["application-default"]
    categories            = ["any"]
  }

  rule {
    name                  = "Allow outbound"
    source_zones          = ["${panos_zone.db.name}", "${panos_zone.web.name}"]
    source_addresses      = ["any"]
    source_users          = ["any"]
    hip_profiles          = ["any"]
    destination_zones     = ["${panos_zone.untrust.name}"]
    destination_addresses = ["any"]
    applications          = ["any"]
    services              = ["application-default"]
    categories            = ["any"]
  }
}

resource "panos_nat_rule_group" "nat" {
  rule {
    name = "Web SSH"

    original_packet {
      source_zones          = ["${panos_zone.untrust.name}"]
      source_addresses      = ["any"]
      destination_zone      = "${panos_zone.untrust.name}"
      destination_addresses = ["192.168.55.20"]
      service               = "${panos_service_object.service-tcp-221.name}"
    }

    translated_packet {
      source {
        dynamic_ip_and_port {
          interface_address {
            interface = "${panos_ethernet_interface.eth2.name}"
          }
        }
      }

      destination = {
        static {
          address = "${panos_address_object.web-srv.name}"
          port    = "22"
        }
      }
    }
  }

  rule {
    name = "DB SSH"

    original_packet {
      source_zones          = ["${panos_zone.untrust.name}"]
      source_addresses      = ["any"]
      destination_zone      = "${panos_zone.untrust.name}"
      destination_addresses = ["192.168.55.20"]
      service               = "${panos_service_object.service-tcp-222.name}"
    }

    translated_packet {
      source {
        dynamic_ip_and_port {
          interface_address {
            interface = "${panos_ethernet_interface.eth3.name}"
          }
        }
      }

      destination = {
        static {
          address = "${panos_address_object.db-srv.name}"
          port    = "22"
        }
      }
    }
  }

  rule {
    name = "WordPress NAT"

    original_packet {
      source_zones          = ["${panos_zone.untrust.name}"]
      source_addresses      = ["any"]
      destination_zone      = "${panos_zone.untrust.name}"
      destination_addresses = ["192.168.55.20"]
      service               = "service-http"
    }

    translated_packet {
      source {
        dynamic_ip_and_port {
          interface_address {
            interface = "${panos_ethernet_interface.eth2.name}"
          }
        }
      }

      destination = {
        static {
          address = "${panos_address_object.web-srv.name}"
        }
      }
    }
  }

  rule {
    name = "Outgoing traffic"

    original_packet {
      source_zones          = ["${panos_zone.web.name}", "${panos_zone.db.name}"]
      source_addresses      = ["any"]
      destination_zone      = "${panos_zone.untrust.name}"
      destination_addresses = ["any"]
    }

    translated_packet {
      source {
        dynamic_ip_and_port {
          interface_address {
            interface = "${panos_ethernet_interface.eth1.name}"
          }
        }
      }

      destination {}
    }
  }
}
