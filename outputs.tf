output "vpc_id" {
  value = data.aws_vpc.main.id
}

output "subnets_publicas" {
  description = "Sub-redes da API. MapPublicIpOnLaunch é false: a instância precisa de EIP explícito."
  value       = data.aws_subnets.public.ids
}

output "subnets_privadas" {
  description = "Sub-redes do banco, sem rota para a internet."
  value       = data.aws_subnets.private.ids
}

output "sg_api_id" {
  value = data.aws_security_group.api.id
}

output "sg_db_id" {
  value = data.aws_security_group.db.id
}

output "ecr_repository_url" {
  description = "Destino do push do CodeBuild e origem do pull da instância."
  value       = aws_ecr_repository.api.repository_url
}

output "uploads_bucket" {
  value = aws_s3_bucket.uploads.bucket
}

output "log_group" {
  value = aws_cloudwatch_log_group.api.name
}

output "db_endpoint" {
  description = "Alcançável só de dentro da VPC. Do notebook, por port forwarding do SSM."
  value       = aws_db_instance.main.address
}

output "db_secret_arn" {
  description = "Segredo gerenciado pela AWS com usuário e senha do banco."
  value       = aws_db_instance.main.master_user_secret[0].secret_arn
}

output "cognito_user_pool_id" {
  value = one(data.aws_cognito_user_pools.main.ids)
}

output "cognito_client_id" {
  value = var.cognito_client_id
}

output "api_url" {
  description = "Endereço público da API. HTTPS com certificado da AWS, sem domínio próprio."
  value       = "https://${aws_cloudfront_distribution.api.domain_name}"
}

output "api_instance_id" {
  description = "Para `aws ssm start-session --target <id>`. Não há SSH."
  value       = aws_instance.api.id
}

output "api_eip" {
  value = aws_eip.api.public_ip
}

output "frontend_url" {
  value = "https://${aws_amplify_branch.main.branch_name}.${aws_amplify_app.frontend.id}.amplifyapp.com"
}


output "frontend_deploy_role_arn" {
  description = "Role assumida pelo GitHub Actions do frontend."
  value       = aws_iam_role.frontend_deploy.arn
}
