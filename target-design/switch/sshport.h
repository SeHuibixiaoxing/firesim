#ifndef __SSHPORT_H
#define __SSHPORT_H

#include <errno.h>
#include <queue>
#include <stdint.h>
#include <string.h>

#include <linux/if.h>
#include <linux/if_tun.h>
#include <sys/ioctl.h>

#define DEVNAME_BYTES 128
#define NET_IP_ALIGN 2
#define ETH_MAX_WORDS 190
#define ETH_MAX_BYTES 1518

struct network_flit {
  uint64_t data;
  bool last;
};

/* The other side of this port is a TAP interface to the host network.
 * This allows users to ssh into a simulated cluster */
class SSHPort : public BasePort {
public:
  SSHPort(int portNo);
  void tick();
  void tick_pre();
  void send();
  void recv();

private:
  int sshtapfd;
  char tap_devname[DEVNAME_BYTES + 1];
  uint64_t tap_send_buffer[ETH_MAX_WORDS], tap_recv_buffer[ETH_MAX_WORDS];
  void *tap_send_frame = ((char *)tap_send_buffer) + NET_IP_ALIGN;
  void *tap_recv_frame = ((char *)tap_recv_buffer) + NET_IP_ALIGN;
  int tap_send_idx = 0, tap_len;
  bool tap_can_send = false;
  std::queue<network_flit> out_flits;
  std::queue<network_flit> in_flits;
  uint64_t debug_output_events = 0;
  uint64_t debug_tap_send_events = 0;
  uint64_t debug_tap_recv_events = 0;
};

/* open TAP device */
static int tuntap_alloc(const char *dev, int flags) {
  struct ifreq ifr;
  int tapfd, err;

  if ((tapfd = open("/dev/net/tun", O_RDWR | O_NONBLOCK)) < 0) {
    perror("open()");
    return tapfd;
  }

  memset(&ifr, 0, sizeof(ifr));
  ifr.ifr_flags = flags;
  strncpy(ifr.ifr_name, dev, IFNAMSIZ);

  if ((err = ioctl(tapfd, TUNSETIFF, &ifr)) < 0) {
    perror("ioctl()");
    close(tapfd);
    return err;
  }

  return tapfd;
}

#define ceil_div(n, d) (((n)-1) / (d) + 1)

static uint16_t switch_read_be16(const unsigned char *p) {
  return ((uint16_t)p[0] << 8) | p[1];
}

static void switch_write_be16(unsigned char *p, uint16_t v) {
  p[0] = (unsigned char)(v >> 8);
  p[1] = (unsigned char)(v & 0xff);
}

static uint32_t switch_checksum_accumulate(uint32_t sum,
                                           const unsigned char *data,
                                           int len) {
  while (len >= 2) {
    sum += switch_read_be16(data);
    data += 2;
    len -= 2;
  }
  if (len == 1) {
    sum += (uint16_t)data[0] << 8;
  }
  return sum;
}

static uint16_t switch_checksum_finish(uint32_t sum) {
  while (sum >> 16) {
    sum = (sum & 0xffff) + (sum >> 16);
  }
  return (uint16_t)(~sum & 0xffff);
}

static uint16_t switch_ipv4_header_checksum(const unsigned char *ip,
                                            int ihl_bytes) {
  return switch_checksum_finish(switch_checksum_accumulate(0, ip, ihl_bytes));
}

static uint16_t switch_tcp_checksum(const unsigned char *ip,
                                    const unsigned char *tcp,
                                    int tcp_len) {
  uint32_t sum = 0;
  sum = switch_checksum_accumulate(sum, ip + 12, 8);
  sum += 0x0006;
  sum += (uint16_t)tcp_len;
  sum = switch_checksum_accumulate(sum, tcp, tcp_len);
  return switch_checksum_finish(sum);
}

