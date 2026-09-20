data "aws_ec2_managed_prefix_list" "cloudfront_origins" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_vpc_security_group_ingress_rule" "api_from_cloudfront" {
  security_group_id = data.aws_security_group.api.id
  description       = "CloudFront edge locations only"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront_origins.id
}
