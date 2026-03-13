# AWS F2 Migration Notes

This tree has been updated to follow the FireSim `main` branch's AWS F2 flow instead of the older F1-only flow.

## What changed
- Added F2 platform support in FireSim manager, build, and sim paths.
- Switched the default AWS run-farm recipe from `AWSEC2F1` to `AWSEC2F2`.
- Added the `platforms/f2/aws-fpga-firesim-f2` submodule and `deploy/bit-builder-recipes/f2.yaml`.
- Updated AMI lookup to use FPGA Developer AMI Ubuntu `1.17.0`.
- Fixed the `br-base-*.json` workload paths so the basic Linux workload resolves correctly.

## Workflow changes
- FPGA-backed runs now use F2 instance types such as `f2.6xlarge`, `f2.12xlarge`, and `f2.48xlarge`.
- The expected manager flow is unchanged:
  `firesim launchrunfarm -> firesim infrasetup -> firesim runworkload -> firesim terminaterunfarm`
- Verilator-style metasimulation still uses the same manager flow; only the host simulator selection changes in `config_runtime.yaml`.

## Local testing defaults
- The local runtime config continues to use `br-base-uniform.json`.
- The local HWDB keeps the `firesim_rocket_quadcore_no_nic_l2_llc4mb_ddr3` entry, now with the standard FireChip deploy makefrag override.
- The local runtime run-farm host default is now `f2.6xlarge: 1`.

## Notes
- This file documents the migration without modifying the upstream FireSim docs tree.
- If additional submodule-local changes are needed later, switch that submodule to `npu/aws_f2` before editing it.