static int repair_host_tap_egress(unsigned char *frame, int len) {
  enum {
    REPAIR_ARP_SHA = 1,
    REPAIR_IPV4_CHECKSUM = 2,
    REPAIR_TCP_CHECKSUM = 4
  };

  if (len < 14) {
    return 0;
  }

  int repaired = 0;
  const uint16_t ethertype = switch_read_be16(frame + 12);

  if (ethertype == 0x0806 && len >= 42 && switch_read_be16(frame + 14) == 1 &&
      switch_read_be16(frame + 16) == 0x0800 && frame[18] == 6 &&
      frame[19] == 4) {
    if (memcmp(frame + 22, frame + 6, 6) != 0) {
      memcpy(frame + 22, frame + 6, 6);
      repaired |= REPAIR_ARP_SHA;
    }
  }

  if (ethertype != 0x0800 || len < 34) {
    return repaired;
  }

  unsigned char *ip = frame + 14;
  const int version = ip[0] >> 4;
  const int ihl_bytes = (ip[0] & 0x0f) * 4;
  if (version != 4 || ihl_bytes < 20 || len < 14 + ihl_bytes ||
      ip[9] != 6) {
    return repaired;
  }

  const int total_len = switch_read_be16(ip + 2);
  if (total_len < ihl_bytes + 20 || len < 14 + total_len) {
    return repaired;
  }

  unsigned char *tcp = ip + ihl_bytes;
  const int tcp_len = total_len - ihl_bytes;
  const int tcp_header_len = (tcp[12] >> 4) * 4;
  if (tcp_header_len < 20 || tcp_len < tcp_header_len ||
      tcp_len != tcp_header_len) {
    return repaired;
  }

  const uint16_t old_ip_checksum = switch_read_be16(ip + 10);
  ip[10] = 0;
  ip[11] = 0;
  const uint16_t new_ip_checksum = switch_ipv4_header_checksum(ip, ihl_bytes);
  switch_write_be16(ip + 10, new_ip_checksum);
  if (old_ip_checksum != new_ip_checksum) {
    repaired |= REPAIR_IPV4_CHECKSUM;
  }

  const uint16_t old_tcp_checksum = switch_read_be16(tcp + 16);
  tcp[16] = 0;
  tcp[17] = 0;
  const uint16_t new_tcp_checksum = switch_tcp_checksum(ip, tcp, tcp_len);
  switch_write_be16(tcp + 16, new_tcp_checksum);
  if (old_tcp_checksum != new_tcp_checksum) {
    repaired |= REPAIR_TCP_CHECKSUM;
  }

  return repaired;
}

SSHPort::SSHPort(int portNo) : BasePort(portNo, false) {
  char *slotid =
      NULL; // placeholder for multiple SSH port support if we need it later
  char devname[DEVNAME_BYTES + 1];
  devname[0] = '\0';
  strncat(devname, "tap", DEVNAME_BYTES);

  if (!slotid) {
    fprintf(stderr, "Slot ID not specified. Assuming tap0\n");
    slotid = (char *)"0";
  }
  strncat(devname, slotid, DEVNAME_BYTES - 3);
  strncpy(tap_devname, devname, DEVNAME_BYTES);
  tap_devname[DEVNAME_BYTES] = '\0';

  sshtapfd = tuntap_alloc(devname, IFF_TAP | IFF_NO_PI);
  if (sshtapfd < 0) {
    fprintf(stderr, "Could not open tap interface %s\n", devname);
    abort();
  }
  fprintf(stderr, "SSHPort opened TAP interface %s fd=%d\n", tap_devname, sshtapfd);
  fflush(stderr);

  current_input_buf = (uint8_t *)calloc(sizeof(uint8_t), BUFSIZE_BYTES);
  current_output_buf = (uint8_t *)calloc(sizeof(uint8_t), BUFSIZE_BYTES);
}

