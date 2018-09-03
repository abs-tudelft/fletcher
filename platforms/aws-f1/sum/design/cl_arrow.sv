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

// If you create your own design using our framework, you might leave everything
// in this file as-is and start using this unit as a baseline.

`define ARROW_TOP axi_top

module cl_arrow
(
   `include "cl_ports.vh"
);

`include "cl_id_defines.vh"               // Defines for ID0 and ID1 (PCI ID's)
`include "cl_arrow_defines.vh"

// Unused interfaces:
`include "unused_cl_sda_template.inc"     // Not using CL SDA interface
`include "unused_apppf_irq_template.inc"  // Not using interrupts
`include "unused_sh_ocl_template.inc"     // Not using Shell OCL interface
`include "unused_ddr_a_b_d_template.inc"  // Not using DDR A, B or D
`include "unused_pcim_template.inc"       // Not using PCI master from CL to SH

// Used interfaces:
//`include "unused_dma_pcis_template.inc" // Using DMA access from SH to CL
//`include "unused_ddr_c_template.inc"    // Using DDR C
//`include "unused_sh_bar1_template.inc"  // Using BAR1 from SH to CL
//`include "unused_flr_template.inc"      // TODO: decribe what this is for

//----------------------------
// Internal signals
//----------------------------
axi_bus_t dma_pcis();
axi_bus_t pcis();

axi_bus_t sh_bar1();
axi_bus_t arrow_slv();

axi_bus_t ddr_c();
axi_bus_t ddr();

axi_bus_t arrow_mst();

logic clk;
(* dont_touch = "true" *) logic pipe_rst_n;
logic pre_sync_rst_n;
(* dont_touch = "true" *) logic sync_rst_n;
logic pre_sync_rst;
(* dont_touch = "true" *) logic sync_rst;
logic sh_cl_flr_assert_q;
//----------------------------
// End Internal signals
//----------------------------

assign clk = clk_main_a0;

//reset synchronizer
lib_pipe #(.WIDTH(1), .STAGES(4)) PIPE_RST_N (.clk(clk), .rst_n(1'b1), .in_bus(rst_main_n), .out_bus(pipe_rst_n));

always_ff @(negedge pipe_rst_n or posedge clk)
   if (!pipe_rst_n)
   begin
      pre_sync_rst_n <= 0;
      sync_rst_n <= 0;
      pre_sync_rst <= 1;
      sync_rst <= 1;
   end
   else
   begin
      pre_sync_rst_n <= 1;
      sync_rst_n <= pre_sync_rst_n;
      pre_sync_rst <= 0;
      sync_rst <= pre_sync_rst;
   end

//FLR response
always_ff @(negedge sync_rst_n or posedge clk)
   if (!sync_rst_n)
   begin
      sh_cl_flr_assert_q <= 0;
      cl_sh_flr_done <= 0;
   end
   else
   begin
      sh_cl_flr_assert_q <= sh_cl_flr_assert;
      cl_sh_flr_done <= sh_cl_flr_assert_q && !cl_sh_flr_done;
   end


// ID's
assign cl_sh_id0 = `CL_SH_ID0;
assign cl_sh_id1 = `CL_SH_ID1;

//-----------------------------------------
// BAR 1 Connections -> sh_bar1
//-----------------------------------------
assign bar1_sh_awready = sh_bar1.awready;
assign sh_bar1.awvalid = sh_bar1_awvalid;
assign sh_bar1.awaddr  = sh_bar1_awaddr ;

assign bar1_sh_wready  = sh_bar1.wready ;
assign sh_bar1.wvalid  = sh_bar1_wvalid ;
assign sh_bar1.wdata   = sh_bar1_wdata  ;
assign sh_bar1.wstrb   = sh_bar1_wstrb  ;

assign bar1_sh_bvalid  = sh_bar1.bvalid ;
assign bar1_sh_bresp   = sh_bar1.bresp  ;
assign sh_bar1.bready  = sh_bar1_bready ;

assign bar1_sh_arready = sh_bar1.arready;
assign sh_bar1.arvalid = sh_bar1_arvalid;
assign sh_bar1.araddr  = sh_bar1_araddr ;

