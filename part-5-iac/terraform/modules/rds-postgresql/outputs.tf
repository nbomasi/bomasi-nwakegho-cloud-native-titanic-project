output "db_instance_id" {
  description = "RDS instance ID"
  value       = aws_db_instance.postgresql.id
}

output "db_instance_arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.postgresql.arn
}

output "db_instance_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.postgresql.endpoint
}

output "db_instance_address" {
  description = "RDS instance address"
  value       = aws_db_instance.postgresql.address
}

output "db_instance_port" {
  description = "RDS instance port"
  value       = aws_db_instance.postgresql.port
}

output "db_instance_name" {
  description = "Database name"
  value       = aws_db_instance.postgresql.db_name
}

output "db_instance_username" {
  description = "Master username"
  value       = aws_db_instance.postgresql.username
  sensitive   = true
}

output "secrets_manager_secret_arn" {
  description = "ARN of the Secrets Manager secret containing database credentials"
  value       = aws_secretsmanager_secret.rds_credentials.arn
}

output "secrets_manager_secret_name" {
  description = "Name of the Secrets Manager secret containing database credentials"
  value       = aws_secretsmanager_secret.rds_credentials.name
}

output "security_group_id" {
  description = "Security group ID for RDS"
  value       = aws_security_group.rds.id
}

output "subnet_group_id" {
  description = "DB subnet group ID"
  value       = aws_db_subnet_group.postgresql.id
}

output "connection_string" {
  description = "PostgreSQL connection string (without password)"
  value       = "postgresql://${aws_db_instance.postgresql.username}@${aws_db_instance.postgresql.address}:${aws_db_instance.postgresql.port}/${aws_db_instance.postgresql.db_name}"
  sensitive   = true
}
