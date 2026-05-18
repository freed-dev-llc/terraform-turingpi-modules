output "flashed_nodes" {
  description = "Map of node number → firmware file path that was flashed"
  value = merge(
    { for r in turingpi_flash.node1 : "1" => r.firmware_file },
    { for r in turingpi_flash.node2 : "2" => r.firmware_file },
    { for r in turingpi_flash.node3 : "3" => r.firmware_file },
    { for r in turingpi_flash.node4 : "4" => r.firmware_file },
  )
}

output "powered_nodes" {
  description = "Map of node number → power state for nodes that were powered on"
  value       = { for k, v in turingpi_power.nodes : k => v.state }
}
