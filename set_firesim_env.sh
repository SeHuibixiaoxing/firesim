#!/bin/bash
# =============================================================================
# FireSim 环境变量设置脚本
# 用于提高 infrasetup 时 Java/SBT 编译和 Verilator 编译的线程数
# 
# 使用方法:
#   source ./set_firesim_env.sh <CPU线程数> <Java堆内存>
#
# 示例:
#   source ./set_firesim_env.sh 16 32G
# =============================================================================

# 检查参数
if [ $# -ne 2 ]; then
    echo "错误: 参数数量不正确"
    echo "用法: source $0 <CPU线程数> <Java堆内存>"
    echo "示例: source $0 16 32G"
    return 1
fi

CPU_THREADS=$1
JAVA_HEAP=$2

# 统一使用 FireSim 根目录，避免在 deploy/ 或其他目录 source 时路径错误
FIRESIM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "========================================"
echo "FireSim 环境变量设置"
echo "========================================"
echo "CPU 线程数: $CPU_THREADS"
echo "Java 堆内存: $JAVA_HEAP"
echo ""

# =============================================================================
# 1. Verilator 编译线程数设置
# =============================================================================
export VERILATOR_MAKEFLAGS="-j${CPU_THREADS} VM_PARALLEL_BUILDS=1"
echo "[已设置] VERILATOR_MAKEFLAGS=${VERILATOR_MAKEFLAGS}"

# =============================================================================
# 2. Java/SBT 编译设置
# =============================================================================

# Java 工具选项 (堆内存、栈大小、GC等)
export JAVA_HEAP_SIZE="${JAVA_HEAP}"
export JAVA_TOOL_OPTIONS="-Xmx${JAVA_HEAP} -Xss8M -XX:+UseParallelGC -Djava.io.tmpdir=${FIRESIM_ROOT}/.java_tmp"
echo "[已设置] JAVA_TOOL_OPTIONS=${JAVA_TOOL_OPTIONS}"
echo "[已设置] JAVA_HEAP_SIZE=${JAVA_HEAP_SIZE}"

# SBT 选项 (并行编译、缓存目录等)
export SBT_OPTS="-Dsbt.ivy.home=${FIRESIM_ROOT}/.ivy2 \
                 -Dsbt.global.base=${FIRESIM_ROOT}/.sbt \
                 -Dsbt.boot.directory=${FIRESIM_ROOT}/.sbt/boot/ \
                 -Dsbt.color=always \
                 -Dsbt.supershell=false \
                 -Dsbt.server.forcestart=true \
                 -Dsbt.parallel=true"
echo "[已设置] SBT_OPTS=${SBT_OPTS}"

# 预先创建 Java/SBT 需要的目录，避免运行时因路径不存在导致失败
mkdir -p "${FIRESIM_ROOT}/.java_tmp" "${FIRESIM_ROOT}/.ivy2" "${FIRESIM_ROOT}/.sbt/boot"

# =============================================================================
# 3. 可选: MAKE 并行编译设置
# =============================================================================
export MAKEFLAGS="-j${CPU_THREADS}"
echo "[已设置] MAKEFLAGS=${MAKEFLAGS}"

# =============================================================================
# 4. Vivado 并行任务数（避免大设计综合时 Vivado 进程并发过高导致崩溃）
# =============================================================================
# 可在 source 前自行 export FIRESIM_VIVADO_JOBS 覆盖默认值
export FIRESIM_VIVADO_JOBS="${FIRESIM_VIVADO_JOBS:-1}"
echo "[已设置] FIRESIM_VIVADO_JOBS=${FIRESIM_VIVADO_JOBS}"

# Vivado 单个综合任务内部线程数（和 jobs 不同）。大设计下建议设为 1 提高稳定性。
export FIRESIM_VIVADO_SYNTH_MAX_THREADS="${FIRESIM_VIVADO_SYNTH_MAX_THREADS:-1}"
echo "[已设置] FIRESIM_VIVADO_SYNTH_MAX_THREADS=${FIRESIM_VIVADO_SYNTH_MAX_THREADS}"

echo ""
echo "========================================"
echo "环境变量设置完成!"
echo "========================================"
echo ""
echo "现在可以运行 FireSim 命令:"
echo "  firesim buildbitstream ..."
echo "  firesim infrasetup ..."
echo ""
echo "如需验证设置:"
echo "  echo \$VERILATOR_MAKEFLAGS"
echo "  echo \$JAVA_TOOL_OPTIONS"
echo "  echo \$SBT_OPTS"
echo "  echo \$FIRESIM_VIVADO_JOBS"
echo "  echo \$FIRESIM_VIVADO_SYNTH_MAX_THREADS"
