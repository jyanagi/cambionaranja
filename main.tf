terraform {
  required_providers {
    nsxt = {
      source = "vmware/nsxt"
      version = "3.7.0"
    }
  }
}

# NSX-T Manager Credentials
provider "nsxt" {
  host                  = "10.8.200.95"
  username              = "admin"
  password              = "Illumio123!@#"
  allow_unverified_ssl  = true
  max_retries           = 10
  retry_min_delay       = 500
  retry_max_delay       = 5000
  retry_on_status_codes = [429]
}

# External Data Sources

data "external" "get_external_ids" {
 program = ["bash", "${path.module}/vm_ids.sh", "oshift"]
}

data "external" "oshift_web" {
 program = ["bash", "${path.module}/vm_ids.sh", "oshift_web"]
}

# Create and Tag Virtual Machines

resource "nsxt_policy_vm_tags" "oshift_web" {
 instance_id = data.external.oshift_web.result["external_ids"]

 tag {
   scope = "env"
   tag   = "test"
 }

 tag {
   scope = "role"
   tag   = "web"
 }

 tag {
   scope = "type"
   tag   = "server"
 }
}

# Create Security Groups
resource "nsxt_policy_group" "ipl_ext_nets" {
  display_name = "ipl_External_Nets"
  description  = "RestNSX (OrangeShift) NSX Security Group | IP List for External Networks"
  criteria {
    ipaddress_expression {
      ip_addresses = ["1.1.1.0/24","8.8.8.0/24","9.0.0.0/8"]
    }
  }
}

resource "nsxt_policy_group" "ipl_ext_ip" {
  display_name = "ipl_External_IP"
  description  = "RestNSX (OrangeShift) NSX Security Group | IP List for Single External IP"
  criteria {
    ipaddress_expression {
      ip_addresses = ["8.8.7.9"]
    }
  }
}

resource "nsxt_policy_group" "ipl_priv_network" {
  display_name = "ipl_Private_Nets"
  description  = "RestNSX (OrangeShift) NSX Security Group | IP List for Private Networks"

  criteria {
    ipaddress_expression {
      ip_addresses = ["192.168.0.0/16"]
    }
  }
}

resource "nsxt_policy_group" "ipl_overlapping" {
  display_name = "ipl_Overlap"
  description  = "RestNSX (OrangeShift) NSX Security Group | IP List that overlaps with existing NSGs with dynamic criteria"

  criteria {
    ipaddress_expression {
      ip_addresses = ["10.16.0.0/24"]
    }
  }
}

resource "nsxt_policy_group" "ipl_web_net" {
  display_name = "ipl_Web_Net"
  description  = "RestNSX (OrangeShift) NSX Security Group | IP List for Web Server network"
  criteria {
    ipaddress_expression {
      ip_addresses = ["10.17.0.0/24"]
    }
  }
}

resource "nsxt_policy_group" "ipl_web_server" {
  display_name = "ipl_Web_Server"
  description  = "RestNSX (OrangeShift) NSX Security Group | IP List for the Web Server"
  criteria {
    ipaddress_expression {
      ip_addresses = ["10.17.0.1"]
    }
  }
}

resource "nsxt_policy_group" "nsg_tag_and_ip" {
  display_name = "nsg_Tag_and_IP"
  description  = "RestNSX (OrangeShift) NSX Security Group | Dynamic Group using NSX VM Tag and Static IP address for criteria"
  criteria {
    condition {
      key         = "Tag"
      member_type = "VirtualMachine"
      operator    = "EQUALS"
      value       = "role|web"
    }
  }
  conjunction {
    operator    = "OR"
  }
  criteria {
    ipaddress_expression {
      ip_addresses = ["10.17.0.1"]
    }
  }
}

resource "nsxt_policy_group" "nsg_tag_only" {
  display_name = "nsg_Tag_Only"
  description  = "RestNSX (OrangeShift) NSX Security Group | Dynamic Group using only NSX VM Tags"
  criteria {
    condition {
      key         = "Tag"
      member_type = "VirtualMachine"
      operator    = "EQUALS"
      value       = "role|web"
    }
  }
}

