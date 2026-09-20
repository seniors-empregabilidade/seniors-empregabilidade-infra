# NÃO criamos pool de produção. Decisão de 20/09: o diagrama aprovado desenha um
# único User Pool, e os usuários de produção são os três de teste com senha
# publicada — não há dado real a isolar. O pool abaixo já existe desde 10/09,
# tem usuários reais e entrega e-mail comprovadamente.
#
# Criar um segundo pool no dia em que existir usuário externo de verdade.

data "aws_cognito_user_pools" "main" {
  name = "seniors-development"
}

data "aws_cognito_user_pool_client" "api" {
  user_pool_id = one(data.aws_cognito_user_pools.main.ids)
  client_id    = var.cognito_client_id
}
