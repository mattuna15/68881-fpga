# Non-incremental synthesis + implementation for MC68881 FPGA
# Run via: vivado -mode batch -source scripts/run_impl.tcl

set project_path "C:/code/68881-fpga/project/fpga68881/fpga68881.xpr"
set report_dir "C:/code/68881-fpga/reports"
file mkdir $report_dir

puts "=== Opening project ==="
open_project $project_path

# Force non-incremental synthesis
puts "=== Configuring non-incremental synthesis ==="
set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs synth_1]
set_property INCREMENTAL_CHECKPOINT "" [get_runs synth_1]

# Reset both runs
puts "=== Resetting runs ==="
reset_run synth_1
reset_run impl_1

# Launch synthesis
puts "=== Launching synthesis ==="
launch_runs synth_1
wait_on_run synth_1
set synth_status [get_property STATUS [get_runs synth_1]]
puts "Synthesis status: $synth_status"
if {[string match "*ERROR*" $synth_status]} {
    puts "ERROR: Synthesis failed"
    exit 1
}

# Generate post-synth utilization report
open_run synth_1
report_utilization -file "$report_dir/post_synth_util.rpt"
report_utilization -hierarchical -hierarchical_depth 10 -file "$report_dir/post_synth_util_hier.rpt"
close_design

# Launch implementation
puts "=== Launching implementation ==="
launch_runs impl_1
wait_on_run impl_1
set impl_status [get_property STATUS [get_runs impl_1]]
puts "Implementation status: $impl_status"
if {[string match "*ERROR*" $impl_status]} {
    puts "ERROR: Implementation failed"
    exit 1
}

# Generate post-impl reports
puts "=== Generating reports ==="
open_run impl_1
report_utilization -file "$report_dir/post_impl_util.rpt"
report_utilization -hierarchical -hierarchical_depth 10 -file "$report_dir/post_impl_util_hier.rpt"
report_timing_summary -max_paths 10 -file "$report_dir/timing_summary.rpt"
report_timing -max_paths 20 -sort_by slack -file "$report_dir/timing_paths.rpt"
report_power -file "$report_dir/power.rpt"
report_drc -file "$report_dir/drc.rpt"
report_methodology -file "$report_dir/methodology.rpt"
report_clock_utilization -file "$report_dir/clock_util.rpt"
report_route_status -file "$report_dir/route_status.rpt"
close_design

puts "=== Done ==="
puts "Reports written to: $report_dir/"
exit 0
