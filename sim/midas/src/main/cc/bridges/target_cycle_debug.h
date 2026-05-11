#ifndef __TARGET_CYCLE_DEBUG_H
#define __TARGET_CYCLE_DEBUG_H

#include "core/address_map.h"
#include "core/bridge_driver.h"

#include <cstdint>
#include <string>
#include <utility>
#include <vector>

class target_cycle_debug_t final : public bridge_driver_t {
public:
  static char KIND;

  target_cycle_debug_t(simif_t &sim,
                       AddressMap &&addr_map,
                       unsigned widgetno,
                       const std::vector<std::string> &args,
                       const std::vector<const char *> &hport_labels,
                       const std::vector<const char *> &wire_input_labels,
                       const std::vector<const char *> &wire_output_labels,
                       const std::vector<const char *> &rv_input_labels,
                       const std::vector<const char *> &rv_output_labels,
                       uint32_t mask_chunks);

  void init() override;
  void tick() override;
  void finish() override;

private:
  const AddressMap addr_map;
  const unsigned widgetno;
  const uint32_t mask_chunks;

  bool enabled = false;
  bool print_labels = true;
  uint32_t dump_limit = 8;
  uint32_t dumps = 0;
  uint32_t last_trigger_count = 0;
  bool dumped_finish = false;

  std::vector<std::string> hport_labels;
  std::vector<std::string> wire_input_labels;
  std::vector<std::string> wire_output_labels;
  std::vector<std::string> rv_input_labels;
  std::vector<std::string> rv_output_labels;

  uint32_t read_reg(const std::string &name);
  uint64_t read_u64(const std::string &lo_name, const std::string &hi_name);
  std::vector<uint32_t> read_mask(const std::string &prefix);
  bool bit(const std::vector<uint32_t> &mask, size_t idx) const;
  std::vector<std::pair<std::string, const std::vector<std::string> *>>
  blocker_groups() const;

  void dump(const char *context);
  void dump_snapshot(const char *snapshot);
  void dump_mask_hex(const char *name, const std::vector<uint32_t> &mask);
  void dump_blocker_stats();
  void dump_blocker_snapshot(const char *snapshot);
  void dump_blocker_group_snapshot(const char *snapshot,
                                   const std::string &name,
                                   const std::vector<std::string> &labels);
  void dump_hports(const char *snapshot);
  void dump_pipe_group(const char *snapshot,
                       const char *group,
                       const std::vector<std::string> &labels,
                       const std::vector<uint32_t> &valid,
                       const std::vector<uint32_t> &ready);
  void dump_rv_group(const char *snapshot,
                     const char *group,
                     const std::vector<std::string> &labels,
                     const std::vector<uint32_t> &fwd_valid,
                     const std::vector<uint32_t> &fwd_ready,
                     const std::vector<uint32_t> &rev_valid,
                     const std::vector<uint32_t> &rev_ready);
};

#endif // __TARGET_CYCLE_DEBUG_H
