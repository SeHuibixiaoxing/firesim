#include "target_cycle_debug.h"

#include <cstdio>
#include <cstdlib>
#include <utility>

char target_cycle_debug_t::KIND;

static std::vector<std::string>
copy_labels(const std::vector<const char *> &labels) {
  std::vector<std::string> out;
  out.reserve(labels.size());
  for (auto *label : labels) {
    out.emplace_back(label ? label : "");
  }
  return out;
}

target_cycle_debug_t::target_cycle_debug_t(
    simif_t &sim,
    AddressMap &&addr_map,
    unsigned widgetno,
    const std::vector<std::string> &args,
    const std::vector<const char *> &hport_labels,
    const std::vector<const char *> &wire_input_labels,
    const std::vector<const char *> &wire_output_labels,
    const std::vector<const char *> &rv_input_labels,
    const std::vector<const char *> &rv_output_labels,
    uint32_t mask_chunks)
    : bridge_driver_t(sim, &KIND), addr_map(std::move(addr_map)),
      widgetno(widgetno), mask_chunks(mask_chunks),
      hport_labels(copy_labels(hport_labels)),
      wire_input_labels(copy_labels(wire_input_labels)),
      wire_output_labels(copy_labels(wire_output_labels)),
      rv_input_labels(copy_labels(rv_input_labels)),
      rv_output_labels(copy_labels(rv_output_labels)) {
  const std::string indexed_enable =
      std::string("+targetcycle-debug") + std::to_string(widgetno) + "=";
  const std::string global_enable = "+targetcycle-debug=";
  const std::string indexed_flag =
      std::string("+targetcycle-debug") + std::to_string(widgetno);
  const std::string global_flag = "+targetcycle-debug";
  const std::string indexed_limit =
      std::string("+targetcycle-debug-limit") + std::to_string(widgetno) + "=";
  const std::string global_limit = "+targetcycle-debug-limit=";
  const std::string indexed_labels =
      std::string("+targetcycle-debug-labels") + std::to_string(widgetno) + "=";
  const std::string global_labels = "+targetcycle-debug-labels=";

  for (const auto &arg : args) {
    if (arg == indexed_flag || arg == global_flag) {
      enabled = true;
    }
    if (arg.find(indexed_enable) == 0) {
      enabled = std::atoi(arg.c_str() + indexed_enable.size()) != 0;
    }
    if (arg.find(global_enable) == 0) {
      enabled = std::atoi(arg.c_str() + global_enable.size()) != 0;
    }
    if (arg.find(indexed_limit) == 0) {
      dump_limit = std::atoi(arg.c_str() + indexed_limit.size());
    }
    if (arg.find(global_limit) == 0) {
      dump_limit = std::atoi(arg.c_str() + global_limit.size());
    }
    if (arg.find(indexed_labels) == 0) {
      print_labels = std::atoi(arg.c_str() + indexed_labels.size()) != 0;
    }
    if (arg.find(global_labels) == 0) {
      print_labels = std::atoi(arg.c_str() + global_labels.size()) != 0;
    }
  }

  if (enabled) {
    printf("TARGETCYCLE DEBUG enabled widget=%u dump_limit=%u mask_chunks=%u "
           "labels hport=%zu wire_in=%zu wire_out=%zu rv_in=%zu rv_out=%zu\n",
           widgetno,
           dump_limit,
           mask_chunks,
           this->hport_labels.size(),
           this->wire_input_labels.size(),
           this->wire_output_labels.size(),
           this->rv_input_labels.size(),
           this->rv_output_labels.size());
    fflush(stdout);
  }
}

void target_cycle_debug_t::init() {
  if (!enabled) {
    return;
  }
  last_trigger_count = read_reg("trigger_count");
}

void target_cycle_debug_t::tick() {
  if (!enabled || dumps >= dump_limit) {
    return;
  }

  const auto trigger_live = read_reg("trigger_live");
  const auto trigger_count = read_reg("trigger_count");
  if (trigger_live || trigger_count != last_trigger_count) {
    dump("tick");
    dumps++;
  }
  last_trigger_count = trigger_count;
}

void target_cycle_debug_t::finish() {
  if (!enabled || dumped_finish) {
    return;
  }

  const auto trigger_count = read_reg("trigger_count");
  const auto first_valid = read_reg("first_valid");
  if (first_valid || trigger_count != last_trigger_count) {
    dump("finish");
    dumped_finish = true;
  }
}

