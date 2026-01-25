variable "enable_nodepool_reconciler" {
  description = "Enable the NodePool reconciler to continuously apply patches"
  type        = bool
  default     = true
}

variable "nodepool_name" {
  description = "Name of the NodePool to reconcile"
  type        = string
  default     = "general-purpose"
}

variable "reconcile_interval" {
  description = "Interval in seconds between reconciliation attempts"
  type        = string
  default     = "60"
}

