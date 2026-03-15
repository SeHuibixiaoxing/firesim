#!/bin/bash

# This script is called by FireSim's bitbuilder to create a xclbin

# exit script if any command fails
set -e
set -o pipefail

usage() {
    echo "usage: ${0} [OPTIONS]"
    echo ""
    echo "Options"
    echo "   --cl_dir    : Custom logic directory to build AWS F1 bitstream from"
    echo "   --frequency : Frequency in MHz of the desired FPGA host clock."
    echo "   --strategy  : A string to a precanned set of build directives.
                          See aws-fpga documentation for more info/"
    echo "   --help      : Display this message"
    exit "$1"
}

CL_DIR=""
FREQUENCY=""
STRATEGY=""

ensure_shell_checkpoint() {
    local shell_mode="small_shell"
    local shell_version_file shell_version shell_root checkpoint_dir
    local dcp_name dcp_path sha_path shell_url expected_sha actual_sha

    shell_root="${HDK_SHELL_DIR}"
    shell_version_file="${shell_root}/shell_version.txt"
    shell_version=$(awk -F= -v mode="${shell_mode}" '$1 == mode { print $2 }' "${shell_version_file}")

    if [ -z "${shell_version}" ]; then
        echo "Unable to determine ${shell_mode} version from ${shell_version_file}" >&2
        exit 1
    fi

    checkpoint_dir="${shell_root}/build/checkpoints/from_aws"
    dcp_name="cl_bb_routed.${shell_mode}.dcp"
    dcp_path="${checkpoint_dir}/${dcp_name}"
    sha_path="${dcp_path}.sha256"
    shell_url="https://aws-fpga-hdk-resources.s3.amazonaws.com/hdk/shell_v${shell_version#0x}"

    mkdir -p "${checkpoint_dir}"

    wget -q "${shell_url}/${dcp_name}.sha256" -O "${sha_path}.tmp"
    expected_sha=$(awk '{print $1}' "${sha_path}.tmp")

    if [ -f "${dcp_path}" ]; then
        actual_sha=$(sha256sum "${dcp_path}" | awk '{print $1}')
    else
        actual_sha=""
    fi

    if [ "${actual_sha}" != "${expected_sha}" ]; then
        echo "Refreshing ${dcp_name} from ${shell_url}" >&2
        wget -q "${shell_url}/${dcp_name}" -O "${dcp_path}.tmp"
        actual_sha=$(sha256sum "${dcp_path}.tmp" | awk '{print $1}')

        if [ "${actual_sha}" != "${expected_sha}" ]; then
            echo "SHA256 mismatch for ${dcp_name}" >&2
            echo "Expected: ${expected_sha}" >&2
            echo "Actual:   ${actual_sha}" >&2
            rm -f "${dcp_path}.tmp" "${sha_path}.tmp"
            exit 1
        fi

        mv "${dcp_path}.tmp" "${dcp_path}"
    fi

    mv "${sha_path}.tmp" "${sha_path}"
}

# getopts does not support long options, and is inflexible
# ensure $1 arg is empty or else hdk_setup.sh will fail
while [ "$1" != "" ];
do
    case $1 in
        --help)
            usage 1 ;;
        --cl_dir )
            shift
            CL_DIR=$1 ;;
        --strategy )
            shift
            STRATEGY=$1 ;;
        --frequency )
            shift
            FREQUENCY=$1 ;;
        * )
            echo "invalid option $1"
            usage 1 ;;
    esac
    shift
done

if [ -z "$CL_DIR" ] ; then
    echo "no cl directory specified"
    usage 1
fi

if [ -z "$FREQUENCY" ] ; then
    echo "No --frequency specified"
    usage 1
fi

if [ -z "$STRATEGY" ] ; then
    echo "No --strategy specified"
    usage 1
fi

AWS_FPGA_DIR=$CL_DIR/../../../..

# setup hdk; keep -s so the remote build uses the rsynced manager snapshot instead of
# mutating submodules on the build host, then self-heal the required shell checkpoint
cd $AWS_FPGA_DIR
source hdk_setup.sh -s
ensure_shell_checkpoint

export CL_DIR=$CL_DIR

# run build
cd $CL_DIR/build/scripts
# ./aws_build_dcp_from_cl.sh  -strategy $STRATEGY -frequency $FREQUENCY -foreground
export CL_NAME=$(basename $CL_DIR)

./aws_build_dcp_from_cl.py -c $CL_NAME --frequency $FREQUENCY --aws_clk_gen --clock_recipe_a A1  --clock_recipe_b B0 --clock_recipe_c C0 --mode small_shell
