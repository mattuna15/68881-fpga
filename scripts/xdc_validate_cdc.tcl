# xdc_validate_cdc.tcl
# Post-synthesis validation script for CDC timing constraints.
# Run after open_checkpoint or open_run to verify that all CDC constraint
# targets match actual cells in the design. Alerts on silently empty matches
# that would leave CDC paths unconstrained.
#
# Usage: source scripts/xdc_validate_cdc.tcl

set cdc_error_count 0

proc check_cdc_cells {pattern description} {
    upvar cdc_error_count cnt
    set cells [get_cells -quiet -hier -filter "NAME =~ $pattern"]
    if {[llength $cells] == 0} {
        puts "ERROR: CDC target '$description' not found (pattern: $pattern) - constraint is INACTIVE"
        incr cnt
    } else {
        puts "  OK: $description ([llength $cells] cells match)"
    }
}

puts "=== CDC Constraint Target Validation ==="
puts ""

# ASYNC_REG synchronizer flip-flops
puts "Synchronizer flip-flops:"
check_cdc_cells "*/u_bridge/req_ff*_reg"   "req toggle synchronizer"
check_cdc_cells "*/u_bridge/ack_ff*_reg"   "ack toggle synchronizer"
check_cdc_cells "*/u_bridge/err_ff*_reg"   "error flag synchronizer"
check_cdc_cells "*/u_bridge/valid_ff*_reg" "status_valid synchronizer"
check_cdc_cells "*/u_bridge/rst_ff*_reg"   "reset synchronizer"
puts ""

# False path sources
puts "False path sources:"
check_cdc_cells "*/u_bridge/req_toggle_reg*" "req_toggle (bus_clk -> fpu_clk)"
check_cdc_cells "*/u_bridge/ack_toggle_reg*" "ack_toggle (fpu_clk -> bus_clk)"
check_cdc_cells "*/u_bridge/fpu_error_reg*"  "fpu_error (fpu_clk -> bus_clk)"
check_cdc_cells "*/u_fpu/status_valid_reg*"  "status_valid (fpu_clk -> bus_clk)"
puts ""

# CDC data paths
puts "CDC data path registers:"
check_cdc_cells "*/u_bridge/req_addr_reg*"   "req_addr (bus_clk source)"
check_cdc_cells "*/u_bridge/fpu_addr_reg*"   "fpu_addr (fpu_clk destination)"
check_cdc_cells "*/u_bridge/req_wdata_reg*"  "req_wdata (bus_clk source)"
check_cdc_cells "*/u_bridge/fpu_wdata_reg*"  "fpu_wdata (fpu_clk destination)"
check_cdc_cells "*/u_bridge/req_rw_reg*"     "req_rw (bus_clk source)"
check_cdc_cells "*/u_bridge/fpu_rw_reg*"     "fpu_rw (fpu_clk destination)"
check_cdc_cells "*/u_bridge/rdata_fpu_reg*"  "rdata_fpu (fpu_clk source)"
check_cdc_cells "*/rdata_reg*"               "rdata (bus_clk destination)"
puts ""

# Summary
if {$cdc_error_count > 0} {
    puts "=== FAILED: $cdc_error_count CDC constraint target(s) not found ==="
    puts "Constraints targeting missing cells are silently inactive."
    puts "Check for renamed signals or constant-folded registers."
} else {
    puts "=== PASSED: All CDC constraint targets found ==="
}
