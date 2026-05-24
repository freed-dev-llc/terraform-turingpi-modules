variable "nodes" {
  description = "Map of node number → firmware configuration. Keys must be \"1\", \"2\", \"3\", or \"4\" (Turing Pi 2 has 4 node slots)."
  type = map(object({
    # Firmware source. An http(s):// URL is flashed via firmware_url (BMC pulls
    # directly — reliable completion signal); any other value is treated as a
    # local file path via firmware_file.
    firmware = string
  }))

  validation {
    condition     = alltrue([for k in keys(var.nodes) : contains(["1", "2", "3", "4"], k)])
    error_message = "Node keys must be \"1\", \"2\", \"3\", or \"4\"."
  }
}

variable "power_on_after_flash" {
  description = "Power on nodes after flashing"
  type        = bool
  default     = true
}
