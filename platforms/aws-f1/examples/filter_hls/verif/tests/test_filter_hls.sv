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
 * Fletcher filter_hls example test-bench
 */

// Register offsets & some default values:
`define REG_STATUS          1
`define   STATUS_IDLE       32'h00000001
`define   STATUS_BUSY       32'h00000002
`define   STATUS_DONE       32'h00000004

`define REG_CONTROL         0
`define   CONTROL_START     32'h00000001
`define   CONTROL_RESET     32'h00000004

`define REG_RETURN_LO                     2
`define REG_RETURN_HI                     3
`define REG_FIRST_IDX                     4
`define REG_LAST_IDX                      5

// Buffer addresses regs
`define REG_READ_FIRST_NAME_OFF_ADDR_LO   6
`define REG_READ_FIRST_NAME_OFF_ADDR_HI   7
`define REG_READ_FIRST_NAME_VAL_ADDR_LO   8
`define REG_READ_FIRST_NAME_VAL_ADDR_HI   9
`define REG_READ_LAST_NAME_OFF_ADDR_LO   10
`define REG_READ_LAST_NAME_OFF_ADDR_HI   11
`define REG_READ_LAST_NAME_VAL_ADDR_LO   12
`define REG_READ_LAST_NAME_VAL_ADDR_HI   13
`define REG_READ_ZIPCODE_ADDR_LO         14
`define REG_READ_ZIPCODE_ADDR_HI         15
`define REG_WRITE_FIRST_NAME_OFF_ADDR_LO 16
`define REG_WRITE_FIRST_NAME_OFF_ADDR_HI 17
`define REG_WRITE_FIRST_NAME_VAL_ADDR_LO 18
`define REG_WRITE_FIRST_NAME_VAL_ADDR_HI 19

`define NUM_REGISTERS                    20

// Offset buffer address for fpga memory (must be 4Ki aligned)
`define READ_FIRST_NAME_OFF_ADDR_LO       32'h00000000
`define READ_FIRST_NAME_OFF_ADDR_HI       32'h00000000
`define READ_FIRST_NAME_VAL_ADDR_LO       32'h00001000
`define READ_FIRST_NAME_VAL_ADDR_HI       32'h00000000
`define READ_LAST_NAME_OFF_ADDR_LO        32'h00002000
`define READ_LAST_NAME_OFF_ADDR_HI        32'h00000000
`define READ_LAST_NAME_VAL_ADDR_LO        32'h00003000
`define READ_LAST_NAME_VAL_ADDR_HI        32'h00000000
`define READ_ZIPCODE_ADDR_LO              32'h00004000
`define READ_ZIPCODE_ADDR_HI              32'h00000000
`define WRITE_FIRST_NAME_OFF_ADDR_LO      32'h00005000
`define WRITE_FIRST_NAME_OFF_ADDR_HI      32'h00000000
`define WRITE_FIRST_NAME_VAL_ADDR_LO      32'h00006000
`define WRITE_FIRST_NAME_VAL_ADDR_HI      32'h00000000

// Offset buffer address in host memory
`define READ_FIRST_NAME_OFF_ADDR          64'h0000000000000000
`define READ_FIRST_NAME_VAL_ADDR          64'h0000000000001000
`define READ_LAST_NAME_OFF_ADDR           64'h0000000000002000
`define READ_LAST_NAME_VAL_ADDR           64'h0000000000003000
`define READ_ZIPCODE_ADDR                 64'h0000000000004000
`define WRITE_FIRST_NAME_OFF_ADDR         64'h0000000000005000
`define WRITE_FIRST_NAME_VAL_ADDR         64'h0000000000006000

`define NUM_ROWS            4

