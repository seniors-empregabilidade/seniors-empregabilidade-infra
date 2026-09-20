# O diagrama diz "VPC — AZ única", mas o RDS exige subnet group com pelo menos
# duas AZs mesmo em Single-AZ. As duas sub-redes privadas já existem.
resource "aws_db_subnet_group" "main" {
  name       = "seniors-db"
  subnet_ids = data.aws_subnets.private.ids
}

resource "aws_db_parameter_group" "main" {
  name   = "seniors-postgres18"
  family = "postgres18"

  # Recusa conexão sem TLS no próprio banco, não só na string de conexão.
  parameter {
    name         = "rds.force_ssl"
    value        = "1"
    apply_method = "pending-reboot"
  }
}

resource "aws_db_instance" "main" {
  identifier     = "seniors-db"
  engine         = "postgres"
  engine_version = "18"
  instance_class = var.db_instance_class

  allocated_storage = 20
  storage_type      = "gp2"
  storage_encrypted = true

  db_name  = "seniors_empregabilidade"
  username = "seniors"

  # A AWS gera, guarda e rotaciona a senha no Secrets Manager: ela nunca passa
  # pelo state nem por variável de ambiente nossa.
  manage_master_user_password = true

  db_subnet_group_name   = aws_db_subnet_group.main.name
  parameter_group_name   = aws_db_parameter_group.main.name
  vpc_security_group_ids = [data.aws_security_group.db.id]
  publicly_accessible    = false
  multi_az               = false

  # Janelas fixadas de propósito. Sem elas a AWS sorteia, e com.
  backup_retention_period = 7
  backup_window           = "06:00-07:00"
  maintenance_window      = "Mon:07:00-Mon:08:00"

  auto_minor_version_upgrade = true
  deletion_protection        = true
  skip_final_snapshot        = false
  final_snapshot_identifier  = "seniors-db-final"

  # A instância é o produto; um apply distraído não pode derrubá-la.
  # O teardown de fim de semestre está no runbook e passa por remover isto.
  lifecycle {
    prevent_destroy = true
  }
}

# Segredo do projeto, separado do que a AWS gerencia para o banco. Guarda o
# client secret do Cognito, que a aplicação precisa e o navegador nunca pode ver.
resource "aws_secretsmanager_secret" "api" {
  name                    = "seniors/api"
  recovery_window_in_days = 7
}

resource "aws_secretsmanager_secret_version" "api" {
  secret_id = aws_secretsmanager_secret.api.id

  secret_string = jsonencode({
    cognito_client_secret = data.aws_cognito_user_pool_client.api.client_secret
  })
}
