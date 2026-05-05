#ifndef __SHMEMPORT_H
#define __SHMEMPORT_H

#include <errno.h>

class ShmemPort : public BasePort {
public:
  ShmemPort(int portNo, char *shmemportname, bool uplink);
  void tick();
  void tick_pre();
  void send();
  void recv();

private:
  uint8_t *recvbufs[2];
  uint8_t *sendbufs[2];
  int currentround = 0;
  uint64_t debug_recv_events = 0;
  uint64_t debug_send_events = 0;
};

ShmemPort::ShmemPort(int portNo, char *shmemportname, bool uplink)
    : BasePort(portNo, !uplink) {
#define SHMEM_EXTRABYTES 1
#define SHMEM_NAME_SIZE 120

  // create shared memory regions
  char name[SHMEM_NAME_SIZE];
  int shmemfd;

  char *recvdirection;
  char *senddirection;

  int ftresult;

  int shm_flags;
  if (uplink) {
    // uplink should not truncate on SHM_OPEN
    shm_flags = O_RDWR /*| O_CREAT*/;
  } else {
    shm_flags = O_RDWR | O_CREAT | O_TRUNC;
  }

  if (uplink) {
    fprintf(stdout, "Uplink Port\n");
    recvdirection = "stn";
    senddirection = "nts";
  } else {
    fprintf(stdout, "Downlink Port\n");
    recvdirection = "nts";
    senddirection = "stn";
  }

  for (int j = 0; j < 2; j++) {
    int namelen;
    if (shmemportname) {
      fprintf(stdout, "Using non-slot-id associated shmemportname:\n");
      namelen = snprintf(name,
                         SHMEM_NAME_SIZE,
                         "/port_%s%s_%d",
                         recvdirection,
                         shmemportname,
                         j);
      if (namelen >= SHMEM_NAME_SIZE) {
        fprintf(stderr,
                "shmem port name /port_%s%s_%d too large\n",
                recvdirection,
                shmemportname,
                j);
      }
    } else {
      fprintf(stdout, "Using slot-id associated shmemportname:\n");
      snprintf(
          name, SHMEM_NAME_SIZE, "/port_%s%d_%d", recvdirection, _portNo, j);
    }
    fprintf(stdout, "opening/creating shmem region\n%s\n", name);
    shmemfd = shm_open(name, shm_flags, S_IRWXU);

    while (shmemfd == -1) {
      perror("shm_open failed");
      if (uplink) {
        fprintf(stdout, "retrying in 1s...\n");
        sleep(1);
        shmemfd = shm_open(name, shm_flags, S_IRWXU);
      } else {
        abort();
      }
    }

    if (!uplink) {
      ftresult = ftruncate(shmemfd, BUFSIZE_BYTES + SHMEM_EXTRABYTES);
      if (ftresult == -1) {
        perror("ftruncate failed");
        abort();
      }
    }

    recvbufs[j] = (uint8_t *)mmap(NULL,
                                  BUFSIZE_BYTES + SHMEM_EXTRABYTES,
                                  PROT_READ | PROT_WRITE,
                                  MAP_SHARED,
                                  shmemfd,
                                  0);

    if (recvbufs[j] == MAP_FAILED) {
      perror("mmap failed");
      abort();
    }

    if (!uplink) {
      memset(recvbufs[j], 0, BUFSIZE_BYTES + SHMEM_EXTRABYTES);
    }

    if (shmemportname) {
      fprintf(stdout, "Using non-slot-id associated shmemportname:\n");
      sprintf(name, "/port_%s%s_%d", senddirection, shmemportname, j);
    } else {
      fprintf(stdout, "Using slot-id associated shmemportname:\n");
      sprintf(name, "/port_%s%d_%d", senddirection, _portNo, j);
    }
    fprintf(stdout, "opening/creating shmem region\n%s\n", name);
    shmemfd = shm_open(name, shm_flags, S_IRWXU);

    while (shmemfd == -1) {
      perror("shm_open failed");
      if (uplink) {
        fprintf(stdout, "retrying in 1s...\n");
        sleep(1);
        shmemfd = shm_open(name, shm_flags, S_IRWXU);
      } else {
        abort();
      }
    }

    if (!uplink) {
      ftresult = ftruncate(shmemfd, BUFSIZE_BYTES + SHMEM_EXTRABYTES);
      if (ftresult == -1) {
        perror("ftruncate failed");
        abort();
      }
    }

    sendbufs[j] = (uint8_t *)mmap(NULL,
                                  BUFSIZE_BYTES + SHMEM_EXTRABYTES,
                                  PROT_READ | PROT_WRITE,
                                  MAP_SHARED,
                                  shmemfd,
                                  0);

    if (sendbufs[j] == MAP_FAILED) {
      perror("mmap failed");
      abort();
    }

    if (!uplink) {
      memset(sendbufs[j], 0, BUFSIZE_BYTES + SHMEM_EXTRABYTES);
    }
  }

  // setup "current" bufs. tick will swap for shmem passing
  current_input_buf = recvbufs[0];
  current_output_buf = sendbufs[0];
}

