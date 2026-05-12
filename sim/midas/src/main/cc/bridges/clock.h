// See LICENSE for license details.

#ifndef __CLOCK_H
#define __CLOCK_H

#include "core/widget.h"

#include <cstdint>
#include <string>
#include <vector>

class simif_t;

struct CLOCKBRIDGEMODULE_struct {
  uint64_t hCycle_0;
  uint64_t hCycle_1;
  uint64_t hCycle_latch;
  uint64_t tCycle_0;
  uint64_t tCycle_1;
  uint64_t tCycle_latch;
};

class clockmodule_t final : public widget_t {
public:
  /// The identifier for the bridge type.
  static char KIND;

  clockmodule_t(simif_t &simif,
                const CLOCKBRIDGEMODULE_struct &mmio_addrs,
                unsigned index,
                const std::vector<std::string> &args);

  /**
   * Provides the current target cycle of the fastest clock.
   *
   * The target cycle is based on the number of clock tokens enqueued
   * (will report a larger number).
   */
  uint64_t tcycle();

  /**
   * Returns the current host cycle as measured by a hardware counter
   */
  uint64_t hcycle();

  uint32_t debug_status();
  uint32_t debug_token_fire_count();
  uint32_t debug_token_bits_lo();
  uint32_t debug_num_clocks();

private:
  const CLOCKBRIDGEMODULE_struct mmio_addrs;

  uint64_t read_u64(uint64_t lo_addr, uint64_t hi_addr, uint64_t latch_addr);
  uint32_t read_debug_word(unsigned word_index);
};

#endif // __CLOCK_H
