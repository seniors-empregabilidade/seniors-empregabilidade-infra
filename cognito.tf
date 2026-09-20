# NÃO criamos pool de produção. Decisão de 20/09: o diagrama aprovado desenha um.

data "aws_cognito_user_pools" "main" {
  name = "seniors-development"
}

data "aws_cognito_user_pool_client" "api" {
  user_pool_id = one(data.aws_cognito_user_pools.main.ids)
  client_id    = var.cognito_client_id
}
