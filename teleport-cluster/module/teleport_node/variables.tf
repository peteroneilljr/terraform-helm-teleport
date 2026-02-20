variable "nodes" {
  type = map(object({
    name             = string
    namespace        = string
    image            = string
    labels           = optional(list(string), [])
    command          = optional(list(string), ["/bin/sh", "-c"])
    args             = optional(list(string), [])
    replicas         = optional(number, 1)
    wait_for_rollout = optional(bool, false)
    container_env    = optional(map(string), {})
  }))

  default = {}
}
