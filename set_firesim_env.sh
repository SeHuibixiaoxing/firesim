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
export JAVA_TOOL_OPTIONS="-Xmx${JAVA_HEAP} -Xss8M -XX:+UseParallelGC -Djava.io.tmpdir=${PWD}/.java_tmp"
echo "[已设置] JAVA_TOOL_OPTIONS=${JAVA_TOOL_OPTIONS}"

# SBT 选项 (并行编译、缓存目录等)
export SBT_OPTS="-Dsbt.ivy.home=${PWD}/.ivy2 \
                 -Dsbt.global.base=${PWD}/.sbt \
                 -Dsbt.boot.directory=${PWD}/.sbt/boot/ \
                 -Dsbt.color=always \
                 -Dsbt.supershell=false \
                 -Dsbt.server.forcestart=true \
                 -Dsbt.parallel=true"
echo "[已设置] SBT_OPTS=${SBT_OPTS}"

# =============================================================================
# 3. 可选: MAKE 并行编译设置
# =============================================================================
export MAKEFLAGS="-j${CPU_THREADS}"
echo "[已设置] MAKEFLAGS=${MAKEFLAGS}"

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
