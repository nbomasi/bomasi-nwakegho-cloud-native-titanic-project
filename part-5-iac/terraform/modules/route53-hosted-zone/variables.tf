variable "domain_name" {
  description = "Domain name for the hosted zone"
  type        = string
}

variable "zone_comment" {
  description = "Comment for the hosted zone"
  type        = string
  default     = "Managed by Terraform"
}

variable "force_destroy" {
  description = "Whether to destroy all records in the zone when deleting"
  type        = bool
  default     = false
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "parent_zone_id" {
  description = "Parent hosted zone ID for subdomain delegation (leave empty if root domain)"
  type        = string
  default     = ""
}

variable "parent_zone_name" {
  description = "Parent domain name (e.g., darey.io for talentos.darey.io subdomain)"
  type        = string
  default     = ""
}

variable "create_parent_delegation" {
  description = "Whether to create NS delegation record in parent zone"
  type        = bool
  default     = false
}

variable "create_ns_record" {
  description = "Whether to create NS record for the zone (deprecated - use create_parent_delegation instead)"
  type        = bool
  default     = false
}

variable "ns_ttl" {
  description = "TTL for NS records in seconds"
  type        = number
  default     = 172800
}

variable "tags" {
  description = "Additional tags for the hosted zone"
  type        = map(string)
  default     = {}
}

