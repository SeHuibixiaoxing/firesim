# TIMING plus explicit router hold fixing.
#
# The 2026-05-04 1BP NIC TIMING build reached route, then Vivado reported a
# large number of hold violators, disabled hold fixing, and later crashed in
# post-route hold-fix phys_opt. Keep the TIMING directives, but apply Vivado's
# own route recommendation before implementation starts.

set_param route.enableGlobalHoldIter 1
set_param route.enableHoldExpnBailout 0

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
