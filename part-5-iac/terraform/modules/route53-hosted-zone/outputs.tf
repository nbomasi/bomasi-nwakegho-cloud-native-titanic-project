output "zone_id" {
  description = "The hosted zone ID"
  value       = aws_route53_zone.main.zone_id
}

output "zone_arn" {
  description = "The hosted zone ARN"
  value       = aws_route53_zone.main.arn
}

output "name_servers" {
  description = "List of name servers for the hosted zone"
  value       = aws_route53_zone.main.name_servers
}

output "domain_name" {
  description = "The domain name of the hosted zone"
  value       = aws_route53_zone.main.name
}

output "zone_comment" {
  description = "The comment for the hosted zone"
  value       = aws_route53_zone.main.comment
}

