# A rede foi criada pelo console em 07/09/2026 e está correta. O Terraform a
# consome por data source em vez de importar: importar VPC, 4 sub-redes, IGW,
# 3 route tables, associações e 2 SGs exigiria que cada bloco batesse com a
# realidade, e um bloco errado destrói e recria a rede inteira.

data "aws_vpc" "main" {
  filter {
    name   = "tag:Name"
    values = ["seniors-vpc"]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  filter {
    name   = "tag:Name"
    values = ["seniors-subnet-public*"]
  }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.main.id]
  }
  filter {
    name   = "tag:Name"
    values = ["seniors-subnet-private*"]
  }
}

data "aws_internet_gateway" "main" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.main.id]
  }
}

data "aws_route_tables" "main" {
  vpc_id = data.aws_vpc.main.id
}

data "aws_security_group" "api" {
  vpc_id = data.aws_vpc.main.id
  name   = "seniors-api-sg"
}

data "aws_security_group" "db" {
  vpc_id = data.aws_vpc.main.id
  name   = "seniors-db-sg"
}

# A rede nasceu só com a tag Name. A política de custo da AGES é por
# Project=seniors, então etiquetamos o que já existe sem virar dono dele.
locals {
  rede_existente = concat(
    [data.aws_vpc.main.id, data.aws_internet_gateway.main.id],
    [data.aws_security_group.api.id, data.aws_security_group.db.id],
    data.aws_subnets.public.ids,
    data.aws_subnets.private.ids,
    data.aws_route_tables.main.ids,
  )
}

resource "aws_ec2_tag" "project" {
  for_each    = toset(local.rede_existente)
  resource_id = each.value
  key         = "Project"
  value       = "seniors"
}
