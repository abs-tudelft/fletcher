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

/* Structure to easily convert from 64-bit addresses to 2x32-bit registers */
typedef struct _lohi {
  uint32_t lo;
  uint32_t hi;
} lohi;

typedef union _addr_lohi {
  uint64_t full;
  lohi half;
} addr_lohi;


int main()//int argc, char *argv[])
{
  int rc = 0;
  uint64_t cir;
	char device[64];
	struct snap_card *dn;	/* lib snap handle */
  int card_no = 0;
  unsigned long ioctl_data;

  snap_action_flag_t attach_flags = 0;
  struct snap_action *act = NULL;

  sprintf(device, "/dev/cxl/afu%d.0s", card_no);
	dn = snap_card_alloc_dev(device, SNAP_VENDOR_ID_IBM, SNAP_DEVICE_ID_SNAP);


  if (NULL == dn) {
		errno = ENODEV;
		printf("ERROR: snap_card_alloc_dev(%s)\n", device);
		return -1;
	}

  /* Read Card Capabilities */
	snap_card_ioctl(dn, GET_CARD_TYPE, (unsigned long)&ioctl_data);
	printf("SNAP on ");
	switch (ioctl_data) {
		case  0: printf("ADKU3"); break;
		case  1: printf("N250S"); break;
		case 16: printf("N250SP"); break;
		default: printf("Unknown"); break;
	}
	snap_card_ioctl(dn, GET_SDRAM_SIZE, (unsigned long)&ioctl_data);
	printf(" Card, %d MB of Card Ram avilable.\n", (int)ioctl_data);

	snap_mmio_read64(dn, SNAP_S_CIR, &cir);

  // Attach action
  act = snap_attach_action(dn, ACTION_TYPE_EXAMPLE, attach_flags, 100);

  /*
  uint32_t rv;
  for (int i=0;i<32*4;i+=4) {
    snap_mmio_read32(dn, i, &rv);
    printf("REG %02d = %08X\n", i, rv);
  }
  */

  uint32_t * off_buf;
  uint32_t num_rows = 16;
  rc = posix_memalign((void**)&off_buf, BURST_LENGTH, sizeof(uint32_t)*(num_rows+1));

  char * val_buf;
  uint32_t num_chars = 256 * num_rows;
  rc = posix_memalign((void**)&val_buf,BURST_LENGTH, sizeof(char)*num_chars);

  addr_lohi off, val;
  off.full = (uint64_t)off_buf;
  val.full = (uint64_t)val_buf;

  printf("Offsets buffer=%016lX\n", off.full);
  printf("Values buffer=%016lX\n", val.full);

  snap_mmio_write32(dn, REG_CONTROL_LO, CONTROL_RESET);

  snap_mmio_write32(dn, REG_OFF_ADDR_LO, off.half.lo);
  snap_mmio_write32(dn, REG_OFF_ADDR_HI, off.half.hi);

  snap_mmio_write32(dn, REG_UTF8_ADDR_LO, val.half.lo);
  snap_mmio_write32(dn, REG_UTF8_ADDR_HI, val.half.hi);

  snap_mmio_write32(dn, REG_FIRST_IDX, 0);
  snap_mmio_write32(dn, REG_LAST_IDX, num_rows);
  
  snap_mmio_write32(dn, REG_STRLEN_MIN, 0);
  snap_mmio_write32(dn, REG_PRNG_MASK,  127);

  snap_mmio_write32(dn, REG_CONTROL_LO, CONTROL_START);

  uint32_t status = STATUS_BUSY;
  do {
    snap_mmio_read32(dn, REG_STATUS_LO, &status);
    printf("Status: %08X\n", status & STATUS_MASK);
    sleep(1);
  }
  while((status & STATUS_MASK) != STATUS_DONE);

  free(off_buf);
  free(val_buf);

  snap_detach_action(act);

  snap_card_free(dn);
  
  printf("rc=%d", rc);

  return 0;

}