void SSHPort::send() {
  // here, we take data that was written to the port by the switch
  // (data is in current_output_buf)
  // and push it into queues to send into the TAP

  if (((uint64_t *)current_output_buf)[0] == 0xDEADBEEFDEADBEEFL) {
    // if compress flag is set, clear it, this port type doesn't care
    // (and in fact, we're writing too much, so stuff later will get confused)
    ((uint64_t *)current_output_buf)[0] = 0L;
  }

  // first, push into out_flits queue
  int output_valid_flits = 0;
  int output_last_flits = 0;
  int output_sample_count = 0;
  uint64_t output_sample_data[4] = {0, 0, 0, 0};
  int output_sample_last[4] = {0, 0, 0, 0};
  for (int tokenno = 0; tokenno < NUM_TOKENS; tokenno++) {
    if (is_valid_flit(current_output_buf, tokenno)) {
      struct network_flit flt;
      flt.data = get_flit(current_output_buf, tokenno);
      flt.last = is_last_flit(current_output_buf, tokenno);
      output_valid_flits++;
      output_last_flits += flt.last ? 1 : 0;
      if (output_sample_count < 4) {
        output_sample_data[output_sample_count] = flt.data;
        output_sample_last[output_sample_count] = flt.last ? 1 : 0;
        output_sample_count++;
      }
      out_flits.push(flt);
    }
  }
  if (output_valid_flits > 0) {
    debug_output_events++;
    if (debug_output_events <= 128) {
      fprintf(stderr,
              "SWITCH DEBUG SSHPort output_buf port=%d event=%llu "
              "valid_flits=%d last_flits=%d queued_flits=%zu "
              "sample0=0x%016llx/%d sample1=0x%016llx/%d "
              "sample2=0x%016llx/%d sample3=0x%016llx/%d\n",
              _portNo,
              (unsigned long long)debug_output_events,
              output_valid_flits,
              output_last_flits,
              out_flits.size(),
              (unsigned long long)output_sample_data[0],
              output_sample_last[0],
              (unsigned long long)output_sample_data[1],
              output_sample_last[1],
              (unsigned long long)output_sample_data[2],
              output_sample_last[2],
              (unsigned long long)output_sample_data[3],
              output_sample_last[3]);
      fflush(stderr);
    }
  }

  // then, actually send stuff out on the TAP
  // next, see if there is data to send
  if (!tap_can_send) {
    while (!out_flits.empty()) {
      tap_send_buffer[tap_send_idx] = out_flits.front().data;
      tap_can_send = out_flits.front().last;
      out_flits.pop();
      tap_send_idx++;
      if (tap_can_send)
        break;
    }
  }

  if (tap_can_send) {
    tap_len = tap_send_idx * sizeof(uint64_t) - NET_IP_ALIGN;
    unsigned char *frame = (unsigned char *)tap_send_frame;
    const int repair_mask = repair_host_tap_egress(frame, tap_len);
    const int check_len = tap_len < 14 ? tap_len : 14;
    bool zero_eth_head = tap_len > 0;
    for (int i = 0; i < check_len; i++) {
      if (frame[i] != 0) {
        zero_eth_head = false;
      }
    }
    const bool short_frame = tap_len < 14;
    debug_tap_send_events++;
    if (debug_tap_send_events <= 128 || short_frame || zero_eth_head ||
        repair_mask != 0) {
      fprintf(stderr,
              "SWITCH DEBUG SSHPort tap_send port=%d event=%llu "
              "tap_len=%d flits=%d short=%d zero_eth_head=%d repair=0x%x "
              "word0=0x%016llx word1=0x%016llx word2=0x%016llx "
              "bytes=%02x %02x %02x %02x %02x %02x %02x %02x "
              "%02x %02x %02x %02x %02x %02x %02x %02x\n",
              _portNo,
              (unsigned long long)debug_tap_send_events,
              tap_len,
              tap_send_idx,
              short_frame ? 1 : 0,
              zero_eth_head ? 1 : 0,
              repair_mask,
              (unsigned long long)tap_send_buffer[0],
              (unsigned long long)tap_send_buffer[1],
              (unsigned long long)tap_send_buffer[2],
              tap_len > 0 ? frame[0] : 0,
              tap_len > 1 ? frame[1] : 0,
              tap_len > 2 ? frame[2] : 0,
              tap_len > 3 ? frame[3] : 0,
              tap_len > 4 ? frame[4] : 0,
              tap_len > 5 ? frame[5] : 0,
              tap_len > 6 ? frame[6] : 0,
              tap_len > 7 ? frame[7] : 0,
              tap_len > 8 ? frame[8] : 0,
              tap_len > 9 ? frame[9] : 0,
              tap_len > 10 ? frame[10] : 0,
              tap_len > 11 ? frame[11] : 0,
              tap_len > 12 ? frame[12] : 0,
              tap_len > 13 ? frame[13] : 0,
              tap_len > 14 ? frame[14] : 0,
              tap_len > 15 ? frame[15] : 0);
      fflush(stderr);
      const int debug_words = tap_send_idx < 16 ? tap_send_idx : 16;
      for (int debug_idx = 0; debug_idx < debug_words; debug_idx++) {
        fprintf(stderr,
                "SWITCH DEBUG SSHPort tap_send_word port=%d event=%llu "
                "idx=%d data=0x%016llx\n",
                _portNo,
                (unsigned long long)debug_tap_send_events,
                debug_idx,
                (unsigned long long)tap_send_buffer[debug_idx]);
      }
      const int debug_bytes = tap_len < 160 ? tap_len : 160;
      for (int debug_idx = 0; debug_idx < debug_bytes; debug_idx += 16) {
        fprintf(stderr,
                "SWITCH DEBUG SSHPort tap_send_bytes port=%d event=%llu "
                "off=%d bytes=%02x %02x %02x %02x %02x %02x %02x %02x "
                "%02x %02x %02x %02x %02x %02x %02x %02x\n",
                _portNo,
                (unsigned long long)debug_tap_send_events,
                debug_idx,
                debug_idx + 0 < tap_len ? frame[debug_idx + 0] : 0,
                debug_idx + 1 < tap_len ? frame[debug_idx + 1] : 0,
                debug_idx + 2 < tap_len ? frame[debug_idx + 2] : 0,
                debug_idx + 3 < tap_len ? frame[debug_idx + 3] : 0,
                debug_idx + 4 < tap_len ? frame[debug_idx + 4] : 0,
                debug_idx + 5 < tap_len ? frame[debug_idx + 5] : 0,
                debug_idx + 6 < tap_len ? frame[debug_idx + 6] : 0,
                debug_idx + 7 < tap_len ? frame[debug_idx + 7] : 0,
                debug_idx + 8 < tap_len ? frame[debug_idx + 8] : 0,
                debug_idx + 9 < tap_len ? frame[debug_idx + 9] : 0,
                debug_idx + 10 < tap_len ? frame[debug_idx + 10] : 0,
                debug_idx + 11 < tap_len ? frame[debug_idx + 11] : 0,
                debug_idx + 12 < tap_len ? frame[debug_idx + 12] : 0,
                debug_idx + 13 < tap_len ? frame[debug_idx + 13] : 0,
                debug_idx + 14 < tap_len ? frame[debug_idx + 14] : 0,
                debug_idx + 15 < tap_len ? frame[debug_idx + 15] : 0);
      }
      fflush(stderr);
    }
    if (::write(sshtapfd, tap_send_frame, tap_len) >= 0) {
      tap_send_idx = 0;
      tap_can_send = false;
    } else if (errno != EAGAIN) {
      int saved_errno = errno;
      fprintf(stderr,
              "SSHPort TAP write failed dev=%s errno=%d. "
              "For host access, this TAP must be configured up with "
              "172.16.0.1/16 before target traffic reaches the switch.\n",
              tap_devname,
              saved_errno);
      errno = saved_errno;
      perror("send()");
      abort();
    }
  }

  // finally, clear current_output_buf for the next iter
  memset(current_output_buf, 0x0, BUFSIZE_BYTES);
}

