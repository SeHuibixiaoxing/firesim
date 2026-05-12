# adapted from aws-fpga's strategies (minus the extra params + hook tcl)

# The F2 shell can fail with a high-requirement hold path on the OCL read
# response slice. Vivado explicitly recommends this global hold iteration for
# that class of post-route violation.
set_param route.enableGlobalHoldIter 1

set synth_options "-no_lc -shreg_min_size 5 -fsm_extraction one_hot -resource_sharing auto -retiming"
set synth_directive "default"

set opt 1
set opt_options    ""
set opt_directive  "Explore"

set place_options    ""
set place_directive  "ExtraNetDelay_high"

set phys_opt 1
set phys_options     ""
set phys_directive   "AggressiveExplore"

set route_options    "-tns_cleanup"
set route_directive  "Explore"

set route_phys_opt 1
set post_phys_options     ""
set post_phys_directive   "AggressiveExplore"
