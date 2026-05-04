#include "cpu_managed_stream.h"
#include "core/simif.h"

#include <cassert>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>

using namespace CPUManagedStreams;

namespace {

uint64_t push_blocked_events = 0;
uint64_t pull_blocked_events = 0;
bool stream_debug_enabled = false;

bool parse_bool_arg(const std::string &arg,
                    const char *prefix,
                    bool *value) {
  const size_t prefix_len = std::strlen(prefix);
  if (arg.rfind(prefix, 0) != 0) {
    return false;
  }
  if (arg.size() == prefix_len) {
    *value = true;
    return true;
  }
  if (arg[prefix_len] != '=') {
    return false;
  }
  *value = std::atoi(arg.c_str() + prefix_len + 1) != 0;
  return true;
}

bool should_log_blocked_event(uint64_t count) {
  return count <= 4 || ((count & (count - 1)) == 0);
}

void log_push_blocked(CPUManagedStreams::CPUToFPGADriver &driver,
                      size_t requested_bytes,
                      size_t required_bytes,
                      size_t count,
                      size_t space_available,
                      size_t num_beats,
                      size_t threshold_beats,
                      uint64_t event_count) {
  printf("CPU_STREAM DEBUG push_blocked event=%llu "
         "stream=%s count_addr=0x%lx dma_addr=0x%lx "
         "count=%lu fpga_buffer_size=%u space_available=%lu "
         "requested_bytes=%lu required_bytes=%lu requested_beats=%lu threshold_beats=%lu "
         "beat_bytes=%lu\n",
         static_cast<unsigned long long>(event_count),
         driver.stream_name().c_str(),
         driver.count_addr(),
         driver.dma_addr(),
         count,
         driver.fpga_buffer_size(),
         space_available,
         requested_bytes,
         required_bytes,
         num_beats,
         threshold_beats,
         driver.fpga_buffer_width_bytes());
}

void log_pull_blocked(CPUManagedStreams::FPGAToCPUDriver &driver,
                      size_t requested_bytes,
                      size_t required_bytes,
                      size_t count,
                      size_t num_beats,
                      size_t threshold_beats,
                      uint64_t event_count) {
  printf("CPU_STREAM DEBUG pull_blocked event=%llu "
         "stream=%s count_addr=0x%lx dma_addr=0x%lx "
         "count=%lu fpga_buffer_size=%u "
         "requested_bytes=%lu required_bytes=%lu requested_beats=%lu threshold_beats=%lu "
         "beat_bytes=%lu\n",
         static_cast<unsigned long long>(event_count),
         driver.stream_name().c_str(),
         driver.count_addr(),
         driver.dma_addr(),
         count,
         driver.fpga_buffer_size(),
         requested_bytes,
         required_bytes,
         num_beats,
         threshold_beats,
         driver.fpga_buffer_width_bytes());
}

} // namespace

/**
 * @brief Enqueues as much as num_bytes of data into the associated stream
 *
 * @param src Source from which to copy data to enqueue
 * @param num_bytes Desired number of bytes to enqueue
 * @param required_bytes Minimum number of bytes to enqueue. If fewer bytes
 *        would be enqueued, this method enqueues none and returns 0.
 * @return size_t
 */
size_t CPUManagedStreams::CPUToFPGADriver::push(void *src,
                                                size_t num_bytes,
                                                size_t required_bytes) {

  assert(num_bytes >= required_bytes);

  // Similarly to above, the legacy implementation of DMA does not correctly
  // implement non-multiples of 512b. The FPGA-side queue will take on the
  // high-order bytes of the final beat in the transaction, and the strobe is
  // not respected. So put the assertion here and discuss what to do next.
  assert((num_bytes % fpga_buffer_width_bytes()) == 0);

  auto num_beats = num_bytes / fpga_buffer_width_bytes();
  auto threshold_beats = required_bytes / fpga_buffer_width_bytes();

  assert(threshold_beats <= fpga_buffer_size());
  auto count = mmio_read(count_addr());
  auto space_available = fpga_buffer_size() - count;

  if ((space_available == 0) || (space_available < threshold_beats)) {
    push_blocked_events++;
    if (stream_debug_enabled && should_log_blocked_event(push_blocked_events)) {
      log_push_blocked(*this,
                       num_bytes,
                       required_bytes,
                       count,
                       space_available,
                       num_beats,
                       threshold_beats,
                       push_blocked_events);
    }
    return 0;
  }

  auto push_beats = std::min(space_available, num_beats);
  auto push_bytes = push_beats * fpga_buffer_width_bytes();
  auto bytes_written =
      cpu_managed_axi4_write(dma_addr(), (char *)src, push_bytes);
  assert(bytes_written == push_bytes);

  return bytes_written;
}

