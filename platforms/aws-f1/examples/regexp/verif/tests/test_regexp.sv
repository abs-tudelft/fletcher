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

/**
 * Fletcher RegExp example test-bench
 *
 * This example loads some strings from a file into an offsets and data buffer, 
 * according to the Apache Arrow format specification. Then, it continues to 
 * copy the buffers to the on-board DDR memory and runs at most sixteen 
 * regular expression matching units and reports the number of matches for 
 * each unit.
 */

// Register offsets & some default values:
`define REG_CONTROL         0
`define   CONTROL_START     32'h0000FFFF
`define   CONTROL_RESET     32'hFFFF0000

`define REG_STATUS          1
`define   STATUS_BUSY       32'h0000FFFF
`define   STATUS_DONE       32'hFFFF0000

`define REG_FIRSTIDX        2
`define REG_LASTIDX         3

`define REG_RETURN0         4
`define REG_RETURN1         5

`define REG_OFF_ADDR_LO     6
`define REG_OFF_ADDR_HI     7

`define REG_UTF8_ADDR_LO    8
`define REG_UTF8_ADDR_HI    9

// Register offset to the first & last indices of each RegExp unit:
`define REG_CUST_FIRST_IDX  10
`define REG_CUST_LAST_IDX   26

// Register offset to the results of each RegExp unit:
`define REG_RESULT          42

// Maximum string length; must be larger than the length of the string we're inserting randomly
`define MAX_STR_LEN         256

// Number of rows, currently must be a multiple of the no. active units
// because of the naive way in which the work is distributed amongst the units.
// If you change the test file, you should probably also change this.
// TODO: make this dynamic
`define NUM_ROWS            64

// Currently we require the buffers to be aligned to the burst size
`define ALIGNMENT           4096

// Offset buffer address
`define OFF_ADDR_HI         32'h00000000
`define OFF_ADDR_LO         32'h00000000

