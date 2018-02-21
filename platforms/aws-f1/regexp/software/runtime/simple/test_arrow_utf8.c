// Amazon FPGA Hardware Development Kit
//
// Copyright 2016 Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Amazon Software License (the "License"). You may not use
// this file except in compliance with the License. A copy of the License is
// located at
//
//    http://aws.amazon.com/asl/
//
// or in the "license" file accompanying this file. This file is distributed on
// an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or
// implied. See the License for the specific language governing permissions and
// limitations under the License.

#include <stdio.h>
#include <fcntl.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
#include <unistd.h>
#include <poll.h>

#include <fpga_pci.h>
#include <fpga_mgmt.h>
#include <utils/lcd.h>

#include <byteswap.h>

#include <regex.h>

#include <omp.h>

//#define DEBUG
//#define INFO
//#define PRINT_STRINGS
//#define USE_OMP

#ifdef DEBUG
#define DBG(...) do{ fprintf( stderr, __VA_ARGS__ ); } while( false )
#else
#define DBG(...) 
#endif

#ifdef INFO
#define INF(...) do{ fprintf( stderr, __VA_ARGS__ ); } while( false )
#else
#define INF(...) 
#endif

static uint16_t pci_vendor_id = 0x1D0F; /* Amazon PCI Vendor ID */
static uint16_t pci_device_id = 0xF001;

#define DEFAULT_SLOT_ID 0

/* Hardware settings */
#define ACTIVE_UNITS    16
#define TOTAL_UNITS     16

/* Registers */
#define STATUS_REG_HI   0
#define STATUS_REG_LO   4
#define   STATUS_BUSY   0x0000FFFF
#define   STATUS_DONE   0xFFFF0000

#define CONTROL_REG_HI  8
#define CONTROL_REG_LO  12
#define   CONTROL_START 0x0000FFFF
#define   CONTROL_RESET 0xFFFF0000

#define RETURN_HI       16
#define RETURN_LO       20

#define CFG_OFF_HI      24
#define CFG_OFF_LO      28

#define CFG_DATA_HI     32
#define CFG_DATA_LO     36

#define FIRST_IDX_OFF   40
#define LAST_IDX_OFF    FIRST_IDX_OFF + 4*TOTAL_UNITS
#define RESULT_OFF      LAST_IDX_OFF + 4*TOTAL_UNITS

/* Data sizes */
#define MIN_STR_LEN     6           // Must be at least len("kitten")
#define MAX_STR_LEN     256         // Must be larger than len("kitten")
#define DEFAULT_ROWS    8*1024*1024 // About 1 gigabyte of characters

#define BURST_LENGTH    4096

#define TIME_PRINT      "%16.12f, "

/* Structure to easily convert from 64-bit addresses to 2x32-bit registers */
typedef struct _lohi {
  uint32_t lo;
  uint32_t hi;
} lohi;

typedef union _addr_lohi {
  uint64_t full;
  lohi half;
} addr_lohi;

/* use the stdout logger */
const struct logger *logger = &logger_stdout;

void usage(const char* program_name) {
  INF("usage: %s [<num_rows>] [<slot>]\n", program_name);
}

static int check_slot_config(int slot_id) {
  int rc;
  struct fpga_mgmt_image_info info = { 0 };

  /* get local image description, contains status, vendor id, and device id */
  rc = fpga_mgmt_describe_local_image(slot_id, &info, 0);
  fail_on(rc, out, "Unable to get local image information. Are you running as root?");

  /* check to see if the slot is ready */
  if (info.status != FPGA_STATUS_LOADED) {
    rc = 1;
    fail_on(rc, out, "Slot %d is not ready", slot_id);
  }

  /* confirm that the AFI that we expect is in fact loaded */
  if (info.spec.map[FPGA_APP_PF].vendor_id != pci_vendor_id
      || info.spec.map[FPGA_APP_PF].device_id != pci_device_id) {
    rc = 1;
    INF(
        "The slot appears loaded, but the pci vendor or device ID doesn't match the expected values. You may need to rescan the fpga with\n"
            "fpga-describe-local-image -S %i -R\n"
            "Note that rescanning can change which device file in /dev/ a FPGA will map to. To remove and re-add your edma driver and reset the device file mappings, run\n"
            "`sudo rmmod edma-drv && sudo insmod <aws-fpga>/sdk/linux_kernel_drivers/edma/edma-drv.ko`\n",
        slot_id);
    fail_on(rc, out,
        "The PCI vendor id and device of the loaded image are not the expected values.");
  }

  out: return rc;
}