resource "nsxt_policy_group" "nsg_multi_tags" {
  display_name = "nsg_Multi_Tags"
  description  = "RestNSX (OrangeShift) NSX Security Group | Dynamic Group using multiple NSX VM Tags"
  criteria {
    condition {
      key         = "Tag"
      member_type = "VirtualMachine"
      operator    = "EQUALS"
      value       = "role|web"
    }
    condition {
      key         = "Tag"
      member_type = "VirtualMachine"
      operator    = "EQUALS"
      value       = "env|test"
    }
  }
}

resource "nsxt_policy_group" "nsg_vms_in_group" {
  display_name = "nsg_VMs_in_a_Group"
  description  = "RestNSX (OrangeShift) NSX Security Group | Statically Provisioned Group of Virtual Machines"
  criteria {
    external_id_expression {
      member_type = "VirtualMachine"
      external_ids = split(",", data.external.get_external_ids.result["external_ids"])
    }
  }
}

# Use Existing Services
data "nsxt_policy_service" "svc_dns_tcp" {
  display_name = "DNS-TCP"
}

data "nsxt_policy_service" "svc_dns_udp" {
  display_name = "DNS-UDP"
}

data "nsxt_policy_service" "svc_http" {
  display_name = "HTTP"
}

data "nsxt_policy_service" "svc_https" {
  display_name = "HTTPS"
}

data "nsxt_policy_service" "svc_ssh" {
  display_name = "SSH"
}

# Create Services

resource "nsxt_policy_service" "svc_TCP_179" {
  description  = "RestNSX (OrangeShift) Custom Service | TCP 179 (BGP)"
  display_name = "svc_TCP-179 (BGP)"

  l4_port_set_entry {
    display_name      = "svc_TCP-179 (BGP)"
    protocol          = "TCP"
    destination_ports = ["179"]
  }
}

resource "nsxt_policy_service" "svc_TCP_1522" {
  description  = "RestNSX (OrangeShift) Custom Service | TCP 1522"
  display_name = "svc_TCP-1522"

  l4_port_set_entry {
    display_name      = "svc_TCP-1522"
    protocol          = "TCP"
    destination_ports = ["1522"]
  }
}

resource "nsxt_policy_service" "svc_TCP_5414" {
  description  = "RestNSX (OrangeShift) Custom Service | TCP 5414"
  display_name = "svc_TCP-5414"

  l4_port_set_entry {
    display_name      = "svc_TCP-5414"
    protocol          = "TCP"
    destination_ports = ["5414"]
  }
}

resource "nsxt_policy_service" "svc_TCP_9101" {
  description  = "RestNSX (OrangeShift) Custom Service | TCP 9101"
  display_name = "svc_TCP-9101"

  l4_port_set_entry {
    display_name      = "svc_TCP-9101"
    protocol          = "TCP"
    destination_ports = ["9101"]
  }
}

resource "nsxt_policy_service" "svc_TCP_24000" {
  description  = "RestNSX (OrangeShift) Custom Service | TCP 24000"
  display_name = "svc_TCP-24000"

  l4_port_set_entry {
    display_name      = "svc_TCP-24000"
    protocol          = "TCP"
    destination_ports = ["24000"]
  }
}

resource "nsxt_policy_service" "svc_UDP_554" {
  description  = "RestNSX (OrangeShift) Custom Service | UDP 554"
  display_name = "svc_UDP-554"

  l4_port_set_entry {
    display_name      = "svc_UDP-554"
    protocol          = "UDP"
    destination_ports = ["554"]
  }
}

resource "nsxt_policy_service" "svc_UDP_555" {
  description  = "RestNSX (OrangeShift) Custom Service | UDP 555"
  display_name = "svc_UDP-555"

  l4_port_set_entry {
    display_name      = "svc_UDP-555"
    protocol          = "UDP"
    destination_ports = ["555"]
  }
}

