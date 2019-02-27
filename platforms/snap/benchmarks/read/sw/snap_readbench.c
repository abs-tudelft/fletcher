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

#include "snap_readbench.h"
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

  uint32_t *region_ptr;
  size_t region_size = 0x000FFFFF + 1;
  rc = posix_memalign((void**)&region_ptr, 4096, region_size);

  addr_lohi region;
  region.full = (uint64_t) region_ptr;

  fprintf(fp, "Region @ %016lX\n", region.full);
  fprintf(fp, "Region allocated. Setting registers.\n");
  fflush(fp);
  
  snap_mmio_write32(dn, REG_CONTROL, CONTROL_RESET);
  snap_mmio_write32(dn, REG_CONTROL, 0);
  
  snap_mmio_write32(dn, REG_BASE_ADDR_LO, region.half.lo);
  snap_mmio_write32(dn, REG_BASE_ADDR_HI, region.half.hi);
  
  snap_mmio_write32(dn, REG_ADDR_MASK_LO, 0x000FF000);
  snap_mmio_write32(dn, REG_ADDR_MASK_HI, 0x00000000);
  
  snap_mmio_write32(dn, REG_BURST_LENGTH, 0x8);
  snap_mmio_write32(dn, REG_MAX_BURSTS, 0x100);

  fprintf(fp, "Registers set, starting core and polling for completion\n"); fflush(fp);

  double start = omp_get_wtime();

  snap_mmio_write32(dn, REG_CONTROL, CONTROL_START);

  uint32_t status   = 0;
  uint32_t cycles   = 0xDEADBEEF;
  uint32_t checksum = 0xDEADBEEF;
  
  int i = 0;
  do {
    snap_mmio_read32(dn, REG_STATUS, &status);
    fprintf(fp, "S: %08X\n", status); fflush(fp);
    sleep(1);
    i++;
  }
  while ((status != 0x4));
  
  snap_mmio_read32(dn, REG_CYCLES, &cycles);
  snap_mmio_read32(dn, REG_CHECKSUM, &checksum);
  
  fprintf(fp, "Cycles  : %08X\n", cycles); fflush(fp);
  fprintf(fp, "Checksum: %08X\n", checksum); fflush(fp);
  
  double stop = omp_get_wtime();

  fprintf(fp, "Time: %f\n", stop - start);

  fprintf(fp, "Detaching action.\n"); fflush(fp);
  snap_detach_action(act);

  fprintf(fp, "Detaching freeing card.\n"); fflush(fp);
  snap_card_free(dn);

  free(region_ptr);

  fprintf(fp, "rc=%d\n", rc);

  return 0;

}