/**
 * Read and print the strings from the offset and data buffer
 */
void print_strings(uint32_t* offsets, char* data, int num_rows, int hex) {
  int offsets_size = num_rows + 1;
  for (int i = 0; i < offsets_size; i++) {
    INF("%6d, %5d, %5d, ", i, offsets[i], offsets[i + 1] - offsets[i]);
    for (int j = offsets[i]; (j < offsets[i + 1]) && (i < num_rows); j++) {
      if (hex) {
        INF("%2X ", data[j]);
      } else {
        putchar(data[j]);
      }
    }
    INF("\n");
  }
  fflush(stdout);
}

/**
 * Generate random strings randomly containing some string.
 */
int gen_rand_strings_with(const char* with,
                          const char* alphabet,
                          uint32_t** idx_buf,
                          char** data_buf,
                          size_t* data_size,
                          uint32_t num_rows) {

  int strings = 0;
  size_t length = strlen(with);

  // Determine offsets buffer size
  size_t idx_buf_size = sizeof(uint32_t) * (num_rows + 1);
  uint32_t* offsets_buffer = (uint32_t*) malloc(idx_buf_size);

  // Set random seed, we always want the same seed for debugging
  srand(0);

  // Generate indices

  // First offset
  offsets_buffer[0] = 0;

  // Iterate over rows, inclusive range because of last offset
  for (uint32_t i = 1; i <= num_rows; i++) {
    // Generate a string length between min and max
    offsets_buffer[i] = offsets_buffer[i - 1] + length
        + ((uint32_t) rand() % (MAX_STR_LEN - MIN_STR_LEN));
  }

  // The last offset is the size of the data buffer
  *data_size = (size_t) offsets_buffer[num_rows];

  // Allocate the data buffer now that we know the total length
  char* data_buffer = (char*) malloc(sizeof(char) * (*data_size));

  // Generate data:
  for (uint32_t i = 0; i < num_rows; i++) {
    int has_str = 0;
    // Generate random characters
    for (uint32_t j = offsets_buffer[i]; j < offsets_buffer[i + 1];) {
      // Randomly insert a string and check if it still fits in the current string
      if ((rand() % MAX_STR_LEN == 0) && (j + length < offsets_buffer[i + 1])) {
        memcpy(&data_buffer[j], with, length);
        j += strlen(with);
        has_str = 1;
      } else {
        char chr = alphabet[rand() % strlen(alphabet)];
        data_buffer[j] = chr;
        j += 1;
      }
    }
    strings += has_str;
  }

  // Set buffer addresses
  *idx_buf = offsets_buffer;
  *data_buf = data_buffer;

  return strings;
}

/**
 * Count the number of strings matching to a regular expression given an offsets and data buffer
 */
uint32_t count_matches_cpu(const uint32_t* offsets_buffer,
                           const char* data_buffer,
                           const char* regexp_str,
                           uint32_t num_rows) {
  regex_t regexp;
  int regexp_ret;
  char str_buf[MAX_STR_LEN + 1];

  regexp_ret = regcomp(&regexp, regexp_str, REG_NOSUB);
  if (regexp_ret) {
    fprintf(stderr, "Could not compile regex\n");
    exit(1);
  }

  uint32_t total_matches = 0;
  for (int i = 0; i < num_rows; i++) {
    // Get a pointer to the string
    const char* str = &data_buffer[offsets_buffer[i]];

    // Clear the string buffer
    memset(str_buf, 0, MAX_STR_LEN + 1);

    // Calculate the string length
    int len = offsets_buffer[i + 1] - offsets_buffer[i];

    // Copy the string
    memcpy(str_buf, str, len);

    // Terminate the string
    str_buf[len] = '\0';

    // Perform the regular expression matching   
    regexp_ret = regexec(&regexp, str_buf, 0, NULL, 0);
    if (regexp_ret == 0) {
      total_matches++;
    }

#ifdef DEBUG
#ifdef PRINT_STRINGS
    printf("%6d, %5d, %5d, %s\n", i, !regexp_ret, len, str_buf);
#endif
#endif
  }
  return total_matches;
}

