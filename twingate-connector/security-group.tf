resource "aws_security_group" "twingate" {
  lifecycle {
    create_before_destroy = true
  }
  name        = "twingate"
  description = "Used by twingate connectors"
  vpc_id      = var.vpc_id

  tags = merge(local.common_tags, {
    Name = "twingate"
  })
}

resource "aws_security_group_rule" "twingate_allow_vpc" {
  security_group_id = aws_security_group.twingate.id
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = [local.vpc_cidr]
  description       = "Allow from VPC"
}

resource "aws_security_group_rule" "twingate_egress" {
  security_group_id = aws_security_group.twingate.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  ipv6_cidr_blocks  = ["::/0"]
  description       = "Allow outbound internet"
}
