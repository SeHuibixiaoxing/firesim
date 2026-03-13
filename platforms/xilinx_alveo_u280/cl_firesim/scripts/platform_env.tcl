if {[info exists ::env(FIRESIM_VIVADO_JOBS)] && $::env(FIRESIM_VIVADO_JOBS) ne ""} {
  set jobs $::env(FIRESIM_VIVADO_JOBS)
} else {
  set jobs 8
}