uint32_t target_cycle_debug_t::read_reg(const std::string &name) {
  return read(addr_map.r_addr(name));
}

uint64_t target_cycle_debug_t::read_u64(const std::string &lo_name,
                                        const std::string &hi_name) {
  const uint64_t lo = read_reg(lo_name);
  const uint64_t hi = read_reg(hi_name);
  return (hi << 32) | lo;
}

std::vector<uint32_t>
target_cycle_debug_t::read_mask(const std::string &prefix) {
  std::vector<uint32_t> chunks;
  chunks.reserve(mask_chunks);
  for (uint32_t i = 0; i < mask_chunks; i++) {
    chunks.push_back(read_reg(prefix + "_" + std::to_string(i)));
  }
  return chunks;
}

bool target_cycle_debug_t::bit(const std::vector<uint32_t> &mask,
                               size_t idx) const {
  const size_t chunk = idx / 32;
  const size_t offset = idx % 32;
  if (chunk >= mask.size()) {
    return false;
  }
  return ((mask[chunk] >> offset) & 1u) != 0;
}

std::vector<std::pair<std::string, const std::vector<std::string> *>>
target_cycle_debug_t::blocker_groups() const {
  return {
      {"hport_to_host_blocked", &hport_labels},
      {"hport_from_host_blocked", &hport_labels},
      {"wire_input_missing_valid", &wire_input_labels},
      {"wire_input_backpressured", &wire_input_labels},
      {"wire_output_blocked", &wire_output_labels},
      {"rv_input_fwd_missing_valid", &rv_input_labels},
      {"rv_input_fwd_backpressured", &rv_input_labels},
      {"rv_input_rev_backpressured", &rv_input_labels},
      {"rv_output_fwd_blocked", &rv_output_labels},
      {"rv_output_rev_missing_valid", &rv_output_labels},
      {"rv_output_rev_backpressured", &rv_output_labels},
  };
}

void target_cycle_debug_t::dump_mask_hex(
    const char *name, const std::vector<uint32_t> &mask) {
  printf("TARGETCYCLE DEBUG MASK %s=0x", name);
  for (auto it = mask.rbegin(); it != mask.rend(); ++it) {
    printf("%08x", *it);
  }
  printf("\n");
}

void target_cycle_debug_t::dump_blocker_stats() {
  for (const auto &group : blocker_groups()) {
    const auto &name = group.first;
    const auto &labels = *group.second;
    const auto first_valid = read_reg(name + "_first_valid");
    const auto count = read_reg(name + "_count");
    const auto count64 = read_u64(name + "_count64_lo",
                                  name + "_count64_hi");
    const auto streak = read_reg(name + "_streak");
    const auto max_streak = read_reg(name + "_max_streak");
    printf("TARGETCYCLE DEBUG BLOCKER_STATS group=%s first_valid=%u "
           "cycles=%u cycles64=%llu streak=%u max_streak=%u\n",
           name.c_str(),
           first_valid,
           count,
           static_cast<unsigned long long>(count64),
           streak,
           max_streak);

    if (!print_labels) {
      continue;
    }
    for (size_t i = 0; i < labels.size(); i++) {
      const auto bit_count =
          read_reg(name + "_bit_count_" + std::to_string(i));
      if (bit_count == 0) {
        continue;
      }
      printf("TARGETCYCLE DEBUG BLOCKER_COUNT group=%s[%zu] cycles=%u %s\n",
             name.c_str(),
             i,
             bit_count,
             labels[i].c_str());
    }
  }
}

void target_cycle_debug_t::dump_blocker_group_snapshot(
    const char *snapshot,
    const std::string &name,
    const std::vector<std::string> &labels) {
  const std::string prefix = std::string(snapshot) + "_";
  const auto mask = read_mask(prefix + name);
  dump_mask_hex((prefix + name).c_str(), mask);

  if (!print_labels) {
    return;
  }
  for (size_t i = 0; i < labels.size(); i++) {
    if (!bit(mask, i)) {
      continue;
    }
    printf("TARGETCYCLE DEBUG BLOCKER [%s] %s[%zu] %s\n",
           snapshot,
           name.c_str(),
           i,
           labels[i].c_str());
  }
}

