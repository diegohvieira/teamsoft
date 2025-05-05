output "sg_info" {
    description = "Information about the security groups created"
    value = {
        for sg_key, sg_value in local.sg_map : sg_key => {
            name   = aws_security_group.this[sg_key].name
            rules = [
                for rule in try(sg_value.ingress, []) : {
                    cidr_ipv4 = rule.cidr_ipv4
                    from_port = rule.from_port
                    to_port   = rule.to_port
                    protocol  = rule.protocol
                }
            ]

        }
    }
}