assign bar1_sh_rvalid  = sh_bar1.rvalid ;
assign bar1_sh_rdata   = sh_bar1.rdata  ;
assign bar1_sh_rresp   = sh_bar1.rresp  ;
assign sh_bar1.rready  = sh_bar1_rready ;

//----------------------------------------------
// DMA PCI Slave Connections -> dma_pcis
//----------------------------------------------
assign cl_sh_dma_wr_full        = 1'b0;
assign cl_sh_dma_rd_full        = 1'b0;

assign dma_pcis.awid[5:0]       = sh_cl_dma_pcis_awid   ;
assign dma_pcis.awaddr          = sh_cl_dma_pcis_awaddr ;
assign dma_pcis.awlen           = sh_cl_dma_pcis_awlen  ;
assign dma_pcis.awsize          = sh_cl_dma_pcis_awsize ;
assign dma_pcis.awvalid         = sh_cl_dma_pcis_awvalid;
assign cl_sh_dma_pcis_awready   = dma_pcis.awready      ;

assign dma_pcis.wdata           = sh_cl_dma_pcis_wdata  ;
assign dma_pcis.wstrb           = sh_cl_dma_pcis_wstrb  ;
assign dma_pcis.wlast           = sh_cl_dma_pcis_wlast  ;
assign dma_pcis.wvalid          = sh_cl_dma_pcis_wvalid ;
assign cl_sh_dma_pcis_wready    = dma_pcis.wready       ;

assign cl_sh_dma_pcis_bid       = dma_pcis.bid[5:0]     ;
assign cl_sh_dma_pcis_bresp     = dma_pcis.bresp        ;
assign cl_sh_dma_pcis_bvalid    = dma_pcis.bvalid       ;
assign dma_pcis.bready          = sh_cl_dma_pcis_bready ;

assign dma_pcis.arid[5:0]       = sh_cl_dma_pcis_arid   ;
assign dma_pcis.araddr          = sh_cl_dma_pcis_araddr ;
assign dma_pcis.arlen           = sh_cl_dma_pcis_arlen  ;
assign dma_pcis.arsize          = sh_cl_dma_pcis_arsize ;
assign dma_pcis.arvalid         = sh_cl_dma_pcis_arvalid;
assign cl_sh_dma_pcis_arready   = dma_pcis.arready      ;

assign cl_sh_dma_pcis_rid       = dma_pcis.rid[5:0]     ;
assign cl_sh_dma_pcis_rdata     = dma_pcis.rdata        ;
assign cl_sh_dma_pcis_rresp     = dma_pcis.rresp        ;
assign cl_sh_dma_pcis_rlast     = dma_pcis.rlast        ;
assign cl_sh_dma_pcis_rvalid    = dma_pcis.rvalid       ;
assign dma_pcis.rready          = sh_cl_dma_pcis_rready ;

//----------------------------------------------
// DDRC Connections -> ddr_c
//----------------------------------------------
assign cl_sh_ddr_awid           = ddr_c.awid            ;
assign cl_sh_ddr_awaddr         = ddr_c.awaddr          ;
assign cl_sh_ddr_awlen          = ddr_c.awlen           ;
assign cl_sh_ddr_awsize         = ddr_c.awsize          ;
assign cl_sh_ddr_awburst        = 2'b01                 ;
assign cl_sh_ddr_awvalid        = ddr_c.awvalid         ;
assign ddr_c.awready            = sh_cl_ddr_awready     ;

assign cl_sh_ddr_wid            = 16'b0                 ;
assign cl_sh_ddr_wdata          = ddr_c.wdata           ;
assign cl_sh_ddr_wstrb          = ddr_c.wstrb           ;
assign cl_sh_ddr_wlast          = ddr_c.wlast           ;
assign cl_sh_ddr_wvalid         = ddr_c.wvalid          ;
assign ddr_c.wready             = sh_cl_ddr_wready      ;

assign ddr_c.bid                = sh_cl_ddr_bid         ;
assign ddr_c.bresp              = sh_cl_ddr_bresp       ;
assign ddr_c.bvalid             = sh_cl_ddr_bvalid      ;
assign cl_sh_ddr_bready         = ddr_c.bready          ;

