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
 * This example generated a small number of strings containing the word "kitten"
 * in two buffers, an offsets and data buffer, according to the Apache Arrow format
 * specification. Then, it continues to copy the buffers to the on-board DDR memory
 * and runs at most sixteen regular expression matching units and reports the
 * number of matches for each units, and in total.
 */

// Register offsets & some default values:
`define REG_STATUS_HI       0
`define REG_STATUS_LO       1
`define   STATUS_BUSY       32'h00000002
`define   STATUS_DONE       32'h00000005

`define REG_CONTROL_HI      2
`define REG_CONTROL_LO      3
`define   CONTROL_START     32'h00000001
`define   CONTROL_RESET     32'h00000004

`define REG_RETURN_HI       4
`define REG_RETURN_LO       5

`define REG_OFF_ADDR_HI     6
`define REG_OFF_ADDR_LO     7

// Register offset to the first & last indices of each RegExp unit:
`define REG_FIRST_IDX       9
`define REG_LAST_IDX        11

`define NUM_REGISTERS       12

// Offset buffer address
`define OFF_ADDR_HI         32'h00000000
`define OFF_ADDR_LO         32'h00000000

`define NUM_ROWS            512

module test_arrow_sum();

import tb_type_defines_pkg::*;

int         error_count;
int         timeout_count;
int         fail;
logic [3:0] status;
logic       ddr_ready;
int         read_data;

int num_rows = `NUM_ROWS;
int num_buf_bytes = num_rows * 8;  // 64-bit integers
int temp;

union {
  logic[63:0] i;
  logic[7:0][7:0] bytes;
} buf_data;

initial begin

  logic[63:0] buffer_address;

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

  for (int i=0; i<`NUM_REGISTERS; i++) begin
//    $display("[DEBUG] : Reading register %d", i);
    tb.peek_bar1(.addr(i*4), .data(read_data));
    $display("[DEBUG] : Register %d: %H", i, read_data);
  end

  $display("[%t] : Initializing buffers", $realtime);

  buffer_address = {`OFF_ADDR_HI, `OFF_ADDR_LO};

  // Queue the data movement
  tb.que_buffer_to_cl(
    .chan(0),
    .src_addr(buffer_address),
    .cl_addr(64'h0000_0000_0000),
    .len(num_buf_bytes)
  );

  // Set a random seed
  $srandom(0);

  // Fill the buffer with random numbers
  for (int i = 0; i < num_rows; i++) begin
    buf_data.i = i * 7;  // sum == 7 * (x/2 (1 + x))
    tb.hm_put_byte(.addr(buffer_address + 8 * i    ), .d(buf_data.bytes[0]));
    tb.hm_put_byte(.addr(buffer_address + 8 * i + 1), .d(buf_data.bytes[1]));
    tb.hm_put_byte(.addr(buffer_address + 8 * i + 2), .d(buf_data.bytes[2]));
    tb.hm_put_byte(.addr(buffer_address + 8 * i + 3), .d(buf_data.bytes[3]));
    tb.hm_put_byte(.addr(buffer_address + 8 * i + 4), .d(buf_data.bytes[4]));
    tb.hm_put_byte(.addr(buffer_address + 8 * i + 5), .d(buf_data.bytes[5]));
    tb.hm_put_byte(.addr(buffer_address + 8 * i + 6), .d(buf_data.bytes[6]));
    tb.hm_put_byte(.addr(buffer_address + 8 * i + 7), .d(buf_data.bytes[7]));
  end

  $display("[%t] : Starting host to CL DMA transfers ", $realtime);

  // Start transfers of data to CL DDR
  tb.start_que_to_cl(.chan(0));

  // Wait for dma transfers to complete,
  // increase the timeout if you have to transfer a lot of data
  timeout_count = 0;
  do begin
    status[0] = tb.is_dma_to_cl_done(.chan(0));
    #10ns;
    timeout_count++;
  end while ((status != 4'hf) && (timeout_count < 4000));

  if (timeout_count >= 4000) begin
    $display(
      "[%t] : *** ERROR *** Timeout waiting for dma transfers from cl",
      $realtime
    );
    error_count++;
  end

  tb.nsec_delay(1000);

  // Fletcher sum example starts here
  $display("[%t] : Initializing UserCore ", $realtime);

  // Reset
  tb.poke_bar1(.addr(4*`REG_CONTROL_LO), .data(`CONTROL_RESET));

  // Initialize buffer addressess
  tb.poke_bar1(.addr(4*`REG_OFF_ADDR_HI), .data(`OFF_ADDR_HI));
  tb.poke_bar1(.addr(4*`REG_OFF_ADDR_LO), .data(`OFF_ADDR_LO));

  // Set first and last row index
  tb.poke_bar1(.addr(4 * (`REG_FIRST_IDX)), .data(0));
  tb.poke_bar1(.addr(4 * (`REG_LAST_IDX)), .data(`NUM_ROWS));

  $display("[%t] : Starting UserCore", $realtime);

  // Start UserCore
  tb.poke_bar1(.addr(4*`REG_CONTROL_LO), .data(`CONTROL_START));

  // Poll status at an interval of 5000 nsec
  // For the real thing, you should probably increase this to put 
  // less stress on the PCI interface
  do
    begin
      tb.nsec_delay(5000);
      tb.peek_bar1(.addr(4*`REG_STATUS_LO), .data(read_data));
      $display("[%t] : UserCore status: %H", $realtime, read_data);
    end
  while(read_data !== `STATUS_DONE);

  $display("[%t] : UserCore completed ", $realtime);

  // Get the return register value
  tb.peek_bar1(.addr(4*`REG_RETURN_HI), .data(read_data));
  $display("[t] : Return register HI: %d", read_data);
  tb.peek_bar1(.addr(4*`REG_RETURN_LO), .data(read_data));
  $display("[t] : Return register LO: %d", read_data);

  // Power down
  #500ns;
  tb.power_down();

  // Report pass/fail status
  $display("[%t] : Checking total error count...", $realtime);
  if (error_count > 0) begin
    fail = 1;
  end
  $display(
    "[%t] : Detected %3d errors during this test",
    $realtime, error_count
  );

  if (fail || (tb.chk_prot_err_stat())) begin
    $display("[%t] : *** TEST FAILED ***", $realtime);
  end else begin
    $display("[%t] : *** TEST PASSED ***", $realtime);
  end

  $finish;
end // initial begin

endmodule // test_arrow_sum
