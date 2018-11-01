/*
 * Copyright 2017 International Business Machines
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef __SNAP_FW_EXA__
#define __SNAP_FW_EXA__

/*
 * This makes it obvious that we are influenced by HLS details ...
 * The ACTION control bits are defined in the following file.
 */
#include <snap_hls_if.h>

/* Header file for SNAP Framework example code */
#define ACTION_TYPE_EXAMPLE     0x00000001	/* Action Type */

#define ACTION_CONFIG           0x30
#define ACTION_CONFIG_COUNT     1       /* Count Mode */
#define ACTION_CONFIG_COPY_HH   2       /* Memcopy Host to Host */
#define ACTION_CONFIG_COPY_HD   3       /* Memcopy Host to DDR */
#define ACTION_CONFIG_COPY_DH   4       /* Memcopy DDR to Host */
#define ACTION_CONFIG_COPY_DD   5       /* Memcopy DDR to DDR */
#define ACTION_CONFIG_COPY_HDH  6       /* Memcopy Host to DDR to Host */
#define ACTION_CONFIG_MEMSET_H  8       /* Memset Host Memory */
#define ACTION_CONFIG_MEMSET_F  9       /* Memset FPGA Memory */
#define ACTION_CONFIG_COPY_DN   0x0a    /* Copy DDR to NVME drive 0 */
#define ACTION_CONFIG_COPY_ND   0x0b    /* Copy NVME drive 0 to DDR */
#define NVME_DRIVE1		          0x10	  /* Select Drive 1 for 0a and 0b */

#define ACTION_SRC_LOW          0x34	  /* LBA for 0A, 1A, 0B and 1B */
#define ACTION_SRC_HIGH         0x38
#define ACTION_DEST_LOW         0x3c	  /* LBA for 0A, 1A, 0B and 1B */
#define ACTION_DEST_HIGH        0x40
#define ACTION_CNT              0x44    /* Count Register or # of 512 Byte Blocks for NVME */

/* No units */
#define TOTAL_UNITS     16
#define ACTIVE_UNITS    8

#define SNAP_OFFSET     0x200

/* Default registers */
#define REG_STATUS      	SNAP_OFFSET + 0
#define REG_STATUS_MASK		0x0000FFFF
#define REG_STATUS_BUSY 	0x000000FF
#define REG_STATUS_DONE 	0x0000FF00

#define REG_CONTROL			SNAP_OFFSET + 4
#define REG_CONTROL_START 	0x000000FF
#define REG_CONTROL_RESET 	0x0000FF00

#define REG_RETURN0         SNAP_OFFSET + 8
#define REG_RETURN1         SNAP_OFFSET + 12

#define REG_FIRSTIDX        SNAP_OFFSET + 16
#define REG_LASTIDX         SNAP_OFFSET + 20

/* Application specific registers */
#define REG_OFF_ADDR_LO     SNAP_OFFSET + 24
#define REG_OFF_ADDR_HI     SNAP_OFFSET + 28

#define REG_UTF8_ADDR_LO    SNAP_OFFSET + 32
#define REG_UTF8_ADDR_HI    SNAP_OFFSET + 36

#define REG_CUST_FIRST_IDX  SNAP_OFFSET + 40
#define REG_CUST_LAST_IDX   REG_CUST_FIRST_IDX + 4*TOTAL_UNITS

#define REG_RESULT      	REG_CUST_LAST_IDX + 4*TOTAL_UNITS

/* Data sizes */
#define MIN_STR_LEN     6
#define MAX_STR_LEN     256
#define DEFAULT_ROWS    8*1024*1024

/* Burst step length in bytes */
#define BURST_LENGTH    64


#endif	/* __SNAP_FW_EXA__ */