void SSHPort::recv() {
  // clear the input buf leftover from previous cycle
  memset(current_input_buf, 0x0, BUFSIZE_BYTES);

  // pull in flits from the TAP
  tap_len = ::read(sshtapfd, tap_recv_frame, ETH_MAX_BYTES);
  if (tap_len >= 0) {
    const unsigned char *frame = (const unsigned char *)tap_recv_frame;
    debug_tap_recv_events++;
    if (debug_tap_recv_events <= 64) {
      fprintf(stderr,
              "SWITCH DEBUG SSHPort tap_recv port=%d event=%llu "
              "tap_len=%d bytes=%02x %02x %02x %02x %02x %02x "
              "%02x %02x %02x %02x %02x %02x %02x %02x %02x %02x\n",
              _portNo,
              (unsigned long long)debug_tap_recv_events,
              tap_len,
              tap_len > 0 ? frame[0] : 0,
              tap_len > 1 ? frame[1] : 0,
              tap_len > 2 ? frame[2] : 0,
              tap_len > 3 ? frame[3] : 0,
              tap_len > 4 ? frame[4] : 0,
              tap_len > 5 ? frame[5] : 0,
              tap_len > 6 ? frame[6] : 0,
              tap_len > 7 ? frame[7] : 0,
              tap_len > 8 ? frame[8] : 0,
              tap_len > 9 ? frame[9] : 0,
              tap_len > 10 ? frame[10] : 0,
              tap_len > 11 ? frame[11] : 0,
              tap_len > 12 ? frame[12] : 0,
              tap_len > 13 ? frame[13] : 0,
              tap_len > 14 ? frame[14] : 0,
              tap_len > 15 ? frame[15] : 0);
      fflush(stderr);
    }
    int i, n = ceil_div(tap_len + NET_IP_ALIGN, sizeof(uint64_t));
    for (i = 0; i < n; i++) {
      struct network_flit flt;
      flt.data = tap_recv_buffer[i];
      flt.last = i == (n - 1);
      in_flits.push(flt);
    }
  } else if (errno != EAGAIN) {
    perror("recv()");
    abort();
  }

  // next, pull off of in_flits until current_input_buf is full, or we have
  // nothing left to write

  for (int tokenno = 0; tokenno < NUM_TOKENS; tokenno++) {
    if (!in_flits.empty()) {
      write_last_flit(current_input_buf, tokenno, in_flits.front().last);
      write_valid_flit(current_input_buf, tokenno);
      write_flit(current_input_buf, tokenno, in_flits.front().data);
      in_flits.pop();
    }
  }
}

void SSHPort::tick() {
  // don't need to do anything for SSHPorts
}

void SSHPort::tick_pre() {
  // don't need to do anything for SSHPorts
}
#endif // __SSHPORT_H
