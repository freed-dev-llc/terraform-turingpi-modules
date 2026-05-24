output "flashed_nodes" {
  description = "Map of node number → firmware source that was flashed (URL or local file path)"
  value = merge(
    { for r in turingpi_flash.node1 : "1" => coalesce(r.firmware_url, r.firmware_file) },
    { for r in turingpi_flash.node2 : "2" => coalesce(r.firmware_url, r.firmware_file) },
    { for r in turingpi_flash.node3 : "3" => coalesce(r.firmware_url, r.firmware_file) },
    { for r in turingpi_flash.node4 : "4" => coalesce(r.firmware_url, r.firmware_file) },
  )
}

output "powered_nodes" {
  description = "Map of node number → power state for nodes that were powered on"
  value       = { for k, v in turingpi_power.nodes : k => v.state }
}
