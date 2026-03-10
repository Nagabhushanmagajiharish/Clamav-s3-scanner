variable "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "enable_container_insights" {
  description = "Whether to enable CloudWatch container insights"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Map of tags to assign to the ECS cluster"
  type        = map(string)
  default     = {}
}