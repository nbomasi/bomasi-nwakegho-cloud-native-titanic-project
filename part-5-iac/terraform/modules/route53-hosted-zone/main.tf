# Data source to look up parent zone if parent_zone_name is provided
data "aws_route53_zone" "parent" {
  count = var.parent_zone_name != "" && var.create_parent_delegation ? 1 : 0

  name         = var.parent_zone_name
  private_zone = false
}

resource "aws_route53_zone" "main" {
  name          = var.domain_name
  comment       = var.zone_comment
  force_destroy = var.force_destroy

  tags = merge(
    var.tags,
    {
      Name        = var.domain_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  )
}

# Delegation record in parent zone (for subdomains)
resource "aws_route53_record" "delegation" {
  count = var.create_parent_delegation && (var.parent_zone_id != "" || var.parent_zone_name != "") ? 1 : 0

  zone_id = var.parent_zone_id != "" ? var.parent_zone_id : data.aws_route53_zone.parent[0].zone_id
  name    = var.domain_name
  type    = "NS"
  ttl     = var.ns_ttl

  records = aws_route53_zone.main.name_servers
}