/**
 * Count the number of strings matching to a regular expression given an offsets and data buffer in parallel using OpenMP
 */
uint32_t count_matches_omp(const uint32_t* offsets_buffer,
                           const char* data_buffer,
                           const char* regexp_str,
                           uint32_t num_rows,
                           int threads) {
  
  uint32_t total_matches = 0;
  
  if (threads == 0) {
    threads = omp_get_max_threads();
  }
  
  uint32_t* thread_matches = (uint32_t*)calloc(threads, sizeof(uint32_t));
  
  omp_set_num_threads(threads);

  #pragma omp parallel 
  {
    int thread = omp_get_thread_num();
    uint32_t matches = 0;
    
    regex_t regexp;
    int regexp_ret;
    char str_buf[MAX_STR_LEN + 1];

    regexp_ret = regcomp(&regexp, regexp_str, REG_NOSUB);
    if (regexp_ret) {
      fprintf(stderr, "Could not compile regex\n");
      exit(1);
    }

    #pragma omp for
    for (int i = 0; i < num_rows; i++) {
      // Get a pointer to the string
      const char* str = &data_buffer[offsets_buffer[i]];

      // Clear the string buffer
      memset(str_buf, 0, MAX_STR_LEN + 1);

      // Calculate the string length
      int len = offsets_buffer[i + 1] - offsets_buffer[i];

      // Copy the string
      memcpy(str_buf, str, len);

      // Terminate the string
      str_buf[len] = '\0';

      // Perform the regular expression matching   
      regexp_ret = regexec(&regexp, str_buf, 0, NULL, 0);
      if (regexp_ret == 0) {
        matches++;
      }
    }
    
    thread_matches[thread] = matches;
  }
  
  for (int i=0;i<threads;i++) {
    total_matches += thread_matches[i];
  }
  
  return total_matches;
}

/**
 * Copy the example data
 */
