# Plans the module on its own with plainly fake values. Nothing is created.

mock_provider "aws" {
  source = "../../testing/mocks"
}

variables {
  name        = "plan-test"
  description = "Plan test"
  vpc_id      = "vpc-0aaaaaaaaaaaaaaa1"
}

run "accepts_valid_rules_in_both_directions" {
  command = plan

  variables {
    ingress_rules = {
      https = { description = "HTTPS", from_port = 443, to_port = 443, cidr_ipv4 = "10.0.0.0/16" }
      ping  = { description = "Ping", ip_protocol = "icmp", from_port = 8, to_port = -1, cidr_ipv4 = "10.0.0.0/16" }
      peers = { description = "Peers", ip_protocol = "-1", self = true }
    }

    egress_rules = {
      postgres = { description = "PostgreSQL", from_port = 5432, to_port = 5432, referenced_security_group_id = "sg-0aaaaaaaaaaaaaaa1" }
      dns      = { description = "DNS", ip_protocol = "udp", from_port = 53, to_port = 53, cidr_ipv4 = "10.0.0.2/32" }
      anything = { description = "Anything to the VPC", ip_protocol = "-1", cidr_ipv6 = "2001:db8::/56" }
      esp      = { description = "IPsec ESP", ip_protocol = "50", prefix_list_id = "pl-0aaaaaaaaaaaaaaa1" }
    }
  }

  assert {
    condition     = length(aws_vpc_security_group_ingress_rule.this) == 3 && length(aws_vpc_security_group_egress_rule.this) == 4
    error_message = "Every valid rule should be planned."
  }

  assert {
    condition     = aws_vpc_security_group_egress_rule.this["anything"].from_port == null
    error_message = "An all-traffic rule should carry no ports."
  }
}

run "allows_all_egress_when_no_rules_are_given" {
  command = plan

  assert {
    condition     = aws_vpc_security_group_egress_rule.this["all"].cidr_ipv4 == "0.0.0.0/0"
    error_message = "With no egress rules, all outbound IPv4 traffic should be allowed."
  }
}

run "refuses_egress_with_no_destination" {
  command = plan

  variables {
    egress_rules = {
      none = { description = "Nowhere", from_port = 443, to_port = 443 }
    }
  }

  expect_failures = [var.egress_rules]
}

run "refuses_egress_with_two_destinations" {
  command = plan

  variables {
    egress_rules = {
      two = { description = "Two places", from_port = 443, to_port = 443, cidr_ipv4 = "10.0.0.0/16", self = true }
    }
  }

  expect_failures = [var.egress_rules]
}

run "refuses_egress_without_a_description" {
  command = plan

  variables {
    egress_rules = {
      blank = { description = " ", from_port = 443, to_port = 443, cidr_ipv4 = "10.0.0.0/16" }
    }
  }

  expect_failures = [var.egress_rules]
}

run "refuses_egress_with_an_unknown_protocol" {
  command = plan

  variables {
    egress_rules = {
      web = { description = "Web", ip_protocol = "http", from_port = 80, to_port = 80, cidr_ipv4 = "10.0.0.0/16" }
    }
  }

  expect_failures = [var.egress_rules]
}

run "refuses_tcp_egress_without_ports" {
  command = plan

  variables {
    egress_rules = {
      web = { description = "Web", cidr_ipv4 = "10.0.0.0/16" }
    }
  }

  expect_failures = [var.egress_rules]
}

run "refuses_egress_with_a_reversed_port_range" {
  command = plan

  variables {
    egress_rules = {
      web = { description = "Web", from_port = 8080, to_port = 80, cidr_ipv4 = "10.0.0.0/16" }
    }
  }

  expect_failures = [var.egress_rules]
}

run "refuses_egress_past_the_last_port" {
  command = plan

  variables {
    egress_rules = {
      web = { description = "Web", ip_protocol = "udp", from_port = 1024, to_port = 70000, cidr_ipv4 = "10.0.0.0/16" }
    }
  }

  expect_failures = [var.egress_rules]
}

run "refuses_icmp_egress_with_an_out_of_range_type" {
  command = plan

  variables {
    egress_rules = {
      ping = { description = "Ping", ip_protocol = "icmp", from_port = 300, to_port = -1, cidr_ipv4 = "10.0.0.0/16" }
    }
  }

  expect_failures = [var.egress_rules]
}

run "refuses_ingress_with_two_sources" {
  command = plan

  variables {
    ingress_rules = {
      two = { description = "Two places", from_port = 443, to_port = 443, cidr_ipv4 = "10.0.0.0/16", prefix_list_id = "pl-0aaaaaaaaaaaaaaa1" }
    }
  }

  expect_failures = [var.ingress_rules]
}

run "refuses_tcp_ingress_with_a_reversed_port_range" {
  command = plan

  variables {
    ingress_rules = {
      web = { description = "Web", from_port = 443, to_port = 80, cidr_ipv4 = "10.0.0.0/16" }
    }
  }

  expect_failures = [var.ingress_rules]
}

run "refuses_ingress_with_an_unknown_protocol" {
  command = plan

  variables {
    ingress_rules = {
      web = { description = "Web", ip_protocol = "256", from_port = 80, to_port = 80, cidr_ipv4 = "10.0.0.0/16" }
    }
  }

  expect_failures = [var.ingress_rules]
}
