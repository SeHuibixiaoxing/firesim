#include <arpa/inet.h>
#include <fcntl.h>
#include <queue>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <unistd.h>
#include <vector>

#define NUM_TOKENS 14
#define TOKENS_PER_BIGTOKEN 7
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

#include "../sshport.h"

static void put_be16(unsigned char *p, uint16_t v) {
  p[0] = static_cast<unsigned char>(v >> 8);
  p[1] = static_cast<unsigned char>(v & 0xff);
}

static void put_be32(unsigned char *p, uint32_t v) {
  p[0] = static_cast<unsigned char>(v >> 24);
  p[1] = static_cast<unsigned char>((v >> 16) & 0xff);
  p[2] = static_cast<unsigned char>((v >> 8) & 0xff);
  p[3] = static_cast<unsigned char>(v & 0xff);
}

static bool ipv4_checksum_valid(const std::vector<unsigned char> &frame) {
  const unsigned char *ip = frame.data() + 14;
  return switch_ipv4_header_checksum(ip, (ip[0] & 0x0f) * 4) == 0;
}

static bool tcp_checksum_valid(const std::vector<unsigned char> &frame) {
  const unsigned char *ip = frame.data() + 14;
  const int ihl_bytes = (ip[0] & 0x0f) * 4;
  const int total_len = switch_read_be16(ip + 2);
  const unsigned char *tcp = ip + ihl_bytes;
  return switch_tcp_checksum(ip, tcp, total_len - ihl_bytes) == 0;
}

static std::vector<unsigned char> make_ipv4_tcp_frame(uint16_t src_port,
                                                      uint16_t dst_port,
                                                      const char *payload) {
  const size_t payload_len = strlen(payload);
  const size_t ip_len = 20 + 20 + payload_len;
  std::vector<unsigned char> frame(14 + ip_len, 0);

  unsigned char *eth = frame.data();
  const unsigned char dst_mac[6] = {0x02, 0x00, 0x00, 0x00, 0x00, 0x01};
  const unsigned char src_mac[6] = {0x02, 0x00, 0x00, 0x00, 0x00, 0x02};
  memcpy(eth + 0, dst_mac, sizeof(dst_mac));
  memcpy(eth + 6, src_mac, sizeof(src_mac));
  put_be16(eth + 12, 0x0800);

  unsigned char *ip = eth + 14;
  ip[0] = 0x45;
  ip[1] = 0x00;
  put_be16(ip + 2, static_cast<uint16_t>(ip_len));
  put_be16(ip + 4, 0x1234);
  put_be16(ip + 6, 0x4000);
  ip[8] = 64;
  ip[9] = 6;
  put_be32(ip + 12, 0xac100002);
  put_be32(ip + 16, 0xac100001);

  unsigned char *tcp = ip + 20;
  put_be16(tcp + 0, src_port);
  put_be16(tcp + 2, dst_port);
  put_be32(tcp + 4, 0x01020304);
  put_be32(tcp + 8, 0x05060708);
  tcp[12] = 0x50;
  tcp[13] = 0x18;
  put_be16(tcp + 14, 0x2000);
  memcpy(tcp + 20, payload, payload_len);

  put_be16(ip + 10, switch_ipv4_header_checksum(ip, 20));
  put_be16(tcp + 16, switch_tcp_checksum(ip, tcp, static_cast<int>(20 + payload_len)));
  return frame;
}

static std::vector<unsigned char> make_arp_frame_with_bad_sender_hwaddr() {
  std::vector<unsigned char> frame(42, 0);
  unsigned char *eth = frame.data();
  const unsigned char dst_mac[6] = {0xff, 0xff, 0xff, 0xff, 0xff, 0xff};
  const unsigned char src_mac[6] = {0x02, 0x00, 0x00, 0x00, 0x23, 0x45};
  const unsigned char bad_sha[6] = {0, 0, 0, 0, 0, 0};
  memcpy(eth + 0, dst_mac, sizeof(dst_mac));
  memcpy(eth + 6, src_mac, sizeof(src_mac));
  put_be16(eth + 12, 0x0806);

  unsigned char *arp = eth + 14;
  put_be16(arp + 0, 1);
  put_be16(arp + 2, 0x0800);
  arp[4] = 6;
  arp[5] = 4;
  put_be16(arp + 6, 1);
  memcpy(arp + 8, bad_sha, sizeof(bad_sha));
  put_be32(arp + 14, 0xac100002);
  put_be32(arp + 24, 0xac100001);
  return frame;
}

static void require(bool cond, const char *msg) {
  if (!cond) {
    fprintf(stderr, "FAIL: %s\n", msg);
    exit(1);
  }
}

int main() {
  {
    std::vector<unsigned char> frame =
        make_arp_frame_with_bad_sender_hwaddr();
    const int repaired = repair_host_tap_egress(frame.data(), frame.size());
    require(repaired == 1, "ARP sender hardware address repair mask");
    require(memcmp(frame.data() + 22, frame.data() + 6, 6) == 0,
            "ARP sender hardware address matches Ethernet source");
  }

  {
    std::vector<unsigned char> frame =
        make_ipv4_tcp_frame(2345, 44000, "$PacketSize=47ff#00");
    unsigned char *ip = frame.data() + 14;
    unsigned char *tcp = ip + 20;
    put_be16(ip + 10, 0);
    put_be16(tcp + 16, 0);
    const int repaired = repair_host_tap_egress(frame.data(), frame.size());
    require(repaired == 6, "GDB payload checksum repair mask");
    require(ipv4_checksum_valid(frame), "GDB IPv4 checksum valid after repair");
    require(tcp_checksum_valid(frame), "GDB TCP checksum valid after repair");
  }

  {
    std::vector<unsigned char> frame =
        make_ipv4_tcp_frame(1234, 80, "non-gdb-payload");
    unsigned char before_ip[2];
    unsigned char before_tcp[2];
    unsigned char *ip = frame.data() + 14;
    unsigned char *tcp = ip + 20;
    put_be16(ip + 10, 0);
    put_be16(tcp + 16, 0);
    memcpy(before_ip, ip + 10, sizeof(before_ip));
    memcpy(before_tcp, tcp + 16, sizeof(before_tcp));
    const int repaired = repair_host_tap_egress(frame.data(), frame.size());
    require(repaired == 0, "non-GDB payload is left untouched");
    require(memcmp(before_ip, ip + 10, sizeof(before_ip)) == 0,
            "non-GDB IPv4 checksum field unchanged");
    require(memcmp(before_tcp, tcp + 16, sizeof(before_tcp)) == 0,
            "non-GDB TCP checksum field unchanged");
  }

  {
    std::vector<unsigned char> frame = make_ipv4_tcp_frame(1234, 80, "");
    unsigned char *ip = frame.data() + 14;
    unsigned char *tcp = ip + 20;
    put_be16(ip + 10, 0);
    put_be16(tcp + 16, 0);
    const int repaired = repair_host_tap_egress(frame.data(), frame.size());
    require(repaired == 6, "zero-payload TCP control checksum repair mask");
    require(ipv4_checksum_valid(frame), "control IPv4 checksum valid after repair");
    require(tcp_checksum_valid(frame), "control TCP checksum valid after repair");
  }

  printf("PASS sshport_repair_test\n");
  return 0;
}
