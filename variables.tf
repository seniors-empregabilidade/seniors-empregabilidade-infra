variable "region" {
  description = "Única região permitida pela SCP da conta AGES."
  type        = string
  default     = "us-east-2"
}

variable "api_hostname" {
  description = <<-TXT
    Hostname público da API. Vazio = o TLS vem do domínio *.cloudfront.net que a
    AWS gera de graça. Preencher só se a AGES liberar um subdomínio; aí ele entra
    como alternate domain name na mesma distribuição, com certificado ACM.
  TXT
  type        = string
  default     = ""
}

variable "instance_type" {
  description = "A SCP aceita t2/t3/t4g até medium. t4g.nano é o do diagrama aprovado."
  type        = string
  default     = "t4g.nano"
}

variable "db_instance_class" {
  description = "Se a SCP negar t4g no RDS, trocar para db.t3.micro (+US$1,50/mês)."
  type        = string
  default     = "db.t4g.micro"
}

variable "cognito_client_id" {
  description = "App client confidencial do pool seniors-development, provisionado em 10/09."
  type        = string
  default     = "5d8tig18huu8d3rotab969gnki"
}

variable "alert_email" {
  description = "Destino dos alarmes. A inscrição no SNS exige clique de confirmação no e-mail."
  type        = string
}

variable "cors_origins" {
  description = <<-TXT
    Origens permitidas pela API. Começa com a URL do CloudFront porque o app
    Amplify ainda não existe; quando existir, atualizar o parâmetro no SSM com
    `aws ssm put-parameter --overwrite`, sem recriar a instância.
  TXT
  type        = list(string)
  default     = ["http://localhost:5173"]
}
