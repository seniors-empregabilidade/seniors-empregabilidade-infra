resource "aws_cloudfront_vpc_origin" "api" {
  vpc_origin_endpoint_config {
    name                   = "seniors-api-origin"
    arn                    = "arn:aws:ec2:${var.region}:${data.aws_caller_identity.current.account_id}:instance/${aws_instance.api.id}"
    http_port              = 80
    https_port             = 443
    origin_protocol_policy = "http-only"

    origin_ssl_protocols {
      quantity = 1
      items    = ["TLSv1.2"]
    }
  }
}

resource "aws_vpc_security_group_ingress_rule" "api_from_cloudfront" {
  security_group_id            = data.aws_security_group.api.id
  description                  = "CloudFront VPC origin"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = "sg-08fa004f19113b6a5"
}
