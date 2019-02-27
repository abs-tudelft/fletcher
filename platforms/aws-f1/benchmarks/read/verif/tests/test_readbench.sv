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
`define REG_CONTROL         0
`define   CONTROL_START     32'h00000001
`define   CONTROL_STOP      32'h00000002
`define   CONTROL_RESET     32'h00000004

`define REG_STATUS          1
`define   STATUS_IDLE       32'h00000001
`define   STATUS_BUSY       32'h00000002
`define   STATUS_DONE       32'h00000004

`define REG_BURST_LENGTH    2
`define REG_MAX_BURSTS      3
`define REG_BASE_ADDR_LO    4
`define REG_BASE_ADDR_HI    5
`define REG_ADDR_MASK_LO    6
`define REG_ADDR_MASK_HI    7
`define REG_CYCLES          8
`define REG_CHECKSUM        9

`define NUM_REGISTERS       10

// Region address for fpga memory (must be 4Ki aligned)
`define BASE_ADDR_LO        32'h00000000
`define BASE_ADDR_HI        32'h00000000

`define ADDR_MASK_LO        32'h00fff000
`define ADDR_MASK_HI        32'h00000000

`define MAX_BURSTS          256
`define BURST_LENGTH        16

module test_readbench();

import tb_type_defines_pkg::*;

int         error_count;
int         timeout_count;
int         fail;
logic [3:0] status;
logic       ddr_ready;
int         read_data;

int temp;

union {
  logic[63:0] i;
  logic[7:0][7:0] bytes;
} buf_data;

union {
  logic[31:0] i;
  logic[3:0][7:0] bytes;
} off_data;

initial begin

  // Power up the testbench
  tb.power_up(.clk_recipe_a(ClockRecipe::A1),
              .clk_recipe_b(ClockRecipe::B0),
              .clk_recipe_c(ClockRecipe::C0));

  tb.nsec_delay(1000);

  tb.poke_stat(.addr(8'h0c), .ddr_idx(0), .data(32'h0000_0000));
  tb.poke_stat(.addr(8'h0c), .ddr_idx(1), .data(32'h0000_0000));
  tb.poke_stat(.addr(8'h0c), .ddr_idx(2), .data(32'h0000_0000));

  // Allow memory to initialize.
  // Can be ignored when make TEST=... AXI_MEMORY_MODEL=1
  // However, AXI_MEMORY_MODEL=1 is not an AXI compliant memory model as it 
  // doesn't properly support independent request and data channels.
  tb.nsec_delay(27000);
        
  $display("[%t] : Initializing Benchmark ", $realtime);

  // Reset
  tb.poke_bar1(.addr(4*`REG_CONTROL), .data(`CONTROL_RESET));
  tb.poke_bar1(.addr(4*`REG_CONTROL), .data(0));

  // Initialize registers
  tb.poke_bar1(.addr(4*`REG_BASE_ADDR_LO), .data(`BASE_ADDR_LO));
  tb.poke_bar1(.addr(4*`REG_BASE_ADDR_HI), .data(`BASE_ADDR_HI));
  tb.poke_bar1(.addr(4*`REG_ADDR_MASK_LO), .data(`ADDR_MASK_LO));
  tb.poke_bar1(.addr(4*`REG_ADDR_MASK_HI), .data(`ADDR_MASK_HI));
  
  tb.poke_bar1(.addr(4*`REG_BURST_LENGTH), .data(`BURST_LENGTH));
  tb.poke_bar1(.addr(4*`REG_MAX_BURSTS),   .data(`MAX_BURSTS));
  

  $display("[%t] : Starting BusReadBenchmarker", $realtime);

  // Start UserCore
  tb.poke_bar1(.addr(4*`REG_CONTROL), .data(`CONTROL_START));

  // Poll status at an interval of 1000 nsec
  // For the real thing, you should probably increase this to put 
  // less stress on the PCI interface
  do
    begin
      tb.nsec_delay(1000);
      tb.peek_bar1(.addr(4*`REG_STATUS), .data(read_data));
      $display("[%t] : BusReadBenchmarker status: 0x%H", $realtime, read_data);
    end
  while(read_data !== `STATUS_DONE);

  $display("[%t] : BusReadBenchmarker completed ", $realtime);

  tb.nsec_delay(10000);

  $display("Cycles: ");
  tb.peek_bar1(.addr(4*`REG_CYCLES), .data(read_data));
  $display("[%t] : Read cycles: 0x%H", $realtime, read_data);

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

endmodule // test_readbench
