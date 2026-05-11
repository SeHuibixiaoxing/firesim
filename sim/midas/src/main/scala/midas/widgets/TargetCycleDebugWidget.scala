// See LICENSE for license details.

package midas.widgets

import chisel3._
import chisel3.util._
import org.chipsalliance.cde.config.Parameters

import firesim.lib.bridgeutils._

object TargetCycleDebugWidget {
  val MaskBits = 256
  val MaskChunks = MaskBits / 32

  def activeMask(count: Int): UInt = {
    val clipped = math.min(count, MaskBits)
    VecInit(Seq.fill(clipped)(true.B) ++ Seq.fill(MaskBits - clipped)(false.B)).asUInt
  }
}

case class TargetCycleDebugParameters(
  hportLabels: Seq[String],
  wireInputLabels: Seq[String],
  wireOutputLabels: Seq[String],
  rvInputLabels: Seq[String],
  rvOutputLabels: Seq[String],
)

class TargetCycleDebugSignals extends Bundle {
  import TargetCycleDebugWidget._

  val trigger = Bool()

  val hportToHostValid = UInt(MaskBits.W)
  val hportToHostReady = UInt(MaskBits.W)
  val hportFromHostValid = UInt(MaskBits.W)
  val hportFromHostReady = UInt(MaskBits.W)

  val wireInputValid = UInt(MaskBits.W)
  val wireInputReady = UInt(MaskBits.W)
  val wireOutputValid = UInt(MaskBits.W)
  val wireOutputReady = UInt(MaskBits.W)

  val rvInputFwdValid = UInt(MaskBits.W)
  val rvInputFwdReady = UInt(MaskBits.W)
  val rvInputRevValid = UInt(MaskBits.W)
  val rvInputRevReady = UInt(MaskBits.W)

  val rvOutputFwdValid = UInt(MaskBits.W)
  val rvOutputFwdReady = UInt(MaskBits.W)
  val rvOutputRevValid = UInt(MaskBits.W)
  val rvOutputRevReady = UInt(MaskBits.W)
}

class TargetCycleDebugWidgetIO(implicit p: Parameters) extends WidgetIO()(p) {
  val debug = Input(new TargetCycleDebugSignals)
}

class TargetCycleDebugWidget(params: TargetCycleDebugParameters)(implicit p: Parameters) extends Widget()(p) {
  import TargetCycleDebugWidget._