assign cl_sh_ddr_arid           = ddr_c.arid            ;
assign cl_sh_ddr_araddr         = ddr_c.araddr          ;
assign cl_sh_ddr_arlen          = ddr_c.arlen           ;
assign cl_sh_ddr_arsize         = ddr_c.arsize          ;
assign cl_sh_ddr_arburst        = 2'b01                 ;
assign cl_sh_ddr_arvalid        = ddr_c.arvalid         ;
assign ddr_c.arready            = sh_cl_ddr_arready     ;

assign ddr_c.rid                = sh_cl_ddr_rid         ;
assign ddr_c.rdata              = sh_cl_ddr_rdata       ;
assign ddr_c.rresp              = sh_cl_ddr_rresp       ;
assign ddr_c.rlast              = sh_cl_ddr_rlast       ;
assign ddr_c.rvalid             = sh_cl_ddr_rvalid      ;
assign cl_sh_ddr_rready         = ddr_c.rready          ;

//assign sh_cl_ddr_is_ready


//-----------------------------------------
// BAR1 Slice
//-----------------------------------------
axi_register_slice_light BAR1_SLICE (
  .aclk          (clk),
  .aresetn       (sync_rst_n),

  // Slave in
  .s_axi_awvalid (sh_bar1.awvalid  ),
  .s_axi_awready (sh_bar1.awready  ),
  .s_axi_awaddr  (sh_bar1.awaddr   ),

  .s_axi_wvalid  (sh_bar1.wvalid   ),
  .s_axi_wready  (sh_bar1.wready   ),
  .s_axi_wdata   (sh_bar1.wdata    ),
  .s_axi_wstrb   (sh_bar1.wstrb    ),

  .s_axi_bvalid  (sh_bar1.bvalid   ),
  .s_axi_bready  (sh_bar1.bready   ),
  .s_axi_bresp   (sh_bar1.bresp    ),

  .s_axi_arvalid (sh_bar1.arvalid  ),
  .s_axi_arready (sh_bar1.arready  ),
  .s_axi_araddr  (sh_bar1.araddr   ),

  .s_axi_rvalid  (sh_bar1.rvalid   ),
  .s_axi_rready  (sh_bar1.rready   ),
  .s_axi_rdata   (sh_bar1.rdata    ),
  .s_axi_rresp   (sh_bar1.rresp    ),

  // Master out
  .m_axi_awaddr  (arrow_slv.awaddr ),
  .m_axi_awvalid (arrow_slv.awvalid),
  .m_axi_awready (arrow_slv.awready),

  .m_axi_wdata   (arrow_slv.wdata  ),
  .m_axi_wstrb   (arrow_slv.wstrb  ),
  .m_axi_wvalid  (arrow_slv.wvalid ),
  .m_axi_wready  (arrow_slv.wready ),

  .m_axi_bresp   (arrow_slv.bresp  ),
  .m_axi_bvalid  (arrow_slv.bvalid ),
  .m_axi_bready  (arrow_slv.bready ),

  .m_axi_araddr  (arrow_slv.araddr ),
  .m_axi_arvalid (arrow_slv.arvalid),
  .m_axi_arready (arrow_slv.arready),

  .m_axi_rdata   (arrow_slv.rdata  ),
  .m_axi_rresp   (arrow_slv.rresp  ),
  .m_axi_rvalid  (arrow_slv.rvalid ),
  .m_axi_rready  (arrow_slv.rready )
);


