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

#include "snap_regexp.h"

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
  uint32_t num_rows = 4*ACTIVE_UNITS;
  rc = posix_memalign((void**)&off_buf, BURST_LENGTH, sizeof(uint32_t)*(num_rows+1));

  for (uint32_t i=0;i<num_rows+1;i++) {
    off_buf[i] = 256 * i;
  }

  char * val_buf;
  rc = posix_memalign((void**)&val_buf,BURST_LENGTH, sizeof(char)*off_buf[num_rows]);

  const char * alphabet = "abcdefghijklmnopqrstuvwxyz";
  int nchars = strlen(alphabet);
  for (uint32_t i=0;i<  off_buf[num_rows];i++) {
    val_buf[i] = alphabet[i%nchars];
  }

  printf("rc=%d\n", rc);

  addr_lohi off, val;
  off.full = (uint64_t)off_buf;
  val.full = (uint64_t)val_buf;

  printf("Offsets buffer=%016lX\n", off.full);
  printf("Values buffer=%016lX\n", val.full);

  snap_mmio_write32(dn, CONTROL_REG_LO, CONTROL_RESET);

  snap_mmio_write32(dn, CFG_OFF_LO, off.half.lo);
  snap_mmio_write32(dn, CFG_OFF_HI, off.half.hi);

  snap_mmio_write32(dn, CFG_DATA_LO, val.half.lo);
  snap_mmio_write32(dn, CFG_DATA_HI, val.half.hi);


  for (int i = 0; i < ACTIVE_UNITS; i++) {
    uint32_t first = i * num_rows / ACTIVE_UNITS;
    uint32_t last = first + num_rows / ACTIVE_UNITS;
    // 4 * for the proper byte address:
    snap_mmio_write32(dn, FIRST_IDX_OFF + 4*i, first);
    snap_mmio_write32(dn, LAST_IDX_OFF + 4*i, last);
  }


  //snap_mmio_write32(dn, FIRST_IDX_OFF, 0);
  //snap_mmio_write32(dn, LAST_IDX_OFF, 1);

  snap_mmio_write32(dn, CONTROL_REG_LO, CONTROL_START);

  uint32_t status = STATUS_BUSY;
  do {
    snap_mmio_read32(dn, STATUS_REG_LO, &status);
    printf("Status: %08X\n", status & STATUS_MASK);
    sleep(1);
  }
  while((status & STATUS_MASK) != STATUS_DONE);



  free(off_buf);
  free(val_buf);

  snap_detach_action(act);

  snap_card_free(dn);

  return 0;

}