int copy_buffers(int slot_id,
                    const uint32_t* offsets_buffer,
                    const char* data_buffer,
                    size_t data_size,
                    uint64_t offsets_offset,
                    uint64_t data_offset,
                    uint32_t rows) {
  int fd, rc;
  char device_file_name[256];
  double start, end;

  fd = -1;

  rc = sprintf(device_file_name, "/dev/edma%i_queue_0", slot_id);
  fail_on((rc = (rc < 0) ? 1 : 0), out, "Unable to format device file name.");
  INF("device_file_name=%s\n", device_file_name);

  /* make sure the AFI is loaded and ready */
  rc = check_slot_config(slot_id);
  fail_on(rc, out, "slot config is not correct");

  fd = open(device_file_name, O_RDWR);
  if (fd < 0) {
    INF(
        "Cannot open device file %s.\nMaybe the EDMA "
            "driver isn't installed, isn't modified to attach to the PCI ID of "
            "your CL, or you're using a device file that doesn't exist?\n"
            "See the edma_install manual at <aws-fpga>/sdk/linux_kernel_drivers/edma/edma_install.md\n"
            "Remember that rescanning your FPGA can change the device file.\n"
            "To remove and re-add your edma driver and reset the device file mappings, run\n"
            "`sudo rmmod edma-drv && sudo insmod <aws-fpga>/sdk/linux_kernel_drivers/edma/edma-drv.ko`\n",
        device_file_name);
    fail_on((rc = (fd < 0) ? 1 : 0), out, "unable to open DMA queue. ");
  }

  INF("Device file opened. Writing strings to buffer.\n");

  uint32_t offsets_size = rows + 1;

  double t_copy = 0;
  INF("Copying offsets buffer: t=");
  start = omp_get_wtime();
  rc = pwrite(fd, offsets_buffer, offsets_size * sizeof(uint32_t), offsets_offset);
  end = omp_get_wtime();
  t_copy += end - start;
  printf(TIME_PRINT, end - start);
  INF("\nCopied %d bytes for offsets buffer. \n", rc);

  INF("Copying data buffer: t=");
  start = omp_get_wtime();
  rc = pwrite(fd, data_buffer, data_size, data_offset);
  end = omp_get_wtime();
  t_copy += end - start;
  printf(TIME_PRINT, end - start);
  INF("\nCopied %d bytes for data buffer. \n", rc);
  INF("Total copy time: %.16g\n", t_copy);

  fsync(fd);

#ifdef DEBUG    
  uint32_t* check_offsets_buffer = (uint32_t*)malloc(offsets_size * sizeof(uint32_t));
  char* check_data_buffer = (char*)malloc(data_size * sizeof(char));

  INF("Reading back data from FPGA on-board DDR:\n");
  rc = pread(fd, check_offsets_buffer, offsets_size * sizeof(uint32_t), offsets_offset);
  rc = pread(fd, check_data_buffer, data_size * sizeof(char), data_offset);

#ifdef PRINT_STRINGS
  print_strings(check_offsets_buffer, check_data_buffer, rows, 0);
#endif

  INF("Memory compare offsets buffer: %d\n", memcmp(offsets_buffer, check_offsets_buffer, offsets_size * sizeof(uint32_t)));
  INF("Memory compare data  buffer: %d\n", memcmp(data_buffer, check_data_buffer, data_size));

  free(check_offsets_buffer);
  free(check_data_buffer);
#endif

  rc = 0;

  out: if (fd >= 0) {
    close(fd);
  }
  /* if there is an error code, exit with status 1 */
  return (rc != 0 ? 1 : 0);
}

/**
 * Configure and run the FPGA regular expression matcher
 */
