# =============================================================================
# Amazon FPGA Hardware Development Kit
#
# Copyright 2024 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
# Licensed under the Amazon Software License (the "License"). You may not use
# this file except in compliance with the License. A copy of the License is
# located at
#
#    http://aws.amazon.com/asl/
#
# or in the "license" file accompanying this file. This file is distributed on
# an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or
# implied. See the License for the specific language governing permissions and
# limitations under the License.
# =============================================================================


# Common CL Implementation Tcl Script


# AWS shell DCP location
set AWS_DCP_DIR "${HDK_SHELL_DIR}/build/checkpoints/from_aws/"


###############################################################################
print "Start linking customer design ${CL}"
###############################################################################
add_files ${AWS_DCP_DIR}/cl_bb_routed.${SHELL_MODE}.dcp
add_files ${checkpoints_dir}/${CL}.${TAG}.post_synth.dcp

set_property SCOPED_TO_CELLS {WRAPPER/CL} \
             [get_files ${checkpoints_dir}/${CL}.${TAG}.post_synth.dcp]

link_design -mode default \
            -reconfig_partitions {WRAPPER/CL} \
            -top top

print "Writing post-link design checkpoint"
write_checkpoint -force ${checkpoints_dir}/${CL}.${TAG}.post_link.dcp

#######################################
#
# MMCM Clock recipe constraints
#
#######################################
source $HDK_SHELL_DIR/build/scripts/aws_clock_properties.tcl

#######################################
# Floorplan Constraints
#######################################
# Dynamic region floorplan (CL)
read_xdc ${HDK_SHELL_DIR}/build/constraints/${SHELL_MODE}_level_1_fp_cl.xdc

# User defined floorplan (use SLR0/SLR1/SLR2 from main floorplan)
read_xdc ${constraints_dir}/${SHELL_MODE}_cl_pnr_user.xdc

# Optional, MIG placement training
source ${HDK_SHELL_DIR}/build/scripts/ddr_io_train.tcl

# # MMCM cascade placement constraint
# read_xdc ${HDK_SHELL_DESIGN_DIR}/../build/constraints/mmcm_cascade.xdc

###############################################################################
print "Start optimizing customer design ${CL}"
###############################################################################
set opt_cmd [list opt_design]
if {[info exists STRATEGY_OPT_OPTIONS] && $STRATEGY_OPT_OPTIONS ne ""} {
    set opt_cmd [concat $opt_cmd $STRATEGY_OPT_OPTIONS]
}
if {[info exists STRATEGY_OPT_DIRECTIVE] && $STRATEGY_OPT_DIRECTIVE ne ""} {
    lappend opt_cmd -directive $STRATEGY_OPT_DIRECTIVE
}
puts "AWS FPGA: opt command: $opt_cmd"
eval $opt_cmd

# Work Around 2025.1 HBM DONT TOUCH issue
# https://adaptivesupport.amd.com/s/article/000038502?language=en_US&t=1754923887312
if {[llength [get_cells -quiet WRAPPER/CL/CL_HBM/HBM_PRESENT_EQ_1.HBM_WRAPPER_I/HBM_CORE_I/inst]] > 0} {
    puts "INFO: HBM found, setting DONT_TOUCH to 0"
    set_property DONT_TOUCH 0 [get_cells WRAPPER/CL/CL_HBM/HBM_PRESENT_EQ_1.HBM_WRAPPER_I/HBM_CORE_I/inst]
}

print "Writing post-opt design checkpoint and report"
write_checkpoint -force ${checkpoints_dir}/${CL}.${TAG}.post_opt.dcp

report_timing -delay_type max \
              -path_type full_clock_expanded \
              -max_paths 10 \
              -nworst 1 \
              -input_pins \
              -slice_pins \
              -sort_by group \
              -significant_digits 3 \
              -file ${reports_dir}/${CL}.${TAG}.post_opt_timing.rpt


###############################################################################
print "Start placing customer design ${CL}"
###############################################################################
# open_checkpoint ${checkpoints_dir}/${CL}.${TAG}.post_opt.dcp

set place_cmd [list place_design]
if {[info exists STRATEGY_PLACE_OPTIONS] && $STRATEGY_PLACE_OPTIONS ne ""} {
    set place_cmd [concat $place_cmd $STRATEGY_PLACE_OPTIONS]
}
if {$PLACE_DIRECT ne ""} {
    lappend place_cmd -directive $PLACE_DIRECT
}
lappend place_cmd -no_bufg_opt
puts "AWS FPGA: place command: $place_cmd"
eval $place_cmd

print "Writing post-place design checkpoint and report"

write_checkpoint -force ${checkpoints_dir}/${CL}.${TAG}.post_place.dcp

