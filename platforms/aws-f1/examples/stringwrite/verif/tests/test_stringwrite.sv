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
`define REG_STATUS          1
`define   STATUS_IDLE       32'h00000001
`define   STATUS_BUSY       32'h00000002
`define   STATUS_DONE       32'h00000004

`define REG_CONTROL         0
`define   CONTROL_START     32'h00000001
`define   CONTROL_RESET     32'h00000004

`define REG_RETURN_LO           2
`define REG_RETURN_HI           3
`define REG_FIRST_IDX           4
`define REG_LAST_IDX            5
`define REG_STRING_OFF_ADDR_LO  6
`define REG_STRING_OFF_ADDR_HI  7
`define REG_STRING_VAL_ADDR_LO  8
`define REG_STRING_VAL_ADDR_HI  9
`define REG_STRLEN_MIN         10
`define REG_PRNG_MASK          11

`define NUM_REGISTERS       12

// Offset buffer address for fpga memory (must be 4Ki aligned)
`define OFF_ADDR_LO         32'h00001000
`define OFF_ADDR_HI         32'h00000000

`define VAL_ADDR_LO         32'h00004000
`define VAL_ADDR_HI         32'h00000000

// Offset buffer address in host memory
`define HOST_OFF_ADDR       64'h0000000000001000
`define HOST_VAL_ADDR       64'h0000000000004000

`define NUM_ROWS            32
`define MAX_STR_LEN         256

module test_stringwrite();

import tb_type_defines_pkg::*;

int         error_count;
int         timeout_count;
int         fail;
logic [3:0] status;
logic       ddr_ready;
int         read_data;

int num_off_bytes = (`NUM_ROWS + 1) * 4;
int num_val_bytes = (`NUM_ROWS) * `MAX_STR_LEN;
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

  logic[63:0] host_offsets_address;
  logic[63:0] host_values_address;
  
  logic[63:0] cl_offsets_address;
  logic[63:0] cl_values_address;
  
  host_offsets_address = `HOST_OFF_ADDR;
  host_values_address = `HOST_VAL_ADDR;
   
  cl_offsets_address = {`OFF_ADDR_HI, `OFF_ADDR_LO};
  cl_values_address = {`VAL_ADDR_HI, `VAL_ADDR_LO};

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
  tb.nsec_delay(27000);
  //tb.nsec_delay(1000);
  
  for (int i = 0; i < 2; i++) begin
    // Queue offset buffer
    tb.que_cl_to_buffer(
      .chan(0),
      .dst_addr(host_offsets_address),
      .cl_addr(cl_offsets_address),
      .len(num_off_bytes)
    );
    
    // Queue values buffer
    tb.que_cl_to_buffer(
      .chan(0),
      .dst_addr(host_values_address),
      .cl_addr(cl_values_address),
      .len(num_val_bytes)
    );
    
    /*************************************************************
    * Initialize UserCore
    *************************************************************/

    $display("[%t] : Initializing UserCore ", $realtime);

    // Reset
    tb.poke_bar1(.addr(4*`REG_CONTROL), .data(`CONTROL_RESET));
    tb.poke_bar1(.addr(4*`REG_CONTROL), .data(0));

    // Initialize buffer addressess
    tb.poke_bar1(.addr(4*`REG_STRING_OFF_ADDR_LO), .data(`OFF_ADDR_LO));
    tb.poke_bar1(.addr(4*`REG_STRING_OFF_ADDR_HI), .data(`OFF_ADDR_HI));
    tb.poke_bar1(.addr(4*`REG_STRING_VAL_ADDR_LO), .data(`VAL_ADDR_LO));
    tb.poke_bar1(.addr(4*`REG_STRING_VAL_ADDR_HI), .data(`VAL_ADDR_HI));

    // Set first and last row index
    tb.poke_bar1(.addr(4 * (`REG_FIRST_IDX)), .data(0));
    tb.poke_bar1(.addr(4 * (`REG_LAST_IDX)), .data(`NUM_ROWS));
    
    // Set strlen min and prng mask for strlen
    tb.poke_bar1(.addr(4*`REG_STRLEN_MIN), .data(0));
    tb.poke_bar1(.addr(4*`REG_PRNG_MASK), .data(255));

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

    tb.nsec_delay(10000);

    /*************************************************************
    * TRANSFER BUFFERS FROM DEVICE TO HOST
    *************************************************************/
    $display("[%t] : Transfering buffers from CL to Host", $realtime);
      
      // Start transfers of data from CL DDR to host
    tb.start_que_to_buffer(.chan(0));

    // Wait for dma transfers to complete,
    // increase the timeout if you have to transfer a lot of data
    timeout_count = 0;
    do begin
      status[0] = tb.is_dma_to_buffer_done(.chan(0));
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

    tb.nsec_delay(10000);
    
    $display("Offsets: ");
    for (int i = 0; i <= `NUM_ROWS; i++)
    begin
      off_data.bytes[0] = tb.hm_get_byte(.addr(host_offsets_address + 4 * i + 0));
      off_data.bytes[1] = tb.hm_get_byte(.addr(host_offsets_address + 4 * i + 1));
      off_data.bytes[2] = tb.hm_get_byte(.addr(host_offsets_address + 4 * i + 2));
      off_data.bytes[3] = tb.hm_get_byte(.addr(host_offsets_address + 4 * i + 3));
      $write("%6d: 0x%08X / %6d\n", i, off_data.i, off_data.i);
    end
    
    $display("Values: ");
    for (int i = 0; i <  off_data.i && i < 1024; i++)
    begin
      $write("%c", tb.hm_get_byte(.addr(host_values_address + i)));
    end
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

endmodule // test_stringwrite