int count_matches_fpga(uint64_t offsets_address,
                       uint64_t data_address,
                       int32_t firstIdx,
                       int32_t lastIdx,
                       uint32_t * matches,
                       uint32_t rows) {
  int rc;
  int slot_id;
  addr_lohi conv;

  uint32_t result = 0xFFFFFFFF;
  uint32_t status = 0;

  rc = fpga_pci_init();
  fail_on(rc, out, "Unable to initialize the fpga_pci library");
  slot_id = 0;

  int rc_bar1;
  int pf_id = FPGA_APP_PF;
  int bar_id = APP_PF_BAR1;
  pci_bar_handle_t pci_bar_handle = PCI_BAR_HANDLE_INIT;

  rc_bar1 = fpga_pci_attach(slot_id, pf_id, bar_id, 0, &pci_bar_handle);
  fail_on(rc_bar1, out, "Unable to attach to the AFI on slot id %d", slot_id);

  INF("[count_matches_fpga] Initializing registers.\n");

  DBG("Offsets buffer address: %016lX\n", offsets_address);
  DBG("Data buffer address: %016lX\n", data_address);

  // Reset
  rc_bar1 = fpga_pci_poke(pci_bar_handle, CONTROL_REG_LO, CONTROL_RESET);

  // Initialize offsets address
  conv.full = offsets_address;
  rc_bar1 = fpga_pci_poke(pci_bar_handle, CFG_OFF_LO, conv.half.lo);
  rc_bar1 = fpga_pci_poke(pci_bar_handle, CFG_OFF_HI, conv.half.hi);

  // Initialize data address
  conv.full = data_address;
  rc_bar1 = fpga_pci_poke(pci_bar_handle, CFG_DATA_LO, conv.half.lo);
  rc_bar1 = fpga_pci_poke(pci_bar_handle, CFG_DATA_HI, conv.half.hi);

  uint32_t match_rows = lastIdx - firstIdx;
  // Set first and last offset for each unit
  for (int i = 0; i < ACTIVE_UNITS; i++) {
    uint32_t first = firstIdx + i * match_rows / ACTIVE_UNITS;
    uint32_t last = first + match_rows / ACTIVE_UNITS;
    // 4 * for the proper byte address:
    rc_bar1 = fpga_pci_poke(pci_bar_handle, FIRST_IDX_OFF + 4*i, first);
    rc_bar1 = fpga_pci_poke(pci_bar_handle, LAST_IDX_OFF + 4*i, last);
  }

#ifdef DEBUG
  // Check settings:
  DBG("Reading back settings:\n");
  rc_bar1 = fpga_pci_peek(pci_bar_handle, CFG_OFF_HI, &result);
  rc_bar1 = fpga_pci_peek(pci_bar_handle, CFG_OFF_LO, &result);
  rc_bar1 = fpga_pci_peek(pci_bar_handle, CFG_DATA_HI, &result);
  rc_bar1 = fpga_pci_peek(pci_bar_handle, CFG_DATA_LO, &result);

  for (int i=0;i<ACTIVE_UNITS;i++) {
    uint32_t fi, li;
    rc_bar1 = fpga_pci_peek(pci_bar_handle, FIRST_IDX_OFF + 4*i, &fi);
    rc_bar1 = fpga_pci_peek(pci_bar_handle, LAST_IDX_OFF + 4*i, &li);
    DBG("Unit %4d firstIdx - lastIdx : %16d .. %16d\n", i, fi, li);
  }
#endif

  INF("[count_matches_fpga] Starting RegExp matchers and polling until done: ");
  fflush(stdout);

  double start = omp_get_wtime();
  rc_bar1 = fpga_pci_poke(pci_bar_handle, CONTROL_REG_LO, CONTROL_START);

  // Wait until completed - poll status
  do {
#ifdef DEBUG
    // Poll slowly in debug
    sleep(1);
    INF("------------------------------\n");
    rc_bar1 = fpga_pci_peek(pci_bar_handle, STATUS_REG_LO, &status); 
    INF("Status : %08X\n", status);
#else
    // Poll fast
    usleep(10);
    rc_bar1 = fpga_pci_peek(pci_bar_handle, STATUS_REG_LO, &status);
#endif
  } while (status != STATUS_DONE);

  double end = omp_get_wtime();

  INF("FPGA t=");
  printf(TIME_PRINT, end - start);
  INF("\n");

  // Read the return registers (not necessary)
  //rc_bar1 = fpga_pci_peek(pci_bar_handle, 4*RETURN_HI, &result);
  //rc_bar1 = fpga_pci_peek(pci_bar_handle, 4*RETURN_LO, &result);

  uint32_t fpga_matches = 0;

  /* Calculate total matches */
  for (int i = 0; i < ACTIVE_UNITS; i++) {
    rc_bar1 = fpga_pci_peek(pci_bar_handle, (RESULT_OFF + 4 * i), &result);
    INF("Unit %4d result: %d\n", i, result);
    fpga_matches += result;
  }

  *matches = fpga_matches;

  out:
  /* Clean up */
  if (pci_bar_handle >= 0) {
    rc = fpga_pci_detach(pci_bar_handle);
    if (rc) {
      INF("Failure while detaching from the fpga.\n");
    }
  }
  /* if there is an error code, exit with status 1 */
  return (rc != 0 ? 1 : 0);
}

/**
 * Main
 */