void target_cycle_debug_t::dump_blocker_snapshot(const char *snapshot) {
  for (const auto &group : blocker_groups()) {
    dump_blocker_group_snapshot(snapshot, group.first, *group.second);
  }
}

void target_cycle_debug_t::dump_hports(const char *snapshot) {
  const std::string prefix = std::string(snapshot) + "_";
  const auto to_host_valid = read_mask(prefix + "hport_to_host_valid");
  const auto to_host_ready = read_mask(prefix + "hport_to_host_ready");
  const auto from_host_valid = read_mask(prefix + "hport_from_host_valid");
  const auto from_host_ready = read_mask(prefix + "hport_from_host_ready");

  dump_mask_hex((prefix + "hport_to_host_valid").c_str(), to_host_valid);
  dump_mask_hex((prefix + "hport_to_host_ready").c_str(), to_host_ready);
  dump_mask_hex((prefix + "hport_from_host_valid").c_str(), from_host_valid);
  dump_mask_hex((prefix + "hport_from_host_ready").c_str(), from_host_ready);

  if (!print_labels) {
    return;
  }

  for (size_t i = 0; i < hport_labels.size(); i++) {
    printf("TARGETCYCLE DEBUG HPORT [%s] [%zu] to(v=%u r=%u) "
           "from(v=%u r=%u) %s\n",
           snapshot,
           i,
           bit(to_host_valid, i) ? 1 : 0,
           bit(to_host_ready, i) ? 1 : 0,
           bit(from_host_valid, i) ? 1 : 0,
           bit(from_host_ready, i) ? 1 : 0,
           hport_labels[i].c_str());
  }
}

void target_cycle_debug_t::dump_pipe_group(
    const char *snapshot,
    const char *group,
    const std::vector<std::string> &labels,
    const std::vector<uint32_t> &valid,
    const std::vector<uint32_t> &ready) {
  if (!print_labels) {
    return;
  }
  for (size_t i = 0; i < labels.size(); i++) {
    printf("TARGETCYCLE DEBUG CHANNEL [%s] %s[%zu] v=%u r=%u %s\n",
           snapshot,
           group,
           i,
           bit(valid, i) ? 1 : 0,
           bit(ready, i) ? 1 : 0,
           labels[i].c_str());
  }
}

void target_cycle_debug_t::dump_rv_group(
    const char *snapshot,
    const char *group,
    const std::vector<std::string> &labels,
    const std::vector<uint32_t> &fwd_valid,
    const std::vector<uint32_t> &fwd_ready,
    const std::vector<uint32_t> &rev_valid,
    const std::vector<uint32_t> &rev_ready) {
  if (!print_labels) {
    return;
  }
  for (size_t i = 0; i < labels.size(); i++) {
    printf("TARGETCYCLE DEBUG RV [%s] %s[%zu] fwd(v=%u r=%u) "
           "rev(v=%u r=%u) %s\n",
           snapshot,
           group,
           i,
           bit(fwd_valid, i) ? 1 : 0,
           bit(fwd_ready, i) ? 1 : 0,
           bit(rev_valid, i) ? 1 : 0,
           bit(rev_ready, i) ? 1 : 0,
           labels[i].c_str());
  }
}

