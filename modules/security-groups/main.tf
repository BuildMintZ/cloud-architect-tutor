resource "aws_security_group" "this" {
  name        = var.sg_name
  description = var.sg_description
  vpc_id      = var.vpc_id
  lifecycle {
    create_before_destroy = true
  }
  tags = merge(var.tags, { Name = var.sg_name })
}

resource "aws_security_group_rule" "ingress" {
  for_each          = { for idx, rule in var.ingress_rules : idx => rule }
  security_group_id = aws_security_group.this.id
  type              = "ingress"
  description       = each.value.description
  from_port         = each.value.from_port
  to_port           = each.value.to_port
  protocol          = each.value.protocol
  cidr_blocks       = try(each.value.cidr_blocks, null)
}

resource "aws_security_group_rule" "egress" {
  count             = var.allow_all_egress ? 1 : 0
  security_group_id = aws_security_group.this.id
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}
