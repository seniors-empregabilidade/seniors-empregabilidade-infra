resource "aws_sns_topic" "alerts" {
  name = "seniors-alertas"
}

# A inscrição exige um clique de confirmação no e-mail. Sem ele, nenhum
# alarme chega — e o Terraform não tem como saber disso.
resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# Recuperação automática, de graça: a AWS recria a instância em hardware novo.
resource "aws_cloudwatch_metric_alarm" "instancia_com_falha_de_hardware" {
  alarm_name          = "seniors-ec2-status-sistema"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed_System"
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  dimensions          = { InstanceId = aws_instance.api.id }
  alarm_actions       = ["arn:aws:automate:${var.region}:ec2:recover", aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "cpu" {
  alarm_name          = "seniors-ec2-cpu"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  dimensions          = { InstanceId = aws_instance.api.id }
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "disco_do_banco" {
  alarm_name          = "seniors-rds-espaco"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = 2147483648 # 2 GB
  comparison_operator = "LessThanThreshold"
  dimensions          = { DBInstanceIdentifier = aws_db_instance.main.id }
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

# Os dois alarmes abaixo são os únicos que detectam o evento que de fato
# importa: a API morreu. CPU e status check não pegam container caído.
resource "aws_cloudwatch_log_metric_filter" "erros_5xx" {
  name           = "seniors-api-5xx"
  log_group_name = aws_cloudwatch_log_group.api.name
  pattern        = "{ $.status_code = 5* }"

  metric_transformation {
    name          = "ApiErros5xx"
    namespace     = "Seniors"
    value         = "1"
    default_value = "0"
  }
}

resource "aws_cloudwatch_metric_alarm" "api_em_erro" {
  alarm_name          = "seniors-api-5xx"
  namespace           = "Seniors"
  metric_name         = "ApiErros5xx"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 10
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]
}

resource "aws_cloudwatch_metric_alarm" "api_parou_de_logar" {
  alarm_name          = "seniors-api-sem-logs"
  namespace           = "AWS/Logs"
  metric_name         = "IncomingLogEvents"
  statistic           = "Sum"
  period              = 900
  evaluation_periods  = 1
  threshold           = 0
  comparison_operator = "LessThanOrEqualToThreshold"
  dimensions          = { LogGroupName = aws_cloudwatch_log_group.api.name }
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "breaching"
}
