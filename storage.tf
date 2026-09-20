# Registro das imagens da API. IMMUTABLE porque a wiki promete que "cada versão.
resource "aws_ecr_repository" "api" {
  name                 = "seniors-api"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "api" {
  repository = aws_ecr_repository.api.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Mantém as 10 imagens mais recentes"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
      action = { type = "expire" }
    }]
  })
}

# Currículos, documentos e imagens enviados pelos usuários. Sempre por URL.
resource "aws_s3_bucket" "uploads" {
  bucket = "seniors-uploads-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket                  = aws_s3_bucket.uploads.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Retenção curta de propósito: 5 GB/mês de ingestão são gratuitos e não temos
# Cost Explorer para perceber um log group crescendo sem teto.
resource "aws_cloudwatch_log_group" "api" {
  name              = "/seniors/api"
  retention_in_days = 7
}
