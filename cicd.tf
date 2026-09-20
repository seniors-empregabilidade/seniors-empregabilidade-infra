resource "aws_codebuild_project" "api" {
  name          = "seniors-api"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 20

  source {
    type            = "GITHUB"
    location        = "https://github.com/seniors-empregabilidade/seniors-empregabilidade-backend.git"
    git_clone_depth = 1
    buildspec       = "buildspec.yml"
  }

  source_version = "refs/heads/main"

  artifacts {
    type = "NO_ARTIFACTS"
  }

  # ARM porque o alvo é Graviton: build nativo, sem emulação.
  environment {
    type                        = "ARM_CONTAINER"
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux-aarch64-standard:3.0"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"
  }

  cache {
    type  = "LOCAL"
    modes = ["LOCAL_DOCKER_LAYER_CACHE", "LOCAL_SOURCE_CACHE"]
  }

  logs_config {
    cloudwatch_logs {
      group_name = "/aws/codebuild/seniors-api"
    }
  }
}

resource "aws_codebuild_webhook" "api" {
  project_name = aws_codebuild_project.api.name
  build_type   = "BUILD"

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "PUSH"
    }
    filter {
      type    = "HEAD_REF"
      pattern = "^refs/heads/main$"
    }
  }
}

resource "aws_amplify_app" "frontend" {
  name                 = "seniors-frontend"
  iam_service_role_arn = aws_iam_role.amplify.arn
  platform             = "WEB"

  environment_variables = {
    VITE_API_URL = "https://${aws_cloudfront_distribution.api.domain_name}/api/v1"
  }

  # Sem esta regra, atualizar a página em qualquer rota que não a raiz dá 404.
  custom_rule {
    source = "</^[^.]+$|\\.(?!(css|gif|ico|jpg|jpeg|js|png|txt|svg|woff|woff2|ttf|map|json|webp)$)([^.]+$)/>"
    target = "/index.html"
    status = "200"
  }
}

resource "aws_amplify_branch" "main" {
  app_id      = aws_amplify_app.frontend.id
  branch_name = "main"
  stage       = "PRODUCTION"
}