//-----------------------------------------
// PCIS Slice
//-----------------------------------------
axi_register_slice PCIS_SLICE (
  .aclk          (clk),
  .aresetn       (sync_rst_n),
  // Slave side
  .s_axi_awid     (dma_pcis.awid    ),
  .s_axi_awaddr   (dma_pcis.awaddr  ),
  .s_axi_awlen    (dma_pcis.awlen   ),
  .s_axi_awsize   (dma_pcis.awsize  ),
  .s_axi_awvalid  (dma_pcis.awvalid ),
  .s_axi_awready  (dma_pcis.awready ),
  .s_axi_wdata    (dma_pcis.wdata   ),
  .s_axi_wstrb    (dma_pcis.wstrb   ),
  .s_axi_wlast    (dma_pcis.wlast   ),
  .s_axi_wvalid   (dma_pcis.wvalid  ),
  .s_axi_wready   (dma_pcis.wready  ),
  .s_axi_bid      (dma_pcis.bid     ),
  .s_axi_bresp    (dma_pcis.bresp   ),
  .s_axi_bvalid   (dma_pcis.bvalid  ),
  .s_axi_bready   (dma_pcis.bready  ),
  .s_axi_arid     (dma_pcis.arid    ),
  .s_axi_araddr   (dma_pcis.araddr  ),
  .s_axi_arlen    (dma_pcis.arlen   ),
  .s_axi_arsize   (dma_pcis.arsize  ),
  .s_axi_arvalid  (dma_pcis.arvalid ),
  .s_axi_arready  (dma_pcis.arready ),
  .s_axi_rid      (dma_pcis.rid     ),
  .s_axi_rdata    (dma_pcis.rdata   ),
  .s_axi_rresp    (dma_pcis.rresp   ),
  .s_axi_rlast    (dma_pcis.rlast   ),
  .s_axi_rvalid   (dma_pcis.rvalid  ),
  .s_axi_rready   (dma_pcis.rready  ),
   // Master side
  .m_axi_awid     (pcis.awid    ),
  .m_axi_awaddr   (pcis.awaddr  ),
  .m_axi_awlen    (pcis.awlen   ),
  .m_axi_awsize   (pcis.awsize  ),
  .m_axi_awvalid  (pcis.awvalid ),
  .m_axi_awready  (pcis.awready ),
  .m_axi_wdata    (pcis.wdata   ),
  .m_axi_wstrb    (pcis.wstrb   ),
  .m_axi_wlast    (pcis.wlast   ),
  .m_axi_wvalid   (pcis.wvalid  ),
  .m_axi_wready   (pcis.wready  ),
  .m_axi_bid      (pcis.bid     ),
  .m_axi_bresp    (pcis.bresp   ),
  .m_axi_bvalid   (pcis.bvalid  ),
  .m_axi_bready   (pcis.bready  ),
  .m_axi_arid     (pcis.arid    ),
  .m_axi_araddr   (pcis.araddr  ),
  .m_axi_arlen    (pcis.arlen   ),
  .m_axi_arsize   (pcis.arsize  ),
  .m_axi_arvalid  (pcis.arvalid ),
  .m_axi_arready  (pcis.arready ),
  .m_axi_rid      (pcis.rid     ),
  .m_axi_rdata    (pcis.rdata   ),
  .m_axi_rresp    (pcis.rresp   ),
  .m_axi_rlast    (pcis.rlast   ),
  .m_axi_rvalid   (pcis.rvalid  ),
  .m_axi_rready   (pcis.rready  )
);