// Calculate aligned addresses
`define UTF8_ADDR_HI        32'h00000000
`define UTF8_ADDR_LO        ((`NUM_ROWS * 4) / `ALIGNMENT + 1) * `ALIGNMENT

// Placeholder for potential result writeback
`define DEST_ADDR_HI        32'h00000000
`define DEST_ADDR_LO        `UTF8_ADDR_LO + ((`NUM_ROWS * `MAX_STR_LEN) / `ALIGNMENT + 1) * `ALIGNMENT

// Number of active units
`define ACTIVE_UNITS        16

// Number of regexes performed in parallel
`define NUM_REGEX           16

module test_regexp();

import tb_type_defines_pkg::*;

int         error_count;
int         timeout_count;
int         fail;
logic [3:0] status;
logic       ddr_ready;
int         read_data;

int num_rows = `NUM_ROWS;
int num_buf_bytes = num_rows * 4               // For indices
                  + num_rows * `MAX_STR_LEN;   // For characters

// Variables for file loading
int file_descriptor = 0;
string str;

// Variables to build up the Arrow buffers
int offset_index = 0;
int offset_value = 0;

union {
  logic[31:0] i;
  logic[3:0][7:0] bytes;
} buf_data;

initial begin

  logic[63:0] off_buffer_address;
  logic[63:0] utf8_buffer_address;
  logic[7:0] utf8;

  // Power up the testbench
  tb.power_up(.clk_recipe_a(ClockRecipe::A1),
              .clk_recipe_b(ClockRecipe::B0),
              .clk_recipe_c(ClockRecipe::C0));

  tb.nsec_delay(1000);

  tb.poke_stat(.addr(8'h0c), .ddr_idx(0), .data(32'h0000_0000));
  tb.poke_stat(.addr(8'h0c), .ddr_idx(1), .data(32'h0000_0000));
  tb.poke_stat(.addr(8'h0c), .ddr_idx(2), .data(32'h0000_0000));

  // Allow memory to initialize
  tb.nsec_delay(27000);

  $display("[%t] : Initializing buffers", $realtime);

  // Determine buffer addresses
  off_buffer_address = {`OFF_ADDR_HI, `OFF_ADDR_LO};
  utf8_buffer_address = {`UTF8_ADDR_HI, `UTF8_ADDR_LO};

  // Queue the data move,emt
  tb.que_buffer_to_cl(.chan(0), .src_addr(off_buffer_address), .cl_addr(64'h0000_0000_0000), .len(num_buf_bytes) );

  // Load file
  file_descriptor=$fopen("test.txt","r");

  // Only proceed if the file is opened
  if (file_descriptor) begin

    offset_index = 0;
    offset_value = 0;

    // Write the first offset
    buf_data.i = offset_value;
    tb.hm_put_byte(.addr(off_buffer_address + 4 * offset_index    ), .d(buf_data.bytes[0]));
    tb.hm_put_byte(.addr(off_buffer_address + 4 * offset_index + 1), .d(buf_data.bytes[1]));
    tb.hm_put_byte(.addr(off_buffer_address + 4 * offset_index + 2), .d(buf_data.bytes[2]));
    tb.hm_put_byte(.addr(off_buffer_address + 4 * offset_index + 3), .d(buf_data.bytes[3]));
    offset_index++;

    while (! $feof(file_descriptor)) begin
      // Load a line
      $fgets(str, file_descriptor);

      // Write each character of the string to the values buffer, except the newline character
      for(int c = 0; c < str.len()-1; c++) begin
        tb.hm_put_byte(.addr(utf8_buffer_address + offset_value + c), .d(str.getc(c)));
      end

      // Throw line on terminal for debugging
      $write("%6d, 0x%016X, 0x%08X, %6d, %s", offset_index, off_buffer_address + 4 * offset_index, offset_value, offset_value, str);

      // Calculate the next offset value
      offset_value = offset_value + str.len()-1;

      // Write the next offset
      buf_data.i = offset_value;
      tb.hm_put_byte(.addr(off_buffer_address + 4 * offset_index    ), .d(buf_data.bytes[0]));
      tb.hm_put_byte(.addr(off_buffer_address + 4 * offset_index + 1), .d(buf_data.bytes[1]));
      tb.hm_put_byte(.addr(off_buffer_address + 4 * offset_index + 2), .d(buf_data.bytes[2]));
      tb.hm_put_byte(.addr(off_buffer_address + 4 * offset_index + 3), .d(buf_data.bytes[3]));
      offset_index++;
    end
  end else begin
    $display("Could not open test file.\n");
    $finish;
  end

  $display("[%t] : Starting host to CL DMA transfers ", $realtime);

  // Start transfers of data to CL DDR
  tb.start_que_to_cl(.chan(0));

  // Wait for dma transfers to complete, increase the timeout if you
  // have a lot of string or if you have very long strings (if you
  // have to transfer a lot of data in general)
  timeout_count = 0;
  do begin
    status[0] = tb.is_dma_to_cl_done(.chan(0));
    #10ns;
    timeout_count++;
  end while ((status != 4'hf) && (timeout_count < 4000));

  if (timeout_count >= 4000) begin
    $display("[%t] : *** ERROR *** Timeout waiting for dma transfers from cl", $realtime);
    error_count++;
  end

  tb.nsec_delay(1000);

  // Fletcher RegExp example starts here:
  $display("[%t] : Initializing UserCore ", $realtime);

  // Put the units in reset:
  tb.poke_bar1(.addr(4*`REG_CONTROL), .data(`CONTROL_RESET));

  // Initialize buffer addressess:
  tb.poke_bar1(.addr(4*`REG_OFF_ADDR_LO), .data(`OFF_ADDR_LO));
  tb.poke_bar1(.addr(4*`REG_OFF_ADDR_HI), .data(`OFF_ADDR_HI));
  tb.poke_bar1(.addr(4*`REG_UTF8_ADDR_LO), .data(`UTF8_ADDR_LO));
  tb.poke_bar1(.addr(4*`REG_UTF8_ADDR_HI), .data(`UTF8_ADDR_HI));

  // Set first and last row index for each unit
  for (int i = 0; i < `ACTIVE_UNITS; i++) begin
    tb.poke_bar1(.addr(4 * (`REG_CUST_FIRST_IDX + i)), .data(i * `NUM_ROWS/`ACTIVE_UNITS));
  end
  for (int i = 0; i < `ACTIVE_UNITS; i++) begin
    tb.poke_bar1(.addr(4 * (`REG_CUST_LAST_IDX + i)), .data((i + 1) * `NUM_ROWS/`ACTIVE_UNITS));
  end

  $display("[%t] : Starting UserCore", $realtime);

  // Start UserCore, taking units out of reset
  tb.poke_bar1(.addr(4*`REG_CONTROL), .data(`CONTROL_START));

  // Poll status at an interval of 5000 nsec
  // For the real thing, you should probably increase this to put
  // less stress on the PCI interface
  do
    begin
      tb.nsec_delay(5000);
      tb.peek_bar1(.addr(4*`REG_STATUS), .data(read_data));
      $display("[%t] : UserCore status: %H", $realtime, read_data);
    end
  while(read_data !== `STATUS_DONE);

  $display("[%t] : UserCore completed ", $realtime);

  // Get the result for each RegExp
  for (int i = 0; i < `NUM_REGEX; i++) begin
    tb.peek_bar1(.addr(4*(`REG_RESULT+i)), .data(read_data));
    $display("[%t] : Number of matches for RegExp %2d: %2d", $realtime, i, read_data);
  end

  // Get the return register value
  tb.peek_bar1(.addr(4*`REG_RETURN0), .data(read_data));
  $display("[%t] : Return register 0: %d", $realtime, read_data);
  tb.peek_bar1(.addr(4*`REG_RETURN1), .data(read_data));
  $display("[%t] : Return register 1: %d", $realtime, read_data);

  // Power down
  #500ns;
  tb.power_down();

  // Report pass/fail status
  $display("[%t] : Checking total error count...", $realtime);
  if (error_count > 0) begin
    fail = 1;
  end
  $display("[%t] : Detected %3d errors during this test", $realtime, error_count);

  if (fail || (tb.chk_prot_err_stat())) begin
    $display("[%t] : *** TEST FAILED ***", $realtime);
  end else begin
    $display("[%t] : *** TEST PASSED ***", $realtime);
  end

  $finish;
end // initial begin

endmodule // test_regexp
