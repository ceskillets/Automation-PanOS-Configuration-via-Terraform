# Terraform Example Skillet

This skillet is a longer example of how to configure a firewall using the Palo Alto Networks
[Terraform provider](https://www.terraform.io/docs/providers/panos/index.html).

It configures the following on a PAN-OS firewall:

- Interfaces
- Zones
- Default Router
- Address Objects
- Service Objects
- Security Rules
- NAT Rules

It assumes the initial configuration of the firewall is empty.

## Plan Walkthrough

### Creating Resources

The Terraform provider exposes configurable elements on the firewall as
[resources](https://www.terraform.io/docs/configuration-0-11/resources.html):

```
resource "panos_ethernet_interface" "eth1" {
  name       = "ethernet1/1"
  vsys       = "vsys1"
  mode       = "layer3"
  static_ips = ["192.168.55.20/24"]
}
```

Dependencies between resources are handled via Terraform's
[interpolation syntax](https://www.terraform.io/docs/configuration-0-11/interpolation.html):

```
resource "panos_zone" "untrust" {
  name       = "untrust"
  mode       = "layer3"
  interfaces = ["${panos_ethernet_interface.eth1.name}"]
}
```

In this example, referencing the interface name using the interpolation `${panos_ethernet_interface.eth1.name}` rather
than simply `ethernet1/1` ensures that the interface will be created before the zone.

### Committing the Configuration

Terraform does not currently provide support for committing the configuration to a firewall or Panorama.  Outside of
the skillets framework, commits can be performed using the
[Golang code](https://www.terraform.io/docs/providers/panos/index.html#commits) on the provider page.  When running as
a skillet, simply commit the configuration using the GUI or the CLI.

## Support Policy

The code and templates in the repo are released under an as-is, best effort,
support policy. These scripts should be seen as community supported and
Palo Alto Networks will contribute our expertise as and when possible.
We do not provide technical support or help in using or troubleshooting the
components of the project through our normal support options such as
Palo Alto Networks support teams, or ASC (Authorized Support Centers)
partners and backline support options. The underlying product used
(the VM-Series firewall) by the scripts or templates are still supported,
but the support is only for the product functionality and not for help in
deploying or using the template or script itself. Unless explicitly tagged,
all projects or work posted in our GitHub repository
(at https://github.com/PaloAltoNetworks) or sites other than our official
Downloads page on https://support.paloaltonetworks.com are provided under
the best effort policy.