/**
 * @brief Dequeues as much as num_bytes of data from the associated bridge
 * stream.
 *
 * @param dest  Buffer into which to copy dequeued stream data
 * @param num_bytes  Bytes of data to dequeue
 * @param required_bytes  Minimum number of bytes to dequeue. If fewer bytes
 * would be dequeued, dequeue none and return 0.
 * @return size_t Number of bytes successfully dequeued
 */
size_t CPUManagedStreams::FPGAToCPUDriver::pull(void *dest,
                                                size_t num_bytes,
                                                size_t required_bytes) {
  assert(num_bytes >= required_bytes);

  // The legacy code is clearly broken for requests that aren't a
  // multiple of 512b since CPU_MANAGED_AXI4_SIZE is fixed to the full width of
  // the AXI4 IF. The high-order bytes of the final word will be copied into the
  // destination buffer (potentially an overflow, bug 1), and since reads are
  // destructive, will not be visible to future pulls (bug 2). So i've put this
  // assertion here for now...

  // Due to the destructive nature of reads, if we wish to support reads that
  // aren't a multiple of 512b, we'll need to keep a little buffer around for
  // the remainder, and prepend this to the destination buffer.
  assert((num_bytes % fpga_buffer_width_bytes()) == 0);

  auto num_beats = num_bytes / fpga_buffer_width_bytes();
  auto threshold_beats = required_bytes / fpga_buffer_width_bytes();

  assert(threshold_beats <= fpga_buffer_size());
  auto count = mmio_read(count_addr());

  if ((count == 0) || (count < threshold_beats)) {
    pull_blocked_events++;
    if (stream_debug_enabled && should_log_blocked_event(pull_blocked_events)) {
      log_pull_blocked(*this,
                       num_bytes,
                       required_bytes,
                       count,
                       num_beats,
                       threshold_beats,
                       pull_blocked_events);
    }
    return 0;
  }

  auto pull_beats = std::min(count, num_beats);
  auto pull_bytes = pull_beats * fpga_buffer_width_bytes();
  auto bytes_read = cpu_managed_axi4_read(dma_addr(), (char *)dest, pull_bytes);
  assert(bytes_read == pull_bytes);
  return bytes_read;
}

CPUManagedStreamWidget::CPUManagedStreamWidget(
    simif_t &simif,
    unsigned index,
    const std::vector<std::string> &args,
    std::vector<CPUManagedStreams::StreamParameters> &&from_cpu,
    std::vector<CPUManagedStreams::StreamParameters> &&to_cpu) {
  assert(index == 0 && "only one managed stream engine is allowed");

  for (const auto &arg : args) {
    parse_bool_arg(arg, "+cpu-managed-stream-debug", &stream_debug_enabled);
  }

  auto &io = simif.get_cpu_managed_stream_io();
  for (auto &&params : from_cpu) {
    cpu_to_fpga_streams.push_back(
        std::make_unique<CPUManagedStreams::CPUToFPGADriver>(std::move(params),
                                                             io));
  }

  for (auto &&params : to_cpu) {
    fpga_to_cpu_streams.push_back(
        std::make_unique<CPUManagedStreams::FPGAToCPUDriver>(std::move(params),
                                                             io));
  }
}
