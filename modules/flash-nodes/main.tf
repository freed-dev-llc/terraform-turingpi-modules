# Flash resources are intentionally chained sequentially (depends_on)
# rather than using for_each. The Turing Pi 2 BMC's USB only supports
# one node at a time — parallel flashes collide with errors like
# "Bus 002 Device 014: ID 2207:350b Resource busy" (fixes #29).
#
# The Turing Pi 2 has exactly 4 node slots. `count` lets users specify
# a subset of nodes in `var.nodes` while preserving the chain ordering
# for whichever subset is selected.

resource "turingpi_flash" "node1" {
  count         = contains(keys(var.nodes), "1") ? 1 : 0
  node          = 1
  firmware_file = var.nodes["1"].firmware
}

resource "turingpi_flash" "node2" {
  count         = contains(keys(var.nodes), "2") ? 1 : 0
  depends_on    = [turingpi_flash.node1]
  node          = 2
  firmware_file = var.nodes["2"].firmware
}

resource "turingpi_flash" "node3" {
  count         = contains(keys(var.nodes), "3") ? 1 : 0
  depends_on    = [turingpi_flash.node2]
  node          = 3
  firmware_file = var.nodes["3"].firmware
}

resource "turingpi_flash" "node4" {
  count         = contains(keys(var.nodes), "4") ? 1 : 0
  depends_on    = [turingpi_flash.node3]
  node          = 4
  firmware_file = var.nodes["4"].firmware
}

# Power on can run in parallel — no BMC contention for power state changes.
# All powers wait for every selected flash to finish.
resource "turingpi_power" "nodes" {
  for_each = var.power_on_after_flash ? var.nodes : {}
  depends_on = [
    turingpi_flash.node1,
    turingpi_flash.node2,
    turingpi_flash.node3,
    turingpi_flash.node4,
  ]

  node  = tonumber(each.key)
  state = "on"
}