//-----------------------------------------
// DDR C Slice
//-----------------------------------------
axi_register_slice DDRC_SLICE (
  .aclk          (clk),
  .aresetn       (sync_rst_n),
  // Slave side
  .s_axi_awid     (ddr.awid    ),
  .s_axi_awaddr   (ddr.awaddr  ),
  .s_axi_awlen    (ddr.awlen   ),
  .s_axi_awsize   (ddr.awsize  ),
  .s_axi_awvalid  (ddr.awvalid ),
  .s_axi_awready  (ddr.awready ),
  .s_axi_wdata    (ddr.wdata   ),
  .s_axi_wstrb    (ddr.wstrb   ),
  .s_axi_wlast    (ddr.wlast   ),
  .s_axi_wvalid   (ddr.wvalid  ),
  .s_axi_wready   (ddr.wready  ),
  .s_axi_bid      (ddr.bid     ),
  .s_axi_bresp    (ddr.bresp   ),
  .s_axi_bvalid   (ddr.bvalid  ),
  .s_axi_bready   (ddr.bready  ),
  .s_axi_arid     (ddr.arid    ),
  .s_axi_araddr   (ddr.araddr  ),
  .s_axi_arlen    (ddr.arlen   ),
  .s_axi_arsize   (ddr.arsize  ),
  .s_axi_arvalid  (ddr.arvalid ),
  .s_axi_arready  (ddr.arready ),
  .s_axi_rid      (ddr.rid     ),
  .s_axi_rdata    (ddr.rdata   ),
  .s_axi_rresp    (ddr.rresp   ),
  .s_axi_rlast    (ddr.rlast   ),
  .s_axi_rvalid   (ddr.rvalid  ),
  .s_axi_rready   (ddr.rready  ),
   // Master side
  .m_axi_awid     (ddr_c.awid    ),
  .m_axi_awaddr   (ddr_c.awaddr  ),
  .m_axi_awlen    (ddr_c.awlen   ),
  .m_axi_awsize   (ddr_c.awsize  ),
  .m_axi_awvalid  (ddr_c.awvalid ),
  .m_axi_awready  (ddr_c.awready ),
  .m_axi_wdata    (ddr_c.wdata   ),
  .m_axi_wstrb    (ddr_c.wstrb   ),
  .m_axi_wlast    (ddr_c.wlast   ),
  .m_axi_wvalid   (ddr_c.wvalid  ),
  .m_axi_wready   (ddr_c.wready  ),
  .m_axi_bid      (ddr_c.bid     ),
  .m_axi_bresp    (ddr_c.bresp   ),
  .m_axi_bvalid   (ddr_c.bvalid  ),
  .m_axi_bready   (ddr_c.bready  ),
  .m_axi_arid     (ddr_c.arid    ),
  .m_axi_araddr   (ddr_c.araddr  ),
  .m_axi_arlen    (ddr_c.arlen   ),
  .m_axi_arsize   (ddr_c.arsize  ),
  .m_axi_arvalid  (ddr_c.arvalid ),
  .m_axi_arready  (ddr_c.arready ),
  .m_axi_rid      (ddr_c.rid     ),
  .m_axi_rdata    (ddr_c.rdata   ),
  .m_axi_rresp    (ddr_c.rresp   ),
  .m_axi_rlast    (ddr_c.rlast   ),
  .m_axi_rvalid   (ddr_c.rvalid  ),
  .m_axi_rready   (ddr_c.rready  )
);


