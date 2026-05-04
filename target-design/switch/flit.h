#ifndef __FLIT_H
#define __FLIT_H

#include <stdlib.h>

#define BROADCAST_ADJUSTED (0xffff)

#ifndef MAC2PORT_SIZE
#define MAC2PORT_SIZE 0
#endif

/* ----------------------------------------------------
 * buffer flit operations
 *
 * ----------------------------------------------------
 */
// get a flit from recv_buf, given the token id
uint64_t get_flit(uint8_t *recv_buf, int tokenid) {
  int base = tokenid / TOKENS_PER_BIGTOKEN;
  int offset = tokenid % TOKENS_PER_BIGTOKEN;
  return *(((uint64_t *)recv_buf) + base * 8 + (offset + 1));
}

// write a flit to send_buf
void write_flit(uint8_t *send_buf, int tokenid, uint64_t flit) {
  int base = tokenid / TOKENS_PER_BIGTOKEN;
  int offset = tokenid % TOKENS_PER_BIGTOKEN;
  *(((uint64_t *)send_buf) + base * 8 + (offset + 1)) = flit;
}

// for a particular tokenid, determine if the flit is valid
int is_valid_flit(uint8_t *recv_buf, int tokenid) {
  int base = tokenid / TOKENS_PER_BIGTOKEN;
  int offset = tokenid % TOKENS_PER_BIGTOKEN;

  uint64_t lrv = ((uint64_t *)recv_buf)[base * 8];
  int bitoffset = 43 + (offset * 3);
  return (lrv >> bitoffset) & 0x1;
}

int is_last_flit(uint8_t *recv_buf, int tokenid) {
  int base = tokenid / TOKENS_PER_BIGTOKEN;
  int offset = tokenid % TOKENS_PER_BIGTOKEN;

  uint64_t lrv = ((uint64_t *)recv_buf)[base * 8];
  int bitoffset = 45 + (offset * 3);
  return (lrv >> bitoffset) & 0x1;
}

void write_valid_flit(uint8_t *send_buf, int tokenid) {
  int base = tokenid / TOKENS_PER_BIGTOKEN;
  int offset = tokenid % TOKENS_PER_BIGTOKEN;

  uint64_t *lrv = ((uint64_t *)send_buf) + base * 8;
  int bitoffset = 43 + (offset * 3);
  *lrv |= (1L << bitoffset);
}

void write_last_flit(uint8_t *send_buf, int tokenid, int is_last) {
  int base = tokenid / TOKENS_PER_BIGTOKEN;
  int offset = tokenid % TOKENS_PER_BIGTOKEN;

  uint64_t *lrv = ((uint64_t *)send_buf) + base * 8;
  int bitoffset = 45 + (offset * 3);
  *lrv |= (((uint64_t)is_last) << bitoffset);
}

/* get dest mac from flit, then get port from mac */
uint16_t get_port_from_flit(uint64_t flit, int current_port) {
  uint16_t is_multicast = (flit >> 16) & 0x1;
  uint16_t flit_low = (flit >> 48) & 0xFFFF; // indicates dest
  uint16_t sendport = (__builtin_bswap16(flit_low));
  uint16_t dest_suffix = sendport;
  static uint64_t debug_mac2port_oob = 0;
  static uint64_t debug_no_uplink = 0;

  if (is_multicast)
    return BROADCAST_ADJUSTED;

  sendport = sendport & 0xFFFF;
  // printf("mac: %04x\n", sendport);

  // At this point, we know the MAC address is not a broadcast address,
  // so we can just look up the port in the mac2port table
  if (sendport >= MAC2PORT_SIZE) {
    debug_mac2port_oob++;
    if (debug_mac2port_oob <= 64 ||
        ((debug_mac2port_oob & (debug_mac2port_oob - 1)) == 0)) {
      fprintf(stderr,
              "SWITCH DEBUG mac2port_oob event=%llu current_port=%d "
              "dest_suffix=0x%04x table_size=%d num_downlinks=%d "
              "num_uplinks=%d action=%s\n",
              (unsigned long long)debug_mac2port_oob,
              current_port,
              sendport,
              MAC2PORT_SIZE,
              NUMDOWNLINKS,
              NUMUPLINKS,
              NUMUPLINKS > 0 ? "route_to_first_uplink"
                             : "flood_unknown_unicast");
      fflush(stderr);
    }
    return NUMUPLINKS > 0 ? NUMDOWNLINKS : BROADCAST_ADJUSTED;
  }

  sendport = mac2port[sendport];

  if (sendport == NUMDOWNLINKS) {
    // this has been mapped to "any uplink", so pick one
#if NUMUPLINKS > 0
    int randval = rand() % NUMUPLINKS;
    sendport = randval + NUMDOWNLINKS;
#else
    if (NUMUPLINKS == 0) {
      debug_no_uplink++;
      if (debug_no_uplink <= 64 ||
          ((debug_no_uplink & (debug_no_uplink - 1)) == 0)) {
        fprintf(stderr,
                "SWITCH DEBUG mac2port_no_uplink event=%llu current_port=%d "
                "dest_suffix=0x%04x action=flood_unknown_unicast\n",
                (unsigned long long)debug_no_uplink,
                current_port,
                dest_suffix);
        fflush(stderr);
      }
      return BROADCAST_ADJUSTED;
    }
#endif
    //        printf("sending to random uplink.\n");
    //        printf("port: %04x\n", sendport);
  }
  // printf("port: %04x\n", sendport);
  return sendport;
}
#endif // __FLIT_H