report_timing -delay_type max \
              -path_type full_clock_expanded \
              -max_paths 10 \
              -nworst 1 \
              -input_pins \
              -slice_pins \
              -sort_by group \
              -significant_digits 3 \
              -file $reports_dir/${CL}.${TAG}.post_place_timing.rpt


###############################################################################
print "Start physical-optimizing customer design ${CL}"
###############################################################################
if {![info exists STRATEGY_PHYS_OPT] || $STRATEGY_PHYS_OPT != 0} {
    set phys_opt_cmd [list phys_opt_design]
    if {[info exists STRATEGY_PHYS_OPTIONS] && $STRATEGY_PHYS_OPTIONS ne ""} {
        set phys_opt_cmd [concat $phys_opt_cmd $STRATEGY_PHYS_OPTIONS]
    }
    if {$PHY_OPT_DIRECT ne ""} {
        lappend phys_opt_cmd -directive $PHY_OPT_DIRECT
    }
    puts "AWS FPGA: phys_opt command: $phys_opt_cmd"
    eval $phys_opt_cmd
} else {
    puts "AWS FPGA: skipping pre-route phys_opt_design due to strategy setting"
}

print "Writing post-phy_opt design checkpoint and report"

write_checkpoint -force ${checkpoints_dir}/${CL}.${TAG}.post_phys_opt.dcp

report_timing -delay_type max \
              -path_type full_clock_expanded \
              -max_paths 10 \
              -nworst 1 \
              -input_pins \
              -slice_pins \
              -sort_by group \
              -significant_digits 3 \
              -file $reports_dir/${CL}.${TAG}.post_phy_opt_timing.rpt


###############################################################################
print "Start routing customer design ${CL}"
###############################################################################
set route_cmd [list route_design]
if {[info exists STRATEGY_ROUTE_OPTIONS] && $STRATEGY_ROUTE_OPTIONS ne ""} {
    set route_cmd [concat $route_cmd $STRATEGY_ROUTE_OPTIONS]
}
if {$ROUTE_DIRECT ne ""} {
    lappend route_cmd -directive $ROUTE_DIRECT
}
lappend route_cmd -timing_summary
puts "AWS FPGA: route command: $route_cmd"
eval $route_cmd

if {[info exists STRATEGY_ROUTE_PHYS_OPT] && $STRATEGY_ROUTE_PHYS_OPT != 0} {
    print "Start post-route physical-optimizing customer design ${CL}"
    set post_phys_cmd [list phys_opt_design]
    if {[info exists STRATEGY_POST_PHYS_OPTIONS] && $STRATEGY_POST_PHYS_OPTIONS ne ""} {
        set post_phys_cmd [concat $post_phys_cmd $STRATEGY_POST_PHYS_OPTIONS]
    }
    if {[info exists STRATEGY_POST_PHYS_DIRECTIVE] && $STRATEGY_POST_PHYS_DIRECTIVE ne ""} {
        lappend post_phys_cmd -directive $STRATEGY_POST_PHYS_DIRECTIVE
    }
    puts "AWS FPGA: post-route phys_opt command: $post_phys_cmd"
    eval $post_phys_cmd

    print "Writing post-route phys_opt checkpoint and report"
    write_checkpoint -force ${checkpoints_dir}/${CL}.${TAG}.post_route_phys_opt.dcp

    report_timing -delay_type max \
                  -path_type full_clock_expanded \
                  -max_paths 10 \
                  -nworst 1 \
                  -input_pins \
                  -slice_pins \
                  -sort_by group \
                  -significant_digits 3 \
                  -file ${reports_dir}/${CL}.${TAG}.post_route_phys_opt_timing.rpt
} else {
    puts "AWS FPGA: skipping post-route phys_opt_design due to strategy setting"
}

print "Writing post-route design checkpoint and report"

set failPath [check_timing_path]
if {$failPath>0} {
    write_checkpoint -force ${checkpoints_dir}/${CL}.${TAG}.post_route.VIOLATED.dcp
} else {
    write_checkpoint -force ${checkpoints_dir}/${CL}.${TAG}.post_route.dcp
}

report_timing -delay_type max \
              -path_type full_clock_expanded \
              -max_paths 10 \
              -nworst 1 \
              -input_pins \
              -slice_pins \
              -sort_by group \
              -significant_digits 3 \
              -file ${reports_dir}/${CL}.${TAG}.post_route_timing.rpt

write_debug_probes -no_partial_ltxfile -force ${checkpoints_dir}/${TAG}.debug_probes.ltx


###############################################################################
print "Finished building design checkpoints for customer design ${CL}"
###############################################################################

close_design