  lazy val module = new WidgetImp(this) {
    val io = IO(new TargetCycleDebugWidgetIO)

    val hcycle = RegInit(0.U(64.W))
    hcycle := hcycle + 1.U

    val triggerCount = RegInit(0.U(32.W))
    val firstValid = RegInit(false.B)
    val firstTriggerCycle = RegInit(0.U(64.W))
    val lastTriggerCycle = RegInit(0.U(64.W))

    val hportActive     = activeMask(params.hportLabels.size)
    val wireInputActive = activeMask(params.wireInputLabels.size)
    val wireOutputActive = activeMask(params.wireOutputLabels.size)
    val rvInputActive   = activeMask(params.rvInputLabels.size)
    val rvOutputActive  = activeMask(params.rvOutputLabels.size)

    val maskInputs = Seq(
      "hport_to_host_valid" -> io.debug.hportToHostValid,
      "hport_to_host_ready" -> io.debug.hportToHostReady,
      "hport_from_host_valid" -> io.debug.hportFromHostValid,
      "hport_from_host_ready" -> io.debug.hportFromHostReady,
      "wire_input_valid" -> io.debug.wireInputValid,
      "wire_input_ready" -> io.debug.wireInputReady,
      "wire_output_valid" -> io.debug.wireOutputValid,
      "wire_output_ready" -> io.debug.wireOutputReady,
      "rv_input_fwd_valid" -> io.debug.rvInputFwdValid,
      "rv_input_fwd_ready" -> io.debug.rvInputFwdReady,
      "rv_input_rev_valid" -> io.debug.rvInputRevValid,
      "rv_input_rev_ready" -> io.debug.rvInputRevReady,
      "rv_output_fwd_valid" -> io.debug.rvOutputFwdValid,
      "rv_output_fwd_ready" -> io.debug.rvOutputFwdReady,
      "rv_output_rev_valid" -> io.debug.rvOutputRevValid,
      "rv_output_rev_ready" -> io.debug.rvOutputRevReady,
    )

    val derivedMaskInputs = Seq(
      "hport_to_host_blocked" -> (io.debug.hportToHostValid & ~io.debug.hportToHostReady & hportActive),
      "hport_from_host_blocked" -> (io.debug.hportFromHostValid & ~io.debug.hportFromHostReady & hportActive),
      "wire_input_missing_valid" -> (~io.debug.wireInputValid & wireInputActive),
      "wire_input_backpressured" -> (io.debug.wireInputValid & ~io.debug.wireInputReady & wireInputActive),
      "wire_output_blocked" -> (io.debug.wireOutputValid & ~io.debug.wireOutputReady & wireOutputActive),
      "rv_input_fwd_missing_valid" -> (~io.debug.rvInputFwdValid & rvInputActive),
      "rv_input_fwd_backpressured" -> (io.debug.rvInputFwdValid & ~io.debug.rvInputFwdReady & rvInputActive),
      "rv_input_rev_backpressured" -> (io.debug.rvInputRevValid & ~io.debug.rvInputRevReady & rvInputActive),
      "rv_output_fwd_blocked" -> (io.debug.rvOutputFwdValid & ~io.debug.rvOutputFwdReady & rvOutputActive),
      "rv_output_rev_missing_valid" -> (~io.debug.rvOutputRevValid & rvOutputActive),
      "rv_output_rev_backpressured" -> (io.debug.rvOutputRevValid & ~io.debug.rvOutputRevReady & rvOutputActive),
    )

    val problemLive = derivedMaskInputs.map(_._2.orR).foldLeft(false.B)(_ || _)
    val captureLive = io.debug.trigger || problemLive
    val problemCount = RegInit(0.U(32.W))
    val cleanCount = RegInit(0.U(32.W))
    val triggerCount64 = RegInit(0.U(64.W))
    val problemCount64 = RegInit(0.U(64.W))
    val cleanCount64 = RegInit(0.U(64.W))
    val problemStreak = RegInit(0.U(32.W))
    val problemMaxStreak = RegInit(0.U(32.W))
    val cleanStreak = RegInit(0.U(32.W))
    val cleanMaxStreak = RegInit(0.U(32.W))

    val firstMasks = maskInputs.map { case (name, _) => name -> RegInit(0.U(MaskBits.W)) }
    val lastMasks = maskInputs.map { case (name, _) => name -> RegInit(0.U(MaskBits.W)) }

    when(problemLive) {
      problemCount := problemCount + 1.U
      problemCount64 := problemCount64 + 1.U
      cleanStreak := 0.U
      val nextStreak = problemStreak + 1.U
      problemStreak := nextStreak
      when(nextStreak > problemMaxStreak) {
        problemMaxStreak := nextStreak
      }
    }.otherwise {
      cleanCount := cleanCount + 1.U
      cleanCount64 := cleanCount64 + 1.U
      problemStreak := 0.U
      val nextStreak = cleanStreak + 1.U
      cleanStreak := nextStreak
      when(nextStreak > cleanMaxStreak) {
        cleanMaxStreak := nextStreak
      }
    }

    when(captureLive) {
      triggerCount := triggerCount + 1.U
      triggerCount64 := triggerCount64 + 1.U
      lastTriggerCycle := hcycle
      lastMasks.zip(maskInputs).foreach { case ((_, reg), (_, live)) => reg := live }
      when(!firstValid) {
        firstValid := true.B
        firstTriggerCycle := hcycle
        firstMasks.zip(maskInputs).foreach { case ((_, reg), (_, live)) => reg := live }
      }
    }

    case class DerivedGroup(
      name: String,
      labels: Seq[String],
      live: UInt,
      firstValid: Bool,
      first: UInt,
      last: UInt,
      count: UInt,
      count64: UInt,
      streak: UInt,
      maxStreak: UInt,
      bitCounts: Seq[UInt],
    )

    val derivedGroups = derivedMaskInputs.map { case (name, live) =>
      val firstValid = RegInit(false.B)
      val first = RegInit(0.U(MaskBits.W))
      val last = RegInit(0.U(MaskBits.W))
      val count = RegInit(0.U(32.W))
      val count64 = RegInit(0.U(64.W))
      val streak = RegInit(0.U(32.W))
      val maxStreak = RegInit(0.U(32.W))
      val bitCounts = Seq.fill(math.min(MaskBits, groupLabels(name).size))(RegInit(0.U(32.W)))

      when(live.orR) {
        count := count + 1.U
        count64 := count64 + 1.U
        last := live
        val nextStreak = streak + 1.U
        streak := nextStreak
        when(nextStreak > maxStreak) {
          maxStreak := nextStreak
        }
        when(!firstValid) {
          firstValid := true.B
          first := live
        }
      }.otherwise {
        streak := 0.U
      }
      bitCounts.zipWithIndex.foreach { case (counter, idx) =>
        when(live(idx)) {
          counter := counter + 1.U
        }
      }

      DerivedGroup(name, groupLabels(name), live, firstValid, first, last, count, count64, streak, maxStreak, bitCounts)
    }

    def attachRO[T <: Data](wire: T, name: String): Unit = {
      genROReg(wire, name, substruct = false)
    }

    def attachMask(prefix: String, mask: UInt): Unit = {
      for (idx <- 0 until MaskChunks) {
        val lo = idx * 32
        val hi = lo + 31
        attachRO(mask(hi, lo), s"${prefix}_${idx}")
      }
    }

    def attachU64(prefix: String, value: UInt): Unit = {
      attachRO(value(31, 0), s"${prefix}_lo")
      attachRO(value(63, 32), s"${prefix}_hi")
    }

    attachRO(hcycle(31, 0), "hcycle_lo")
    attachRO(hcycle(63, 32), "hcycle_hi")
    attachRO(captureLive, "trigger_live")
    attachRO(io.debug.trigger, "raw_trigger_live")
    attachRO(problemLive, "problem_live")
    attachRO(triggerCount, "trigger_count")
    attachRO(problemCount, "problem_count")
    attachRO(cleanCount, "clean_count")
    attachU64("trigger_count64", triggerCount64)
    attachU64("problem_count64", problemCount64)
    attachU64("clean_count64", cleanCount64)
    attachRO(problemStreak, "problem_streak")
    attachRO(problemMaxStreak, "problem_max_streak")
    attachRO(cleanStreak, "clean_streak")
    attachRO(cleanMaxStreak, "clean_max_streak")
    attachRO(firstValid, "first_valid")
    attachRO(firstTriggerCycle(31, 0), "first_trigger_cycle_lo")
    attachRO(firstTriggerCycle(63, 32), "first_trigger_cycle_hi")
    attachRO(lastTriggerCycle(31, 0), "last_trigger_cycle_lo")
    attachRO(lastTriggerCycle(63, 32), "last_trigger_cycle_hi")

    attachRO(params.hportLabels.size.U(32.W), "hport_count")
    attachRO(params.wireInputLabels.size.U(32.W), "wire_input_count")
    attachRO(params.wireOutputLabels.size.U(32.W), "wire_output_count")
    attachRO(params.rvInputLabels.size.U(32.W), "rv_input_count")
    attachRO(params.rvOutputLabels.size.U(32.W), "rv_output_count")

    maskInputs.foreach { case (name, live) => attachMask(s"live_${name}", live) }
    firstMasks.foreach { case (name, reg) => attachMask(s"first_${name}", reg) }
    lastMasks.foreach { case (name, reg) => attachMask(s"last_${name}", reg) }
    derivedGroups.foreach { group =>
      attachRO(group.firstValid, s"${group.name}_first_valid")
      attachRO(group.count, s"${group.name}_count")
      attachU64(s"${group.name}_count64", group.count64)
      attachRO(group.streak, s"${group.name}_streak")
      attachRO(group.maxStreak, s"${group.name}_max_streak")
      attachMask(s"live_${group.name}", group.live)
      attachMask(s"first_${group.name}", group.first)
      attachMask(s"last_${group.name}", group.last)
      group.bitCounts.zipWithIndex.foreach { case (counter, idx) =>
        attachRO(counter, s"${group.name}_bit_count_${idx}")
      }
    }

    genCRFile()

    override def genHeader(base: BigInt, memoryRegions: Map[String, BigInt], sb: StringBuilder): Unit = {
      genConstructor(
        base,
        sb,
        "target_cycle_debug_t",
        "target_cycle_debug",
        Seq(
          StdVector("const char *", params.hportLabels.map(CStrLit(_))),
          StdVector("const char *", params.wireInputLabels.map(CStrLit(_))),
          StdVector("const char *", params.wireOutputLabels.map(CStrLit(_))),
          StdVector("const char *", params.rvInputLabels.map(CStrLit(_))),
          StdVector("const char *", params.rvOutputLabels.map(CStrLit(_))),
          UInt32(MaskChunks),
        ),
        hasMMIOAddrMap = true,
      )
    }

    private def groupLabels(name: String): Seq[String] = name match {
      case "hport_to_host_blocked" | "hport_from_host_blocked" => params.hportLabels
      case "wire_input_missing_valid" | "wire_input_backpressured" => params.wireInputLabels
      case "wire_output_blocked" => params.wireOutputLabels
      case "rv_input_fwd_missing_valid" | "rv_input_fwd_backpressured" | "rv_input_rev_backpressured" =>
        params.rvInputLabels
      case "rv_output_fwd_blocked" | "rv_output_rev_missing_valid" | "rv_output_rev_backpressured" =>
        params.rvOutputLabels
      case _ => Seq.empty
    }
  }
}