resource "nsxt_policy_service" "svc_ICMPv4_Echo_Reply" {
  description  = "RestNSX (OrangeShift) Custom Service | ICMPv4 Echo Reply"
  display_name = "svc_ICMPv4 Echo Reply"

  icmp_entry {
    display_name = "ICMPv4 Echo Reply"
    description  = "ICMPv4 Echo Reply"
    protocol     = "ICMPv4"
    icmp_code    = "0"
    icmp_type    = "0"
  }
}

resource "nsxt_policy_service" "svc_ICMPv4_Echo_Request" {
  description  = "RestNSX (OrangeShift) Custom Service | ICMPv4 Echo Request"
  display_name = "svc_ICMPv4 Echo Request"

  icmp_entry {
    display_name = "ICMPv4 Echo Request"
    description  = "ICMPv4 Echo Request"
    protocol     = "ICMPv4"
    icmp_code    = "0"
    icmp_type    = "8"
  }
}

resource "nsxt_policy_service" "svc_ICMPv4_Host_Unreachable" {
  description  = "RestNSX (OrangeShift) Custom Service | ICMPv4 Destination Host Unreachable"
  display_name = "svc_ICMPv4 Destination Host Unreachable"

  icmp_entry {
    display_name = "ICMPv4 Destination Host Unreachable"
    description  = "ICMPv4 Destination Host Unreachable"
    protocol     = "ICMPv4"
    icmp_code    = "1"
    icmp_type    = "3"
  }
}

resource "nsxt_policy_service" "svc_ICMPv4_Network_Unreachable" {
  description  = "RestNSX (OrangeShift) Custom Service | ICMPv4 Destination Network Unreachable"
  display_name = "svc_ICMPv4 Destination Network Unreachable"

  icmp_entry {
    display_name = "ICMPv4 Destination Network Unreachable"
    description  = "ICMPv4 Destination Network Unreachable"
    protocol     = "ICMPv4"
    icmp_code    = "0"
    icmp_type    = "3"
  }
}

resource "nsxt_policy_service" "svc_Unsupported" {
  description  = "RestNSX (OrangeShift) Custom Service | IP (WESP)"
  display_name = "svc_IP (WESP)"

  ip_protocol_entry {
    display_name = "IP (WESP)"
    protocol     = "141"
  }
}

# Create DFW - Application Policy and Rulesets