int main(int argc, char **argv) {
  const char insstring[] = "kitten";
  const char insstring_regexp[] = ".*[Kk][Ii][Tt][Tt][Ee][Nn].*";
  const char alphabet[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";

  int rc;

  int slot_id = DEFAULT_SLOT_ID;
  int rows = DEFAULT_ROWS;

  switch (argc) {
  case 1:
    break;
  case 2:
    sscanf(argv[1], "%u", &rows);
    if (rows < 0) {
      usage(argv[0]);
      return 1;
    }
    break;
  case 3:
    sscanf(argv[1], "%d", &rows);
    sscanf(argv[2], "%x", &slot_id);
    break;
  default:
    usage(argv[0]);
    return 1;
  }
  
  /* Setup logging to print to stdout */
  rc = log_init("test_arrow_utf8");
  fail_on(rc, out, "Unable to initialize the log.");
  rc = log_attach(logger, NULL, 0);
  fail_on(rc, out, "%s", "Unable to attach to the log.");

  /* Initialize the fpga_plat library */
  INF("Initializing FPGA management library\n");
  rc = fpga_mgmt_init();
  fail_on(rc, out, "Unable to initialize the fpga_mgmt library");

  double start, end;

  /* Generate the offsets and data buffer */
  uint32_t* offsets_buffer;
  char* data_buffer;
  size_t data_size;

  INF("Generating random strings containing %s\n", insstring);
  start = omp_get_wtime();
  int insertions = gen_rand_strings_with(insstring, alphabet, &offsets_buffer, &data_buffer, &data_size, rows);
  end = omp_get_wtime();
  printf(TIME_PRINT, end - start);

#ifdef DEBUG
#ifdef PRINT_STRINGS
  print_strings(offsets_buffer, data_buffer, rows, 0);
#endif
#endif
  INF("  Generated %d strings of which %d contain at least one deliberately inserted \"%s\".\n", rows, insertions, insstring);
  INF("  It could be that more generated strings randomly contain it, especially in a large number of strings.\n");
  
  /* Match the strings on CPU */
  start = omp_get_wtime();
#ifdef USE_OMP
  INF("RegExping on CPU in parallel: t=");
  uint32_t cpu_matches = count_matches_omp(offsets_buffer, data_buffer, insstring_regexp, rows, 0);
#else
  INF("RegExping on CPU on single core: t=");
  uint32_t cpu_matches = count_matches_cpu(offsets_buffer, data_buffer, insstring_regexp, rows);
#endif
  end = omp_get_wtime();
  printf(TIME_PRINT, end - start);
  INF("\nCPU RegExp matches %s %d times.\n", insstring_regexp, cpu_matches);

  /* Calculate the location of the buffers in the on-board memory */
  // Buffers must be aligned to burst boundaries (Currently a Fletcher spec, this will be changed to Arrow alignment spec)
  uint64_t offsets_addr = (uint64_t)(0);
  uint64_t data_addr = (uint64_t)(offsets_addr + ((rows * sizeof(uint32_t)) / BURST_LENGTH + 1) * BURST_LENGTH);
  
  /* Copy the buffers to FPGA on-board memory */
  INF("Copy data to FPGA on-board memory.\n");
  rc = copy_buffers(slot_id, offsets_buffer, data_buffer, data_size, offsets_addr, data_addr, rows);
  fail_on(rc, out, "Data copy failed");

  sleep(1);

  /* Perform regular expression matching on FPGA */
  INF("RegExping on FPGA\n");
  uint32_t fpga_matches = 0xFFFFFFFF;
  rc = count_matches_fpga(offsets_addr, data_addr, 0, rows, &fpga_matches, rows);
  INF("FPGA RegExp matches %s %d times.\n", insstring_regexp, fpga_matches);
  
  printf("%16lu, %16d, %16d, %16d, %16d\n", sizeof(uint32_t) * (rows+1), (uint32_t)data_size, cpu_matches, fpga_matches, insertions);
  
  if (fpga_matches == cpu_matches) {
    INF("TEST PASSED\n");
  } else {
    INF("TEST FAILED\n");
  }

  fail_on(rc, out, "Data copy failed");

  out: if (offsets_buffer != NULL) {
    free(offsets_buffer);
  }
  if (data_buffer != NULL) {
    free(data_buffer);
  }
  return rc;
}
