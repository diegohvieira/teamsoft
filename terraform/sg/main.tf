locals {
  sg_config_path = "../../values"
  instance_sets  = fileset(local.sg_config_path, "sg.yml")
  sg             = flatten([
    for instance in local.instance_sets : [
      for idx, content in yamldecode(file("${local.sg_config_path}/${instance}")).sg : content
    ]
  ])
  defaults = yamldecode(file("${local.sg_config_path}/defaults.yml")).defaults

  sg_map = { for idx, content in local.sg : "${content.name}-${idx}" => content }

  sg_ingress_rules = flatten([
    for sg_key, sg_value in local.sg_map : [
      for rule in try(sg_value.ingress, []) : {
        sg_key = sg_key
        rule   = rule
      }
    ]
  ])

  sg_egress_rules = flatten([
    for sg_key, sg_value in local.sg_map : [
      for rule in try(sg_value.egress, []) : {
        sg_key = sg_key
        rule   = rule
      }
    ]
  ])
}

resource "aws_security_group" "this" {
  for_each    = local.sg_map
  name        = each.value.name
  description = try(each.value.description, null)
  vpc_id      = try(each.value.vpc_id, local.defaults.vpc_id)

  tags = merge(
    {
      Name = each.value.name
    },
    local.defaults
  )
}

resource "aws_vpc_security_group_ingress_rule" "ipv4" {
  for_each = {
    for rule in local.sg_ingress_rules :
    "${rule.sg_key}-${rule.rule.cidr_ipv4}-${rule.rule.from_port}" => rule
  }

  security_group_id = aws_security_group.this[each.value.sg_key].id
  cidr_ipv4         = each.value.rule.cidr_ipv4
  from_port         = each.value.rule.from_port
  to_port           = each.value.rule.to_port
  ip_protocol       = each.value.rule.protocol
}

resource "aws_vpc_security_group_egress_rule" "ipv4" {
  for_each = {
    for rule in local.sg_egress_rules :
    "${rule.sg_key}-${rule.rule.cidr_ipv4}-${rule.rule.from_port}" => rule
  }

  security_group_id = aws_security_group.this[each.value.sg_key].id
  cidr_ipv4         = try(each.value.rule.cidr_ipv4, "0.0.0.0/0")
  from_port         = try(each.value.rule.from_port, null)
  to_port           = try(each.value.rule.to_port, null)
  ip_protocol       = try(each.value.rule.protocol, "-1")
}
