#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#include <string>

#define NUM_TOKENS 14
#define BUFSIZE_BYTES 128

uint64_t get_flit(uint8_t *, int) { return 0; }
int is_valid_flit(uint8_t *, int) { return 0; }
int is_last_flit(uint8_t *, int) { return 0; }
void write_flit(uint8_t *, int, uint64_t) {}
void write_valid_flit(uint8_t *, int) {}
void write_last_flit(uint8_t *, int, int) {}

class BasePort {
public:
  BasePort(int portNo, bool) : _portNo(portNo) {}
  virtual void tick() = 0;
  virtual void tick_pre() = 0;
  virtual void send() = 0;
  virtual void recv() = 0;

  uint8_t *current_input_buf = nullptr;
  uint8_t *current_output_buf = nullptr;

protected:
  int _portNo;
};

#include "../shmemport.h"

static constexpr uint64_t kEmptyMarker = 0xDEADBEEFDEADBEEFULL;

static void require(bool cond, const char *msg) {
  if (!cond) {
    fprintf(stderr, "FAIL: %s\n", msg);
    exit(1);
  }
}

static void unlink_port_regions(const std::string &name) {
  for (int idx = 0; idx < 2; idx++) {
    std::string nts = "/port_nts" + name + "_" + std::to_string(idx);
    std::string stn = "/port_stn" + name + "_" + std::to_string(idx);
    shm_unlink(nts.c_str());
    shm_unlink(stn.c_str());
  }
}

int main() {
  const std::string region_name =
      "shmem_marker_test_" + std::to_string(getpid());
  unlink_port_regions(region_name);

  char mutable_name[128];
  snprintf(mutable_name, sizeof(mutable_name), "%s", region_name.c_str());
  ShmemPort port(0, mutable_name, false);

  auto *header = reinterpret_cast<uint64_t *>(port.current_output_buf);
  header[0] = kEmptyMarker;
  port.current_output_buf[BUFSIZE_BYTES] = 0;
  port.send();
  require(header[0] == 0, "empty marker header is cleared before send");
  require(port.current_output_buf[BUFSIZE_BYTES] == 1,
          "send publishes poll byte for marker round");

  port.tick_pre();
  header = reinterpret_cast<uint64_t *>(port.current_output_buf);
  header[0] = 0x0123456789abcdefULL;
  port.current_output_buf[BUFSIZE_BYTES] = 0;
  port.send();
  require(header[0] == 0x0123456789abcdefULL,
          "non-marker header is preserved");
  require(port.current_output_buf[BUFSIZE_BYTES] == 1,
          "send publishes poll byte for non-marker round");

  port.current_input_buf[BUFSIZE_BYTES] = 1;
  port.tick();
  require(port.current_input_buf[BUFSIZE_BYTES] == 0,
          "tick clears consumed input poll byte");

  unlink_port_regions(region_name);
  printf("PASS shmemport_marker_test\n");
  return 0;
}