void target_cycle_debug_t::dump_snapshot(const char *snapshot) {
  const std::string prefix = std::string(snapshot) + "_";

  dump_hports(snapshot);

  const auto wire_input_valid = read_mask(prefix + "wire_input_valid");
  const auto wire_input_ready = read_mask(prefix + "wire_input_ready");
  const auto wire_output_valid = read_mask(prefix + "wire_output_valid");
  const auto wire_output_ready = read_mask(prefix + "wire_output_ready");
  const auto rv_input_fwd_valid = read_mask(prefix + "rv_input_fwd_valid");
  const auto rv_input_fwd_ready = read_mask(prefix + "rv_input_fwd_ready");
  const auto rv_input_rev_valid = read_mask(prefix + "rv_input_rev_valid");
  const auto rv_input_rev_ready = read_mask(prefix + "rv_input_rev_ready");
  const auto rv_output_fwd_valid = read_mask(prefix + "rv_output_fwd_valid");
  const auto rv_output_fwd_ready = read_mask(prefix + "rv_output_fwd_ready");
  const auto rv_output_rev_valid = read_mask(prefix + "rv_output_rev_valid");
  const auto rv_output_rev_ready = read_mask(prefix + "rv_output_rev_ready");

  dump_mask_hex((prefix + "wire_input_valid").c_str(), wire_input_valid);
  dump_mask_hex((prefix + "wire_input_ready").c_str(), wire_input_ready);
  dump_mask_hex((prefix + "wire_output_valid").c_str(), wire_output_valid);
  dump_mask_hex((prefix + "wire_output_ready").c_str(), wire_output_ready);
  dump_mask_hex((prefix + "rv_input_fwd_valid").c_str(), rv_input_fwd_valid);
  dump_mask_hex((prefix + "rv_input_fwd_ready").c_str(), rv_input_fwd_ready);
  dump_mask_hex((prefix + "rv_input_rev_valid").c_str(), rv_input_rev_valid);
  dump_mask_hex((prefix + "rv_input_rev_ready").c_str(), rv_input_rev_ready);
  dump_mask_hex((prefix + "rv_output_fwd_valid").c_str(), rv_output_fwd_valid);
  dump_mask_hex((prefix + "rv_output_fwd_ready").c_str(), rv_output_fwd_ready);
  dump_mask_hex((prefix + "rv_output_rev_valid").c_str(), rv_output_rev_valid);
  dump_mask_hex((prefix + "rv_output_rev_ready").c_str(), rv_output_rev_ready);
  dump_blocker_snapshot(snapshot);

  dump_pipe_group(snapshot,
                  "wire_input",
                  wire_input_labels,
                  wire_input_valid,
                  wire_input_ready);
  dump_pipe_group(snapshot,
                  "wire_output",
                  wire_output_labels,
                  wire_output_valid,
                  wire_output_ready);
  dump_rv_group(snapshot,
                "rv_input",
                rv_input_labels,
                rv_input_fwd_valid,
                rv_input_fwd_ready,
                rv_input_rev_valid,
                rv_input_rev_ready);
  dump_rv_group(snapshot,
                "rv_output",
                rv_output_labels,
                rv_output_fwd_valid,
                rv_output_fwd_ready,
                rv_output_rev_valid,
                rv_output_rev_ready);
}

void target_cycle_debug_t::dump(const char *context) {
  const auto hcycle = read_u64("hcycle_lo", "hcycle_hi");
  const auto first_cycle =
      read_u64("first_trigger_cycle_lo", "first_trigger_cycle_hi");
  const auto last_cycle =
      read_u64("last_trigger_cycle_lo", "last_trigger_cycle_hi");

  printf("TARGETCYCLE DEBUG [%s] widget=%u hcycle=%llu trigger_live=%u "
         "raw_trigger_live=%u problem_live=%u trigger_count=%u "
         "problem_count=%u clean_count=%u trigger_count64=%llu "
         "problem_count64=%llu clean_count64=%llu problem_streak=%u "
         "problem_max_streak=%u clean_streak=%u clean_max_streak=%u "
         "first_valid=%u first_cycle=%llu last_cycle=%llu "
         "counts hport=%u wire_in=%u wire_out=%u rv_in=%u rv_out=%u "
         "dumps=%u/%u\n",
         context,
         widgetno,
         static_cast<unsigned long long>(hcycle),
         read_reg("trigger_live"),
         read_reg("raw_trigger_live"),
         read_reg("problem_live"),
         read_reg("trigger_count"),
         read_reg("problem_count"),
         read_reg("clean_count"),
         static_cast<unsigned long long>(
             read_u64("trigger_count64_lo", "trigger_count64_hi")),
         static_cast<unsigned long long>(
             read_u64("problem_count64_lo", "problem_count64_hi")),
         static_cast<unsigned long long>(
             read_u64("clean_count64_lo", "clean_count64_hi")),
         read_reg("problem_streak"),
         read_reg("problem_max_streak"),
         read_reg("clean_streak"),
         read_reg("clean_max_streak"),
         read_reg("first_valid"),
         static_cast<unsigned long long>(first_cycle),
         static_cast<unsigned long long>(last_cycle),
         read_reg("hport_count"),
         read_reg("wire_input_count"),
         read_reg("wire_output_count"),
         read_reg("rv_input_count"),
         read_reg("rv_output_count"),
         dumps,
         dump_limit);

  dump_blocker_stats();
  dump_snapshot("live");
  dump_snapshot("first");
  dump_snapshot("last");
  fflush(stdout);
}
