// See LICENSE for license details.

#include "clock.h"
#include "core/simif.h"

char clockmodule_t::KIND;

clockmodule_t::clockmodule_t(simif_t &simif,
                             const CLOCKBRIDGEMODULE_struct &mmio_addrs,
                             unsigned index,
                             const std::vector<std::string> &args)
    : widget_t(simif, &KIND), mmio_addrs(mmio_addrs) {
  assert(index == 0 && "only one clock bridge is allowed");
}

uint64_t clockmodule_t::read_u64(uint64_t lo_addr,
                                 uint64_t hi_addr,
                                 uint64_t latch_addr) {
  simif.write(latch_addr, 1);
  uint32_t value_l = simif.read(lo_addr);
  uint32_t value_h = simif.read(hi_addr);
  return (((uint64_t)value_h) << 32) | value_l;
}

uint64_t clockmodule_t::tcycle() {
  return read_u64(mmio_addrs.tCycle_0,
                  mmio_addrs.tCycle_1,
                  mmio_addrs.tCycle_latch);
}

uint64_t clockmodule_t::hcycle() {
  return read_u64(mmio_addrs.hCycle_0,
                  mmio_addrs.hCycle_1,
                  mmio_addrs.hCycle_latch);
}

uint32_t clockmodule_t::read_debug_word(unsigned word_index) {
  return simif.read(mmio_addrs.tCycle_latch + ((word_index + 1) * sizeof(uint32_t)));
}

uint32_t clockmodule_t::debug_status() { return read_debug_word(0); }

uint32_t clockmodule_t::debug_token_fire_count() {
  return read_debug_word(1);
}

uint32_t clockmodule_t::debug_token_bits_lo() { return read_debug_word(2); }

uint32_t clockmodule_t::debug_num_clocks() { return read_debug_word(3); }