void ShmemPort::send() {
  if (((uint64_t *)current_output_buf)[0] == 0xDEADBEEFDEADBEEFL) {
    // Shmem ports exchange full buffers. Clear the compressed-empty marker so
    // the peer cannot decode marker bits as valid/last flit metadata.
    ((uint64_t *)current_output_buf)[0] = 0L;
  }

  int valid_flits = 0;
  int last_flits = 0;
  int sample_count = 0;
  uint64_t sample_data[16] = {0};
  int sample_last[16] = {0};
  int sample_token[16] = {0};
  for (int tokenno = 0; tokenno < NUM_TOKENS; tokenno++) {
    if (is_valid_flit(current_output_buf, tokenno)) {
      const bool last = is_last_flit(current_output_buf, tokenno);
      valid_flits++;
      last_flits += last ? 1 : 0;
      if (sample_count < 16) {
        sample_data[sample_count] = get_flit(current_output_buf, tokenno);
        sample_last[sample_count] = last ? 1 : 0;
        sample_token[sample_count] = tokenno;
        sample_count++;
      }
    }
  }
  if (valid_flits > 0) {
    debug_send_events++;
    if (debug_send_events <= 128) {
      fprintf(stderr,
              "SWITCH DEBUG ShmemPort send port=%d event=%llu round=%d "
              "valid_flits=%d last_flits=%d marker=0x%016llx "
              "sample0=0x%016llx/%d sample1=0x%016llx/%d "
              "sample2=0x%016llx/%d sample3=0x%016llx/%d\n",
              _portNo,
              (unsigned long long)debug_send_events,
              currentround,
              valid_flits,
              last_flits,
              (unsigned long long)((uint64_t *)current_output_buf)[0],
              (unsigned long long)sample_data[0],
              sample_last[0],
              (unsigned long long)sample_data[1],
              sample_last[1],
              (unsigned long long)sample_data[2],
              sample_last[2],
              (unsigned long long)sample_data[3],
              sample_last[3]);
      fflush(stderr);
      for (int debug_idx = 0; debug_idx < sample_count; debug_idx++) {
        fprintf(stderr,
                "SWITCH DEBUG ShmemPort send_flit port=%d event=%llu "
                "sample=%d token=%d data=0x%016llx last=%d\n",
                _portNo,
                (unsigned long long)debug_send_events,
                debug_idx,
                sample_token[debug_idx],
                (unsigned long long)sample_data[debug_idx],
                sample_last[debug_idx]);
      }
      fflush(stderr);
    }
  }
  // mark flag to initiate "send"
  current_output_buf[BUFSIZE_BYTES] = 1;
}

void ShmemPort::recv() {
  volatile uint8_t *polladdr = current_input_buf + BUFSIZE_BYTES;
  while (*polladdr == 0) {
    ;
  } // poll
  int valid_flits = 0;
  int last_flits = 0;
  int sample_count = 0;
  uint64_t sample_data[16] = {0};
  int sample_last[16] = {0};
  int sample_token[16] = {0};
  for (int tokenno = 0; tokenno < NUM_TOKENS; tokenno++) {
    if (is_valid_flit(current_input_buf, tokenno)) {
      const bool last = is_last_flit(current_input_buf, tokenno);
      valid_flits++;
      last_flits += last ? 1 : 0;
      if (sample_count < 16) {
        sample_data[sample_count] = get_flit(current_input_buf, tokenno);
        sample_last[sample_count] = last ? 1 : 0;
        sample_token[sample_count] = tokenno;
        sample_count++;
      }
    }
  }
  const uint64_t marker = ((uint64_t *)current_input_buf)[0];
  if (valid_flits > 0 || marker != 0) {
    debug_recv_events++;
    if (debug_recv_events <= 128 || marker == 0xDEADBEEFDEADBEEFL) {
      fprintf(stderr,
              "SWITCH DEBUG ShmemPort recv port=%d event=%llu round=%d "
              "valid_flits=%d last_flits=%d marker=0x%016llx "
              "sample0=0x%016llx/%d sample1=0x%016llx/%d "
              "sample2=0x%016llx/%d sample3=0x%016llx/%d\n",
              _portNo,
              (unsigned long long)debug_recv_events,
              currentround,
              valid_flits,
              last_flits,
              (unsigned long long)marker,
              (unsigned long long)sample_data[0],
              sample_last[0],
              (unsigned long long)sample_data[1],
              sample_last[1],
              (unsigned long long)sample_data[2],
              sample_last[2],
              (unsigned long long)sample_data[3],
              sample_last[3]);
      fflush(stderr);
      for (int debug_idx = 0; debug_idx < sample_count; debug_idx++) {
        fprintf(stderr,
                "SWITCH DEBUG ShmemPort recv_flit port=%d event=%llu "
                "sample=%d token=%d data=0x%016llx last=%d\n",
                _portNo,
                (unsigned long long)debug_recv_events,
                debug_idx,
                sample_token[debug_idx],
                (unsigned long long)sample_data[debug_idx],
                sample_last[debug_idx]);
      }
      fflush(stderr);
    }
  }
}

void ShmemPort::tick_pre() {
  currentround = (currentround + 1) % 2;
  current_output_buf = sendbufs[currentround];
}

void ShmemPort::tick() {
  // zero out recv buf flag for next iter
  current_input_buf[BUFSIZE_BYTES] = 0;

  // swap buf pointers
  current_input_buf = recvbufs[currentround];
}
#endif // __SSHMEMPORT_H