resource "nsxt_policy_security_policy" "restNSX_DFW_Policy" {
  display_name = "dFW - RestNSX Sample Rules"
  category     = "Application"
  locked       = false
  stateful     = true
  tcp_strict   = true

  rule {
    display_name       = "NSX RS - Rule with SuperNet to Private Network"
    source_groups      = [nsxt_policy_group.ipl_overlapping.path]
    destination_groups = [nsxt_policy_group.ipl_priv_network.path]
    services           = [data.nsxt_policy_service.svc_dns_tcp.path,data.nsxt_policy_service.svc_dns_udp.path,data.nsxt_policy_service.svc_http.path]
    action             = "ALLOW"
  }
  
  rule {
    display_name       = "NSX RS - Rule with Security Group and Overlapping IP List"
    source_groups      = [nsxt_policy_group.ipl_ext_ip.path]
    destination_groups = [nsxt_policy_group.nsg_vms_in_group.path,nsxt_policy_group.ipl_overlapping.path]
    action             = "ALLOW"
  }

  rule {
    display_name       = "NSX RS - Rule with External IP to External Resource"
    source_groups      = [nsxt_policy_group.ipl_ext_ip.path]
    destination_groups = ["4.3.5.2"]
    action             = "ALLOW"
  }

  rule {
    display_name       = "NSX RS - Rule with External IP to Any"
    source_groups      = [nsxt_policy_group.ipl_ext_ip.path]
    services           = [nsxt_policy_service.svc_UDP_554.path,nsxt_policy_service.svc_UDP_555.path]
    action             = "ALLOW"
  }

  rule {
    display_name       = "NSX RS - Rule with External IPset to Web Server Network"
    source_groups      = ["160.0.0.0/8"]
    destination_groups = [nsxt_policy_group.ipl_web_net.path]
    services           = [data.nsxt_policy_service.svc_ssh.path]
    action             = "ALLOW"
  }

  rule {
    display_name       = "NSX RS - Rule with External IPset to Web Server IPlist"
    source_groups      = ["170.0.0.0/8"]
    destination_groups = [nsxt_policy_group.ipl_web_server.path]
    services           = [data.nsxt_policy_service.svc_dns_tcp.path,data.nsxt_policy_service.svc_dns_udp.path]
    action             = "ALLOW"
  }

    rule {
    display_name       = "NSX RS - Rule with External IP and ICMPv4"
    source_groups      = [nsxt_policy_group.ipl_ext_ip.path]
    services           = [nsxt_policy_service.svc_ICMPv4_Echo_Reply.path,nsxt_policy_service.svc_ICMPv4_Echo_Request.path,nsxt_policy_service.svc_ICMPv4_Host_Unreachable.path,nsxt_policy_service.svc_ICMPv4_Network_Unreachable.path]
    action             = "ALLOW"
  }

  rule {
    display_name       = "NSX RS - Rule using Tag-Only to External Networks"
    source_groups      = [nsxt_policy_group.nsg_tag_only.path]
    destination_groups = [nsxt_policy_group.ipl_ext_nets.path]
    services           = [data.nsxt_policy_service.svc_https.path]
    action             = "ALLOW"
  }

  rule {
    display_name       = "NSX RS - Rule using Multi-Tag to External Networks"
    source_groups      = [nsxt_policy_group.nsg_multi_tags.path]
    destination_groups = ["172.15.0.0/16","8.0.0.0/8"]
    services           = [data.nsxt_policy_service.svc_https.path]
    action             = "ALLOW"
  }

  rule {
    display_name       = "NSX RS - Rule with Any to External Networks"
    destination_groups = [nsxt_policy_group.ipl_ext_nets.path]
    action             = "ALLOW"
  }

  rule {
    display_name       = "NSX RS - Rule with Internal IPset to Any"
    source_groups      = ["10.0.0.1"]
    services           = [nsxt_policy_service.svc_UDP_554.path,nsxt_policy_service.svc_UDP_555.path]
    action             = "ALLOW"
  }

  rule {
    display_name       = "NSX RS - Any to a Private Network"
    destination_groups = ["192.168.1.0/24"]
    services           = [nsxt_policy_service.svc_TCP_179.path]
    action             = "ALLOW"
  }

  rule {
    display_name       = "NSX RS - Rule with Any to VMs in a Group"
    destination_groups = [nsxt_policy_group.nsg_vms_in_group.path]
    services           = [data.nsxt_policy_service.svc_dns_tcp.path,data.nsxt_policy_service.svc_dns_udp.path,data.nsxt_policy_service.svc_https.path,data.nsxt_policy_service.svc_ssh.path]
    action             = "ALLOW"
  }

  rule {
    display_name       = "NSX RS - VM Grouping to VM Tag"
    source_groups      = [nsxt_policy_group.nsg_vms_in_group.path]
    destination_groups = [nsxt_policy_group.nsg_tag_only.path]
    services           = [nsxt_policy_service.svc_TCP_24000.path,nsxt_policy_service.svc_TCP_9101.path,nsxt_policy_service.svc_TCP_5414.path,nsxt_policy_service.svc_TCP_1522.path]
    action             = "ALLOW"
  }

  rule {
    display_name       = "NSX RS - Unsupported Protocol and Ruleset"
    source_groups      = [nsxt_policy_group.ipl_ext_ip.path,"2.2.2.0"]
    services           = [nsxt_policy_service.svc_Unsupported.path]
    action             = "ALLOW"
  }

  rule {
    display_name       = "NSX RS - IPlist to IPlist (Unsupported Ruleset)"
    source_groups      = [nsxt_policy_group.ipl_web_net.path]
    destination_groups = [nsxt_policy_group.ipl_overlapping.path]
    services           = [data.nsxt_policy_service.svc_https.path]
    action             = "ALLOW"
  }

}
