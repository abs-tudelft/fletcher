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

`define K_COLUMNS           8
`define K_CENTROIDS         4

`define NUM_REGISTERS       11 + 2 * `K_COLUMNS * `K_CENTROIDS

// Offset buffer address for fpga memory (must be 4k aligned)
`define OFF_ADDR_HI         32'h00000000
`define OFF_ADDR_LO         32'h00000000
`define DATA_ADDR_HI        32'h00000000
`define DATA_ADDR_LO        32'h00000040
// Offset buffer address in host memory
`define HOST_ADDR           64'h0000000000000000

`define NUM_ROWS            6

module test_arrow_kmeans3();

import tb_type_defines_pkg::*;

int         error_count;
int         timeout_count;
int         fail;
logic [3:0] status;
logic       ddr_ready;
int         read_data;

int num_rows = `NUM_ROWS;
int num_buf_bytes = 384;
int temp;

// 21 24 -34 120 242 140
// 1  1   0   2   3   2

int centroid_ref[`K_CENTROIDS][2 * `K_COLUMNS] =
    '{'{-34,-1,0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0},
      '{ 22,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0},
      '{130,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0},
      '{242,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0}};

int centroid_init[`K_CENTROIDS][2 * `K_COLUMNS] =
    '{'{ 21,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0},
      '{ 24,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0},
      '{120,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0},
      '{242,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0}};

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

  `include "intlistwide3.sv"

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
  for (int c=0; c<`K_CENTROIDS; c++) begin
    for (int d=0; d<`K_COLUMNS; d++) begin
        tb.poke_bar1(.addr(4 * (10 + 2*(c * `K_COLUMNS + d))),     .data(centroid_init[c][2*d]));
        tb.poke_bar1(.addr(4 * (10 + 2*(c * `K_COLUMNS + d) + 1)), .data(centroid_init[c][2*d+1]));
    end
  end

  // Set maximum number of iterations
  tb.poke_bar1(.addr(4*(`NUM_REGISTERS-1)), .data(4));

  // Start UserCore
  $display("[%t] : Starting UserCore", $realtime);
  tb.poke_bar1(.addr(4*`REG_CONTROL), .data(`CONTROL_START));

  // Poll status at an interval of 2000 nsec
  // For the real thing, you should probably increase this to put 
  // less stress on the PCI interface
  do
    begin
      tb.nsec_delay(2000);
      tb.peek_bar1(.addr(4*`REG_STATUS), .data(read_data));
      $display("[%t] : UserCore status: %H", $realtime, read_data);
    end
  while(read_data !== `STATUS_DONE);

  $display("[%t] : UserCore completed ", $realtime);


  // Check outputs
  for (int c=0; c<`K_CENTROIDS; c++) begin
    for (int d=0; d<`K_COLUMNS; d++) begin
        tb.peek_bar1(.addr(4 * (10 + 2*(c * `K_COLUMNS + d))), .data(read_data));
        if (read_data != centroid_ref[c][2*d]) begin
          $display("ERROR: Result incorrect (centroid %d, column %d LO): %H; expected %H", c, d, read_data, centroid_ref[c][2*d]);
          error_count++;
        end
        tb.peek_bar1(.addr(4 * (10 + 2*(c * `K_COLUMNS + d) + 1)), .data(read_data));
        if (read_data != centroid_ref[c][2*d + 1]) begin
          $display("ERROR: Result incorrect (centroid %d, column %d HI): %H; expected %H", c, d, read_data, centroid_ref[c][2*d+1]);
          error_count++;
        end
    end
  end

  tb.peek_bar1(.addr(4*(`NUM_REGISTERS-1)), .data(read_data));
  if (read_data != 1) begin
    $display("ERROR: Result incorrect (iterations): %d", read_data);
    error_count++;
  end


  // Report pass/fail status
  $display("[%t] : Checking total error count...", $realtime);
  if (error_count > 0) begin
    fail = 1;
    // Debug print of all registers
    for (int i=0; i<`NUM_REGISTERS; i++) begin
      tb.peek_bar1(.addr(i*4), .data(read_data));
      $display("[DEBUG] : Register %d: %H", i, read_data);
    end
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


  // Power down
  #500ns;
  tb.power_down();

  $finish;
end // initial begin

endmodule // test_arrow_sum
