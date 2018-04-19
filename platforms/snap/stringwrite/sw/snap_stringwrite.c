#include <inttypes.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include <errno.h>
#include <malloc.h>
#include <unistd.h>
#include <sys/time.h>
#include <getopt.h>
#include <ctype.h>

#include <libsnap.h>
#include <snap_tools.h>
#include <snap_s_regs.h>

#include "snap_stringwrite.h"
#include <omp.h>

/* Structure to easily convert from 64-bit addresses to 2x32-bit registers */
typedef struct _lohi {
    uint32_t lo;
    uint32_t hi;
  }
lohi;

typedef union _addr_lohi {
  uint64_t full;
  lohi half;
}
addr_lohi;

int main(int argc, char * argv[]) {
  FILE * fp = fopen("swlog.log", "w");

  uint32_t num_rows = 1;
  uint32_t strlen_min = 0;
  uint32_t strlen_mask = 127;
  uint32_t alloc_reserve;

  if (argc > 3) {
    sscanf(argv[2], "%u", & strlen_min);
    sscanf(argv[3], "%u", & strlen_mask);
  }

  alloc_reserve = strlen_min + strlen_mask; //(6*(strlen_min + strlen_mask))/9;

  fprintf(fp, "Reserving an average of %u bytes per string.\n", alloc_reserve);

  uint32_t approx_max = 2147483648 / alloc_reserve;

  if (argc > 1) {
    sscanf(argv[1], "%u", & num_rows);

    if (num_rows >= approx_max) {
      fprintf(fp, "Byte offsets are likely to overflow 32-bit signed representation. Scaling back number of rows to %u.\n", approx_max);
      num_rows = approx_max;
    }
  }

  int rc = 0;
  uint64_t cir;
  char device[64];
  struct snap_card * dn; /* lib snap handle */
  int card_no = 0;
  unsigned long ioctl_data;

  snap_action_flag_t attach_flags = 0;
  struct snap_action * act = NULL;

  sprintf(device, "/dev/cxl/afu%d.0s", card_no);
  dn = snap_card_alloc_dev(device, SNAP_VENDOR_ID_IBM, SNAP_DEVICE_ID_SNAP);

  if (NULL == dn) {
    errno = ENODEV;
    fprintf(fp, "ERROR: snap_card_alloc_dev(%s)\n", device);
    return -1;
  }

  /* Read Card Capabilities */
  snap_card_ioctl(dn, GET_CARD_TYPE, (unsigned long) & ioctl_data);
  fprintf(fp, "SNAP on ");
  switch (ioctl_data) {
  case 0:
    fprintf(fp, "ADKU3");
    break;
  case 1:
    fprintf(fp, "N250S");
    break;
  case 16:
    fprintf(fp, "N250SP");
    break;
  default:
    fprintf(fp, "Unknown");
    break;
  }
  snap_card_ioctl(dn, GET_SDRAM_SIZE, (unsigned long) & ioctl_data);
  fprintf(fp, " Card, %d MB of Card Ram avilable.\n", (int) ioctl_data);

  snap_mmio_read64(dn, SNAP_S_CIR, & cir);
  fprintf(fp, "Read from MMIO. Attaching action.\n");
  fflush(stdout);

  // Attach action
  act = snap_attach_action(dn, ACTION_TYPE_EXAMPLE, attach_flags, 100);
  fprintf(fp, "Action attached, allocating buffers...\n");
  fflush(stdout);

  uint32_t * off_buf;
  rc = posix_memalign((void * * ) & off_buf, BURST_LENGTH, sizeof(uint32_t) * (num_rows + 1));

  // clear offset buffer
  for (uint32_t i = 0; i < num_rows + 1; i++) {
    off_buf[i] = 0xDEADBEEF;
  }

  char * val_buf;

  uint32_t max_num_chars = alloc_reserve * num_rows;
  rc = posix_memalign((void * * ) & val_buf, BURST_LENGTH, sizeof(char) * max_num_chars);

  // clear values buffer
  for (uint32_t i = 0; i < max_num_chars; i++) {
    val_buf[i] = '\0';
  }

  addr_lohi off, val;
  off.full = (uint64_t) off_buf;
  val.full = (uint64_t) val_buf;

  // Print initial contents:
  // print offsets buffer
  /*for (uint32_t i=0;i<num_rows+1;i++) {
  fprintf(fp, "%5u: %u\n", i, off_buf[i]);
  }

  // print values buffer
  for (uint32_t i=0;i<max_num_chars;i++) {
  fprintf(fp, "%5u: %8X ... %c\n", i, (int)val_buf[i], val_buf[i]);
  }*/
  fprintf(fp, "-----------------------------------------------------------------\n");

  fprintf(fp, "Buffers allocated. Setting registers.\n");
  fflush(stdout);

  fprintf(fp, "Offsets buffer @ %016lX\n", off.full);
  fprintf(fp, "Values buffer @ %016lX\n", val.full);
  fflush(stdout);

  snap_mmio_write32(dn, REG_CONTROL_LO, CONTROL_RESET);

  snap_mmio_write32(dn, REG_OFF_ADDR_LO, off.half.lo);
  snap_mmio_write32(dn, REG_OFF_ADDR_HI, off.half.hi);

  snap_mmio_write32(dn, REG_UTF8_ADDR_LO, val.half.lo);
  snap_mmio_write32(dn, REG_UTF8_ADDR_HI, val.half.hi);

  snap_mmio_write32(dn, REG_FIRST_IDX, 0);
  snap_mmio_write32(dn, REG_LAST_IDX, num_rows);

  snap_mmio_write32(dn, REG_STRLEN_MIN, strlen_min);
  snap_mmio_write32(dn, REG_PRNG_MASK, strlen_mask);

  fprintf(fp, "Registers set, starting core and polling for completion\n");
  fflush(stdout);

  double start = omp_get_wtime();

  snap_mmio_write32(dn, REG_CONTROL_LO, CONTROL_START);

  //uint32_t status = STATUS_BUSY;
  uint32_t last_off = 0xDEADBEEF;
  int i = 0;
  do {
    //snap_mmio_read32(dn, REG_STATUS_LO, &status);
    last_off = off_buf[num_rows];
    //fprintf(fp, "S: %08X\n", status);
    //fprintf(fp, "O[%d] = : %08X\n", num_rows, last_off);
    //fflush(stdout);
    usleep(10);
    i++;
  }
  while ((last_off == 0xDEADBEEF));

  i = 0;
  do {
    //fprintf(fp, "V[%d]=%c\n", last_off, val_buf[last_off-1]);
    //sleep(1);
    usleep(10);
    i++;
  }
  while ((val_buf[last_off - 1] == '\0') && (i < 16));

  double stop = omp_get_wtime();

  fprintf(fp, "Time: %f\n", stop - start);

  uint64_t total_bytes = num_rows * sizeof(uint32_t) + last_off;
  double total_time = stop - start;
  double gib = (double)(num_rows * sizeof(uint32_t) + last_off) / (double)(1 << 30);
  double gbps = (double) total_bytes / total_time * 1E-9;

  fprintf(fp, "Total bytes written: %lu\n", num_rows * sizeof(uint32_t) + last_off);
  fprintf(fp, "%f GiB\n", gib);
  fprintf(fp, "Throughput: %f\n", (double) total_bytes / total_time);
  fprintf(fp, "%f GB/s\n", gbps);
  fprintf(fp, "Last char: %2X ... %c\n", (int) val_buf[last_off - 1], val_buf[last_off - 1]);

  if (0) {
    // print offsets buffer
    for (uint32_t i = 0; i < num_rows + 1; i++) {
      fprintf(fp, "%8u: %u\n", i, off_buf[i]);
    }

    // print values buffer
    for (uint32_t i = 0; i < last_off;) {
      uint32_t j = i;
      fprintf(fp, "%8u: ", i);
      for (j = i;
        (j < i + 16) && (j < last_off); j++) {
        fprintf(fp, "%2X ", (int) val_buf[j]);
      }
      fprintf(fp, " ");
      for (j = i;
        (j < i + 16) && (j < last_off); j++) {
        fprintf(fp, "%c", val_buf[j]);
      }
      fprintf(fp, "\n");
      i = j;
    }
  }

  printf("%u, %u, %u, %u, %lu, %f, %f, %f\n", strlen_min, strlen_mask, alloc_reserve, num_rows, total_bytes, total_time, gib, gbps);

  free(off_buf);
  free(val_buf);

  snap_detach_action(act);

  snap_card_free(dn);

  fprintf(fp, "rc=%d\n", rc);

  return 0;

}
