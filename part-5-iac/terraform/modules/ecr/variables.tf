# ECR Module Variables - V1 Migration
# This module creates ECR repositories and IAM policies for IRSA access

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "ecr_namespace" {
  description = "ECR namespace/prefix for repositories (e.g., 'dareyioinfra', 'v1', or empty for root)"
  type        = string
  default     = "dareyioinfra"
}

variable "repositories" {
  description = "List of ECR repository names to create"
  type        = list(string)
  default     = []
}

variable "image_tag_mutability" {
  description = "The tag mutability setting for the repository. Must be one of: MUTABLE or IMMUTABLE"
  type        = string
  default     = "MUTABLE"
}

variable "scan_on_push" {
  description = "Indicates whether images are scanned after being pushed to the repository"
  type        = bool
  default     = true
}

variable "irsa_role_arn" {
  description = "ARN of the IAM role for IRSA (for ECR pull access by pods)"
  type        = string
  default     = ""
}

variable "pipeline_role_arn" {
  description = "ARN of the IAM role for pipeline (GitLab Runner) to attach ECR push policy"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Additional tags to apply to IAM policies and repositories"
  type        = map(string)
  default     = {}
}