module test_filter_hls();

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

  function int hm_put_uint32(input longint unsigned a, input int unsigned d);
    union {
      logic[31:0] i;
      logic[3:0][7:0] bytes;
    } buf_data;
    buf_data.i = d;
    for (int b = 0; b < 4; b++) begin
      tb.hm_put_byte(.addr(a + b), .d(buf_data.bytes[b]));
    end
  endfunction
  
  function int hm_put_uint64(input longint unsigned a, input longint unsigned d);
    union {
      logic[63:0] i;
      logic[7:0][7:0] bytes;
    } buf_data;
    buf_data.i = d;
    for (int b = 0; b < 8; b++) begin
      tb.hm_put_byte(.addr(a + b), .d(buf_data.bytes[b]));
    end
  endfunction

initial begin

  logic[63:0] host_read_first_name_off_addr   = `READ_FIRST_NAME_OFF_ADDR;
  logic[63:0] host_read_first_name_val_addr   = `READ_FIRST_NAME_VAL_ADDR;
  logic[63:0] host_read_last_name_off_addr    = `READ_LAST_NAME_OFF_ADDR;
  logic[63:0] host_read_last_name_val_addr    = `READ_LAST_NAME_VAL_ADDR;
  logic[63:0] host_read_zipcode_addr          = `READ_ZIPCODE_ADDR;
  logic[63:0] host_write_first_name_off_addr  = `WRITE_FIRST_NAME_OFF_ADDR;
  logic[63:0] host_write_first_name_val_addr  = `WRITE_FIRST_NAME_VAL_ADDR;

  logic[63:0] cl_read_first_name_off_addr     = {`READ_FIRST_NAME_OFF_ADDR_HI,  `READ_FIRST_NAME_OFF_ADDR_LO};
  logic[63:0] cl_read_first_name_val_addr     = {`READ_FIRST_NAME_VAL_ADDR_HI,  `READ_FIRST_NAME_VAL_ADDR_LO};
  logic[63:0] cl_read_last_name_off_addr      = {`READ_LAST_NAME_OFF_ADDR_HI,   `READ_LAST_NAME_OFF_ADDR_LO};
  logic[63:0] cl_read_last_name_val_addr      = {`READ_LAST_NAME_VAL_ADDR_HI,   `READ_LAST_NAME_VAL_ADDR_LO};
  logic[63:0] cl_read_zipcode_addr            = {`READ_ZIPCODE_ADDR_HI,         `READ_ZIPCODE_ADDR_LO};
  logic[63:0] cl_write_first_name_off_addr    = {`WRITE_FIRST_NAME_OFF_ADDR_HI, `WRITE_FIRST_NAME_OFF_ADDR_LO};
  logic[63:0] cl_write_first_name_val_addr    = {`WRITE_FIRST_NAME_VAL_ADDR_HI, `WRITE_FIRST_NAME_VAL_ADDR_LO};

  // Power up the testbench
  tb.power_up(.clk_recipe_a(ClockRecipe::A1),
              .clk_recipe_b(ClockRecipe::B0),
              .clk_recipe_c(ClockRecipe::C0));

  tb.nsec_delay(1000);

  tb.poke_stat(.addr(8'h0c), .ddr_idx(0), .data(32'h0000_0000));
  tb.poke_stat(.addr(8'h0c), .ddr_idx(1), .data(32'h0000_0000));
  tb.poke_stat(.addr(8'h0c), .ddr_idx(2), .data(32'h0000_0000));

  // Allow memory to initialize.
  tb.nsec_delay(27000);

  // Queue read buffers.
  tb.que_buffer_to_cl(.chan(0), .src_addr(host_read_first_name_off_addr),  .cl_addr(cl_read_first_name_off_addr),  .len(4096));
  tb.que_buffer_to_cl(.chan(0), .src_addr(host_read_first_name_val_addr),  .cl_addr(cl_read_first_name_val_addr),  .len(4096));
  tb.que_buffer_to_cl(.chan(0), .src_addr(host_read_last_name_off_addr),   .cl_addr(cl_read_last_name_off_addr),   .len(4096));
  tb.que_buffer_to_cl(.chan(0), .src_addr(host_read_last_name_val_addr),   .cl_addr(cl_read_last_name_val_addr),   .len(4096));
  tb.que_buffer_to_cl(.chan(0), .src_addr(host_read_zipcode_addr),         .cl_addr(cl_read_zipcode_addr),         .len(4096));
  
  // Fill the read buffers
  
  /*****************************************
   * No time to waste
   * I've got to move with haste
   * Sorry baby but I have no time to waste
   * - T-Spoon
   *****************************************/
  
  hm_put_uint32(.a(host_read_first_name_off_addr+ 0), .d( 0)); // Alice 5
  hm_put_uint32(.a(host_read_first_name_off_addr+ 4), .d( 5)); // Bob   3
  hm_put_uint32(.a(host_read_first_name_off_addr+ 8), .d( 8)); // Carol 5
  hm_put_uint32(.a(host_read_first_name_off_addr+12), .d(13)); // David 5
  hm_put_uint32(.a(host_read_first_name_off_addr+16), .d(18)); 
  
  hm_put_uint64(.a(host_read_first_name_val_addr+ 0), .d(64'h626f426563696c41)); // boBecilA
  hm_put_uint64(.a(host_read_first_name_val_addr+ 8), .d(64'h7661446c6f726143)); // vaDloraC
  hm_put_uint64(.a(host_read_first_name_val_addr+16), .d(64'h0000000000006469)); //       di
  
  hm_put_uint32(.a(host_read_last_name_off_addr+ 0), .d( 0)); // Cooper 6
  hm_put_uint32(.a(host_read_last_name_off_addr+ 4), .d( 6)); // Smith  5
  hm_put_uint32(.a(host_read_last_name_off_addr+ 8), .d(11)); // Smith  5
  hm_put_uint32(.a(host_read_last_name_off_addr+12), .d(16)); // Smith  5
  hm_put_uint32(.a(host_read_last_name_off_addr+16), .d(21));
  
  hm_put_uint64(.a(host_read_last_name_val_addr+ 0), .d(64'h6d537265706f6f43)); // mSrepooC
  hm_put_uint64(.a(host_read_last_name_val_addr+ 8), .d(64'h6874696d53687469)); // htimShti
  hm_put_uint64(.a(host_read_last_name_val_addr+16), .d(64'h0000006874696d53)); //    htimS
  
  hm_put_uint32(.a(host_read_zipcode_addr +  0), .d(1337));
  hm_put_uint32(.a(host_read_zipcode_addr +  4), .d(4242));
  hm_put_uint32(.a(host_read_zipcode_addr +  8), .d(1337));
  hm_put_uint32(.a(host_read_zipcode_addr + 12), .d(1337));

  $display("[%t] : Starting host to CL DMA transfers ", $realtime);

  // Start transfers of data to CL DDR
  tb.start_que_to_cl(.chan(0));
  
  $display("[%t] : Waiting for timeout ", $realtime);

  // Wait for dma transfers to complete, increase the timeout if you
  // have a lot of string or if you have very long strings (if you
  // have to transfer a lot of data in general)
  timeout_count = 0;
  do begin
    #40ns;
    status[0] = tb.is_dma_to_cl_done(.chan(0));
    timeout_count++;
  end while ((status != 4'hf) && (timeout_count < 2000));

  if (timeout_count >= 2000) begin
    $display("[%t] : *** ERROR *** Timeout waiting for dma transfers from cl", $realtime);
    error_count++;
  end

  tb.nsec_delay(1000);

  /*************************************************************
  * Initialize UserCore
  *************************************************************/

  $display("[%t] : Initializing UserCore ", $realtime);

  // Reset
  tb.poke_bar1(.addr(4*`REG_CONTROL), .data(`CONTROL_RESET));
  tb.poke_bar1(.addr(4*`REG_CONTROL), .data(0));
  
  tb.poke_bar1(.addr(4*`REG_READ_FIRST_NAME_OFF_ADDR_LO ), .data(`READ_FIRST_NAME_OFF_ADDR_LO ));
  tb.poke_bar1(.addr(4*`REG_READ_FIRST_NAME_OFF_ADDR_HI ), .data(`READ_FIRST_NAME_OFF_ADDR_HI ));
  tb.poke_bar1(.addr(4*`REG_READ_FIRST_NAME_VAL_ADDR_LO ), .data(`READ_FIRST_NAME_VAL_ADDR_LO ));
  tb.poke_bar1(.addr(4*`REG_READ_FIRST_NAME_VAL_ADDR_HI ), .data(`READ_FIRST_NAME_VAL_ADDR_HI ));
  tb.poke_bar1(.addr(4*`REG_READ_LAST_NAME_OFF_ADDR_LO  ), .data(`READ_LAST_NAME_OFF_ADDR_LO  ));
  tb.poke_bar1(.addr(4*`REG_READ_LAST_NAME_OFF_ADDR_HI  ), .data(`READ_LAST_NAME_OFF_ADDR_HI  ));
  tb.poke_bar1(.addr(4*`REG_READ_LAST_NAME_VAL_ADDR_LO  ), .data(`READ_LAST_NAME_VAL_ADDR_LO  ));
  tb.poke_bar1(.addr(4*`REG_READ_LAST_NAME_VAL_ADDR_HI  ), .data(`READ_LAST_NAME_VAL_ADDR_HI  ));
  tb.poke_bar1(.addr(4*`REG_READ_ZIPCODE_ADDR_LO        ), .data(`READ_ZIPCODE_ADDR_LO        ));
  tb.poke_bar1(.addr(4*`REG_READ_ZIPCODE_ADDR_HI        ), .data(`READ_ZIPCODE_ADDR_HI        ));
  tb.poke_bar1(.addr(4*`REG_WRITE_FIRST_NAME_OFF_ADDR_LO), .data(`WRITE_FIRST_NAME_OFF_ADDR_LO));
  tb.poke_bar1(.addr(4*`REG_WRITE_FIRST_NAME_OFF_ADDR_HI), .data(`WRITE_FIRST_NAME_OFF_ADDR_HI));
  tb.poke_bar1(.addr(4*`REG_WRITE_FIRST_NAME_VAL_ADDR_LO), .data(`WRITE_FIRST_NAME_VAL_ADDR_LO));
  tb.poke_bar1(.addr(4*`REG_WRITE_FIRST_NAME_VAL_ADDR_HI), .data(`WRITE_FIRST_NAME_VAL_ADDR_HI));

  // Set first and last row index
  tb.poke_bar1(.addr(4 * (`REG_FIRST_IDX)), .data(0));
  tb.poke_bar1(.addr(4 * (`REG_LAST_IDX)), .data(4));

  $display("[%t] : Starting UserCore", $realtime);

  // Start UserCore
  tb.poke_bar1(.addr(4*`REG_CONTROL), .data(`CONTROL_START));
  tb.poke_bar1(.addr(4*`REG_CONTROL), .data(0));

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
  
  // Queue write buffers
  tb.que_cl_to_buffer(.chan(0), .dst_addr(host_write_first_name_off_addr), .cl_addr(cl_write_first_name_off_addr), .len(4096));
  tb.que_cl_to_buffer(.chan(0), .dst_addr(host_write_first_name_val_addr), .cl_addr(cl_write_first_name_val_addr), .len(4096));

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

  $display("Offsets: ");
  for (int i = 0; i <= 5; i++)
  begin
    off_data.bytes[0] = tb.hm_get_byte(.addr(host_write_first_name_off_addr + 4 * i + 0));
    off_data.bytes[1] = tb.hm_get_byte(.addr(host_write_first_name_off_addr + 4 * i + 1));
    off_data.bytes[2] = tb.hm_get_byte(.addr(host_write_first_name_off_addr + 4 * i + 2));
    off_data.bytes[3] = tb.hm_get_byte(.addr(host_write_first_name_off_addr + 4 * i + 3));
    $write("%6d: 0x%08X / %6d\n", i, off_data.i, off_data.i);
  end

  $display("Values: ");
  for (int i = 0; i < 32; i++)
  begin
    $write("%c", tb.hm_get_byte(.addr(host_write_first_name_val_addr + i)));
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