axi_interconnect_top AXI_INTERCONNECT (
  .INTERCONNECT_ACLK    (clk    ),
  .INTERCONNECT_ARESETN (sync_rst_n),

  //.s00_axi_areset_out_n(        ),
  .S00_AXI_ACLK   (clk         ),
  .S00_AXI_AWBURST(2'b1        ),
  .S00_AXI_AWLOCK (1'b0        ),
  .S00_AXI_AWCACHE(4'b11       ),
  .S00_AXI_AWPROT (3'b10       ),
  .S00_AXI_AWQOS  (4'b0        ),
  .S00_AXI_AWID   (pcis.awid   ),
  .S00_AXI_AWADDR (pcis.awaddr ),
  .S00_AXI_AWLEN  (pcis.awlen  ),
  .S00_AXI_AWSIZE (pcis.awsize ),
  .S00_AXI_AWVALID(pcis.awvalid),
  .S00_AXI_AWREADY(pcis.awready),
  .S00_AXI_WDATA  (pcis.wdata  ),
  .S00_AXI_WSTRB  (pcis.wstrb  ),
  .S00_AXI_WLAST  (pcis.wlast  ),
  .S00_AXI_WVALID (pcis.wvalid ),
  .S00_AXI_WREADY (pcis.wready ),
  .S00_AXI_BID    (pcis.bid    ),
  .S00_AXI_BRESP  (pcis.bresp  ),
  .S00_AXI_BVALID (pcis.bvalid ),
  .S00_AXI_BREADY (pcis.bready ),
  .S00_AXI_ARBURST(2'b1        ),
  .S00_AXI_ARLOCK (1'b0        ),
  .S00_AXI_ARCACHE(4'b11       ),
  .S00_AXI_ARPROT (3'b10       ),
  .S00_AXI_ARQOS  (4'b0        ),
  .S00_AXI_ARID   (pcis.arid   ),
  .S00_AXI_ARADDR (pcis.araddr ),
  .S00_AXI_ARLEN  (pcis.arlen  ),
  .S00_AXI_ARSIZE (pcis.arsize ),
  .S00_AXI_ARVALID(pcis.arvalid),
  .S00_AXI_ARREADY(pcis.arready),
  .S00_AXI_RID    (pcis.rid    ),
  .S00_AXI_RDATA  (pcis.rdata  ),
  .S00_AXI_RRESP  (pcis.rresp  ),
  .S00_AXI_RLAST  (pcis.rlast  ),
  .S00_AXI_RVALID (pcis.rvalid ),
  .S00_AXI_RREADY (pcis.rready ),

  //.s01_axi_areset_out_n(            ),
  .S01_AXI_ACLK   (clk              ),
  .S01_AXI_AWBURST(2'b1             ),
  .S01_AXI_AWLOCK (1'b0             ),
  .S01_AXI_AWCACHE(4'b11            ),
  .S01_AXI_AWPROT (3'b10            ),
  .S01_AXI_AWQOS  (4'b0             ),
  .S01_AXI_AWID   (arrow_mst.awid   ),
  .S01_AXI_AWADDR (arrow_mst.awaddr ),
  .S01_AXI_AWLEN  (arrow_mst.awlen  ),
  .S01_AXI_AWSIZE (arrow_mst.awsize ),
  .S01_AXI_AWVALID(arrow_mst.awvalid),
  .S01_AXI_AWREADY(arrow_mst.awready),
  .S01_AXI_WDATA  (arrow_mst.wdata  ),
  .S01_AXI_WSTRB  (arrow_mst.wstrb  ),
  .S01_AXI_WLAST  (arrow_mst.wlast  ),
  .S01_AXI_WVALID (arrow_mst.wvalid ),
  .S01_AXI_WREADY (arrow_mst.wready ),
  .S01_AXI_BID    (arrow_mst.bid    ),
  .S01_AXI_BRESP  (arrow_mst.bresp  ),
  .S01_AXI_BVALID (arrow_mst.bvalid ),
  .S01_AXI_BREADY (arrow_mst.bready ),
  .S01_AXI_ARBURST(2'b1             ),
  .S01_AXI_ARLOCK (1'b0             ),
  .S01_AXI_ARCACHE(4'b11            ),
  .S01_AXI_ARPROT (3'b10            ),
  .S01_AXI_ARQOS  (4'b0             ),
  .S01_AXI_ARID   (arrow_mst.arid   ),
  .S01_AXI_ARADDR (arrow_mst.araddr ),
  .S01_AXI_ARLEN  (arrow_mst.arlen  ),
  .S01_AXI_ARSIZE (arrow_mst.arsize ),
  .S01_AXI_ARVALID(arrow_mst.arvalid),
  .S01_AXI_ARREADY(arrow_mst.arready),
  .S01_AXI_RID    (arrow_mst.rid    ),
  .S01_AXI_RDATA  (arrow_mst.rdata  ),
  .S01_AXI_RRESP  (arrow_mst.rresp  ),
  .S01_AXI_RLAST  (arrow_mst.rlast  ),
  .S01_AXI_RVALID (arrow_mst.rvalid ),
  .S01_AXI_RREADY (arrow_mst.rready ),

  //.m00_axi_areset_out_n(      ),
  .M00_AXI_ACLK   (clk        ),
  //.M00_AXI_AWBURST(ddr.awburst),
  //.M00_AXI_AWLOCK (ddr.awlock ),
  //.M00_AXI_AWCACHE(ddr.awcache),
  //.M00_AXI_AWPROT (ddr.awprot ),
  //.M00_AXI_AWQOS  (ddr.awqos  ),
  .M00_AXI_AWID   (ddr.awid   ),
  .M00_AXI_AWADDR (ddr.awaddr ),
  .M00_AXI_AWLEN  (ddr.awlen  ),
  .M00_AXI_AWSIZE (ddr.awsize ),
  .M00_AXI_AWVALID(ddr.awvalid),
  .M00_AXI_AWREADY(ddr.awready),
  .M00_AXI_WDATA  (ddr.wdata  ),
  .M00_AXI_WSTRB  (ddr.wstrb  ),
  .M00_AXI_WLAST  (ddr.wlast  ),
  .M00_AXI_WVALID (ddr.wvalid ),
  .M00_AXI_WREADY (ddr.wready ),
  .M00_AXI_BID    (ddr.bid    ),
  .M00_AXI_BRESP  (ddr.bresp  ),
  .M00_AXI_BVALID (ddr.bvalid ),
  .M00_AXI_BREADY (ddr.bready ),
  //.M00_AXI_ARBURST(ddr.arburst),
  //.M00_AXI_ARLOCK (ddr.arlock ),
  //.M00_AXI_ARCACHE(ddr.arcache),
  //.M00_AXI_ARPROT (ddr.arprot ),
  //.M00_AXI_ARQOS  (ddr.arqos  ),
  .M00_AXI_ARID   (ddr.arid   ),
  .M00_AXI_ARADDR (ddr.araddr ),
  .M00_AXI_ARLEN  (ddr.arlen  ),
  .M00_AXI_ARSIZE (ddr.arsize ),
  .M00_AXI_ARVALID(ddr.arvalid),
  .M00_AXI_ARREADY(ddr.arready),
  .M00_AXI_RID    (ddr.rid    ),
  .M00_AXI_RDATA  (ddr.rdata  ),
  .M00_AXI_RRESP  (ddr.rresp  ),
  .M00_AXI_RLAST  (ddr.rlast  ),
  .M00_AXI_RVALID (ddr.rvalid ),
  .M00_AXI_RREADY (ddr.rready )
);

// Write channel tie off
assign arrow_mst.bready         = 1'b1;

// Read channel defaults:
assign arrow_mst.arsize         = 3'b110; // 512 bit beats
//assign arrow_mst.arburst        = 2'b01; // incremental

// Not using any of these:
assign arrow_mst.arid           = 0;
//assign arrow_mst.arlock         = 0;
//assign arrow_mst.arcache        = 4'b0010;
//assign arrow_mst.arprot         = 3'b000;
//assign arrow_mst.arqos          = 4'b0000;
//assign arrow_mst.aruser         = (others => '0');

`ARROW_TOP #() ARROW_TOP_INST (
   .acc_clk(clk),
   .bus_clk(clk),
   .acc_reset(sync_rst),
   .bus_reset_n(sync_rst_n),

   // Master interface
   .m_axi_arvalid(arrow_mst.arvalid),
   .m_axi_arready(arrow_mst.arready),
   .m_axi_araddr (arrow_mst.araddr ),
   .m_axi_arlen  (arrow_mst.arlen  ),
   .m_axi_arsize (arrow_mst.arsize ),

   .m_axi_rvalid (arrow_mst.rvalid ),
   .m_axi_rready (arrow_mst.rready ),
   .m_axi_rdata  (arrow_mst.rdata  ),
   .m_axi_rresp  (arrow_mst.rresp  ),
   .m_axi_rlast  (arrow_mst.rlast  ),

    // Write address channel
   .m_axi_awvalid(arrow_mst.awvalid),
   .m_axi_awready(arrow_mst.awready),
   .m_axi_awaddr (arrow_mst.awaddr),
   .m_axi_awlen  (arrow_mst.awlen),
   .m_axi_awsize (arrow_mst.awsize),

    // Write data channel
   .m_axi_wvalid (arrow_mst.wvalid),
   .m_axi_wready (arrow_mst.wready),
   .m_axi_wdata  (arrow_mst.wdata),
   .m_axi_wlast  (arrow_mst.wlast),
   .m_axi_wstrb  (arrow_mst.wstrb),

   // Slave interface
   .s_axi_awvalid(arrow_slv.awvalid),
   .s_axi_awready(arrow_slv.awready),
   .s_axi_awaddr (arrow_slv.awaddr ),
   .s_axi_wvalid (arrow_slv.wvalid ),
   .s_axi_wready (arrow_slv.wready ),
   .s_axi_wdata  (arrow_slv.wdata  ),
   .s_axi_wstrb  (arrow_slv.wstrb  ),
   .s_axi_bvalid (arrow_slv.bvalid ),
   .s_axi_bready (arrow_slv.bready ),
   .s_axi_bresp  (arrow_slv.bresp  ),
   .s_axi_arvalid(arrow_slv.arvalid),
   .s_axi_arready(arrow_slv.arready),
   .s_axi_araddr (arrow_slv.araddr ),
   .s_axi_rvalid (arrow_slv.rvalid ),
   .s_axi_rready (arrow_slv.rready ),
   .s_axi_rdata  (arrow_slv.rdata  ),
   .s_axi_rresp  (arrow_slv.rresp  )
);

endmodule
