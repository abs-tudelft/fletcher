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

/* This file can be used to quickly and easily test and debug the Fletcher
 * regexp example on SNAP.
 */

// Structures/unions to easily convert from 64-bit addresses to 2x32-bit registers */
typedef struct _lohi {
  uint32_t lo;
  uint32_t hi;
} lohi;

typedef union _addr_lohi {
  uint64_t full;
  lohi half;
} addr_lohi;


int main(int argc, char *argv[])
{
  int rc = 0;
  uint64_t cir;
	char device[64];
	struct snap_card *dn;
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

  // Read Card Capabilities
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
  printf("Attatching action.\n");
  act = snap_attach_action(dn, ACTION_TYPE_EXAMPLE, attach_flags, 100);

  printf("Allocating buffers.\n");
  // Allocate offsets buffer
  uint32_t * off_buf;
  uint32_t num_rows = 8*ACTIVE_UNITS;
  rc = posix_memalign((void**)&off_buf, BURST_LENGTH, sizeof(uint32_t)*(num_rows+1));
  
  // Allocate a (probably too large but irrelevant in simulation) values buffer.
  char * val_buf;
  rc = posix_memalign((void**)&val_buf,BURST_LENGTH, sizeof(char)*256*num_rows);
  
  // Get strings from the file in the first argument of this program
  if (argc < 2) {
    perror("Must provide input file.");
    exit(EXIT_FAILURE);
  }
  
  const char *fname  = argv[1];
  printf("Input file %s.\n", fname);
  fflush(stdout);
  
  FILE* fp = fopen(fname, "r");
  
  // Read the file.
  char * line;
  size_t len = 0;
  ssize_t read;
  
  if (fp == NULL) {
    perror("fopen");
    exit(EXIT_FAILURE);
  }

  printf("Preparing offset and values buffer.\n");
  int offset = 0;
  off_buf[0] = offset;
  int l=0;
  while ((read = getline(&line, &len, fp)) != -1) {
    // Get the destination address in the values buffer
    char* val_dest = &val_buf[off_buf[l]];
    // Copy the bytes, except C terminator character
    memcpy(val_dest, line, read - 1);
    // Set the next offset
    off_buf[l+1] = off_buf[l] + read;
    l++;
  }

  // Store addresses in union for 32-bit register setting
  addr_lohi off, val;
  off.full = (uint64_t)off_buf;
  val.full = (uint64_t)val_buf;

  printf("Offsets buffer=%016lX\n", off.full);
  printf("Values buffer=%016lX\n", val.full);

  // Reset the core
  snap_mmio_write32(dn, REG_CONTROL, REG_CONTROL_RESET);

  // Write offsets buffer address
  snap_mmio_write32(dn, REG_OFF_ADDR_LO, off.half.lo);
  snap_mmio_write32(dn, REG_OFF_ADDR_HI, off.half.hi);

  // Write values buffer address
  snap_mmio_write32(dn, REG_UTF8_ADDR_LO, val.half.lo);
  snap_mmio_write32(dn, REG_UTF8_ADDR_HI, val.half.hi);

  // Give each regexp unit the range to work on.
  for (int i = 0; i < ACTIVE_UNITS; i++) {
    uint32_t first = i * num_rows / ACTIVE_UNITS;
    uint32_t last = first + num_rows / ACTIVE_UNITS;
    // 4 * for the proper byte address:
    snap_mmio_write32(dn, REG_CUST_FIRST_IDX + 4*i, first);
    snap_mmio_write32(dn, REG_CUST_LAST_IDX + 4*i, last);
  }

  // Start the matchers
  snap_mmio_write32(dn, REG_CONTROL, REG_CONTROL_START);

  // Poll for completion
  uint32_t status = REG_STATUS_BUSY;
  do {
    snap_mmio_read32(dn, REG_STATUS, &status);
    printf("Status: %08X\n", status & REG_STATUS_MASK);
    sleep(1);
  }
  while((status & REG_STATUS_MASK) != REG_STATUS_DONE);

  // Read the results
  for (int i = 0; i < 16; i++) {
    uint32_t result = 0xDEADBEEF;
    snap_mmio_read32(dn, REG_RESULT + 4* i, &result);
    printf("Matches for RegExp %2d: %d\n", i, result);
  }

  printf("RC=%d\n",rc);

  free(off_buf);
  free(val_buf);

  snap_detach_action(act);

  snap_card_free(dn);

  return 0;

}
