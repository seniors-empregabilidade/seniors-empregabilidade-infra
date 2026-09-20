# O CloudFront existe por um motivo simples: dá HTTPS de graça em um domínio.
resource "aws_cloudfront_distribution" "api" {
  enabled = true
  comment = "API do Seniors - Empregabilidade"

  origin {
    origin_id = "ec2-api"
    # O CloudFront não aceita IP como origem: precisa de nome. O EIP fornece um
    # DNS público estável.
    domain_name = aws_eip.api.public_dns

    custom_origin_config {
      http_port  = 80
      https_port = 443
      # Em claro até existir um nome DNS para a origem com certificado.
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id = "ec2-api"
    # A API responde em todos os métodos; o padrão do CloudFront bloquearia POST.
    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods  = ["GET", "HEAD"]
    # Cachear resposta autenticada seria vazamento entre usuários.
    cache_policy_id = data.aws_cloudfront_cache_policy.disabled.id
    # Encaminha Authorization, query e cookies — menos o Host do viewer, que
    # quebraria a origem.
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
    viewer_protocol_policy   = "redirect-to-https"
    compress                 = true
  }

  # Mais barato. A origem está em Ohio de qualquer jeito, então um edge no
  # Brasil economizaria apenas o handshake TLS.
  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

data "aws_cloudfront_cache_policy" "disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer" {
  name = "Managed-AllViewerExceptHostHeader"
}
