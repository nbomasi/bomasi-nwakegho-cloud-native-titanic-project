locals {
  name_prefix = "${var.project_name}-${var.environment}"

  availability_zones = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, 3)

  public_subnet_cidrs = length(var.public_subnet_cidrs) > 0 ? var.public_subnet_cidrs : [
    for i in range(length(local.availability_zones)) : cidrsubnet(var.vpc_cidr, 8, i + 1)
  ]

  private_subnet_cidrs = length(var.private_subnet_cidrs) > 0 ? var.private_subnet_cidrs : [
    for i in range(length(local.availability_zones)) : cidrsubnet(var.vpc_cidr, 8, i + 11)
  ]

  common_tags = merge(
    {
      Environment = var.environment
      Project     = var.project_name
      Terraform   = "true"
      Owner       = var.owner
    },
    var.additional_tags
  )
}

