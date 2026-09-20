# Configuração da aplicação que não é segredo. Fica no Parameter Store, e não.
resource "aws_ssm_parameter" "api_config" {
  name = "/seniors/api/config"
  type = "String"

  value = <<-CFG
    CORS_ORIGINS=${jsonencode(var.cors_origins)}
    COGNITO_REGION=${var.region}
    COGNITO_USER_POOL_ID=${one(data.aws_cognito_user_pools.main.ids)}
    COGNITO_CLIENT_ID=${var.cognito_client_id}
    UPLOADS_BUCKET=${aws_s3_bucket.uploads.bucket}
  CFG

  # O conteúdo muda por `aws ssm put-parameter` quando o Amplify existir; o
  # Terraform não deve desfazer isso no apply seguinte.
  lifecycle {
    ignore_changes = [value]
  }
}

data "aws_ssm_parameter" "al2023_arm64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

resource "aws_instance" "api" {
  ami           = data.aws_ssm_parameter.al2023_arm64.value
  instance_type = var.instance_type

  subnet_id              = data.aws_subnets.public.ids[0]
  vpc_security_group_ids = [data.aws_security_group.api.id]
  iam_instance_profile   = aws_iam_instance_profile.api.name

  root_block_device {
    volume_type = "gp3"
    volume_size = 8
    encrypted   = true
  }

  # IMDSv2 obrigatório: fecha SSRF contra as credenciais da role.
  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  user_data = templatefile("${path.module}/instance/user-data.sh.tftpl", {
    region         = var.region
    ecr_repo       = aws_ecr_repository.api.repository_url
    ecr_name       = aws_ecr_repository.api.name
    db_host        = aws_db_instance.main.address
    db_name        = aws_db_instance.main.db_name
    db_secret_arn  = aws_db_instance.main.master_user_secret[0].secret_arn
    api_secret_arn = aws_secretsmanager_secret.api.arn
    compose = templatefile("${path.module}/instance/compose.yaml.tftpl", {
      ecr_repo  = aws_ecr_repository.api.repository_url
      region    = var.region
      log_group = aws_cloudwatch_log_group.api.name
    })
    deploy = file("${path.module}/instance/deploy.sh")
  })

  tags = { Name = "seniors-api" }
}

# A sub-rede tem MapPublicIpOnLaunch = false, então o IP público é explícito.
# Também é ele que dá o nome DNS estável usado como origem do CloudFront.
resource "aws_eip" "api" {
  domain   = "vpc"
  instance = aws_instance.api.id
  tags     = { Name = "seniors-api" }
}
