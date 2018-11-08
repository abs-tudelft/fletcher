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


// Register offsets & some default values:
`define REG_STATUS          1
`define   STATUS_BUSY       32'h00000002
`define   STATUS_DONE       32'h00000005

`define REG_CONTROL         0
`define   CONTROL_START     32'h00000001
`define   CONTROL_RESET     32'h00000004

`define REG_RETURN_HI       3
`define REG_RETURN_LO       2

`define REG_OFF_ADDR_HI     4+3
`define REG_OFF_ADDR_LO     4+2

`define REG_DATA_ADDR_HI    4+5
`define REG_DATA_ADDR_LO    4+4

// Registers for first and last (exclusive) row index
`define REG_FIRST_IDX       4+0
`define REG_LAST_IDX        4+1

`define NUM_REGISTERS       8

// Offset buffer address for fpga memory (must be 4k aligned)
`define OFF_ADDR_HI         32'h00000000
`define OFF_ADDR_LO         32'h00000000
`define DATA_ADDR_HI        32'h00000000
`define DATA_ADDR_LO        32'h00000040
// Offset buffer address in host memory
`define HOST_ADDR           64'h0000000000000000

`define NUM_ROWS            5

module test_arrow_kmeans();

import tb_type_defines_pkg::*;

int         error_count;
int         timeout_count;
int         fail;
logic [3:0] status;
logic       ddr_ready;
int         read_data;

int num_rows = `NUM_ROWS;
int num_buf_bytes = 192;
int temp;

union {
  logic[63:0] i;
  logic[7:0][7:0] bytes;
} buf_data;

initial begin

  logic[63:0] host_buffer_address;
  logic[63:0] cl_buffer_address;

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

  host_buffer_address = `HOST_ADDR;
  cl_buffer_address = {`OFF_ADDR_HI, `OFF_ADDR_LO};

  // Queue the data movement
  tb.que_buffer_to_cl(
    .chan(0),
    .src_addr(host_buffer_address),
    .cl_addr(cl_buffer_address),
    .len(num_buf_bytes)
  );

  `include "intlist.sv"

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
  tb.poke_bar1(.addr(4*`REG_CONTROL), .data(`CONTROL_RESET));

  // Initialize buffer addressess
  tb.poke_bar1(.addr(4 * (`REG_OFF_ADDR_HI)), .data(`OFF_ADDR_HI));
  tb.poke_bar1(.addr(4 * (`REG_OFF_ADDR_LO)), .data(`OFF_ADDR_LO));

  tb.poke_bar1(.addr(4 * (`REG_DATA_ADDR_HI)), .data(`DATA_ADDR_HI));
  tb.poke_bar1(.addr(4 * (`REG_DATA_ADDR_LO)), .data(`DATA_ADDR_LO));

  // Set first and last row index
  tb.poke_bar1(.addr(4 * (`REG_FIRST_IDX)), .data(0));
  tb.poke_bar1(.addr(4 * (`REG_LAST_IDX)), .data(`NUM_ROWS));

  // Set starting centroids
  tb.poke_bar1(.addr(4*10), .data(0));
  tb.poke_bar1(.addr(4*11), .data(0));
  tb.poke_bar1(.addr(4*12), .data(0));
  tb.poke_bar1(.addr(4*13), .data(0));

  tb.poke_bar1(.addr(4*14), .data(40));
  tb.poke_bar1(.addr(4*15), .data(0));
  tb.poke_bar1(.addr(4*16), .data(-100));
  tb.poke_bar1(.addr(4*17), .data(-1));

  // Set maximum number of iterations
  tb.poke_bar1(.addr(4*18), .data(4));


  $display("[%t] : Starting UserCore", $realtime);

  // Start UserCore
  tb.poke_bar1(.addr(4*`REG_CONTROL), .data(`CONTROL_START));

  // Poll status at an interval of 1000 nsec
  // For the real thing, you should probably increase this to put 
  // less stress on the PCI interface
  do
    begin
      tb.nsec_delay(1000);
      tb.peek_bar1(.addr(4*`REG_STATUS), .data(read_data));
      $display("[%t] : UserCore status: %H", $realtime, read_data);
    end
  while(read_data !== `STATUS_DONE);

  $display("[%t] : UserCore completed ", $realtime);

  // Get the return register value
  tb.peek_bar1(.addr(4*`REG_RETURN_HI), .data(read_data));
  $display("[t] : Return register HI: %d", read_data);
  if (read_data != 0) begin
    $display("[t] : ERROR: Expected 0 on return HI");
    fail = 1;
  end
  tb.peek_bar1(.addr(4*`REG_RETURN_LO), .data(read_data));
  $display("[t] : Return register LO: %d", read_data);
  if (read_data != 7 * (num_rows * (num_rows - 1)) / 2) begin
    $display("[t] : ERROR: Result does not match expected %d", 7 * (num_rows * (num_rows - 1)) / 2);
    fail = 1;
  end

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
