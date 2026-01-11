variable "nodes" {
  type = map(object({
    name             = string
    namespace        = string
    image            = string
    command          = optional(list(string), ["/bin/sh", "-c"])
    args             = optional(list(string), [])
    replicas         = optional(number, 1)
    wait_for_rollout = optional(bool, false)
  }))

  default = {}
}
