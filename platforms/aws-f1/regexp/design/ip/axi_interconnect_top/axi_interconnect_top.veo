// (c) Copyright 1995-2018 Xilinx, Inc. All rights reserved.
// 
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
// 
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
// 
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
// 
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
// 
// DO NOT MODIFY THIS FILE.

// IP VLNV: xilinx.com:ip:axi_interconnect:1.7
// IP Revision: 13

// The following must be inserted into your Verilog file for this
// core to be instantiated. Change the instance name and port connections
// (in parentheses) to your own signal names.

//----------- Begin Cut here for INSTANTIATION Template ---// INST_TAG
axi_interconnect_top your_instance_name (
  .INTERCONNECT_ACLK(INTERCONNECT_ACLK),        // input wire INTERCONNECT_ACLK
  .INTERCONNECT_ARESETN(INTERCONNECT_ARESETN),  // input wire INTERCONNECT_ARESETN
  .S00_AXI_ARESET_OUT_N(S00_AXI_ARESET_OUT_N),  // output wire S00_AXI_ARESET_OUT_N
  .S00_AXI_ACLK(S00_AXI_ACLK),                  // input wire S00_AXI_ACLK
  .S00_AXI_AWID(S00_AXI_AWID),                  // input wire [5 : 0] S00_AXI_AWID
  .S00_AXI_AWADDR(S00_AXI_AWADDR),              // input wire [63 : 0] S00_AXI_AWADDR
  .S00_AXI_AWLEN(S00_AXI_AWLEN),                // input wire [7 : 0] S00_AXI_AWLEN
  .S00_AXI_AWSIZE(S00_AXI_AWSIZE),              // input wire [2 : 0] S00_AXI_AWSIZE
  .S00_AXI_AWBURST(S00_AXI_AWBURST),            // input wire [1 : 0] S00_AXI_AWBURST
  .S00_AXI_AWLOCK(S00_AXI_AWLOCK),              // input wire S00_AXI_AWLOCK
  .S00_AXI_AWCACHE(S00_AXI_AWCACHE),            // input wire [3 : 0] S00_AXI_AWCACHE
  .S00_AXI_AWPROT(S00_AXI_AWPROT),              // input wire [2 : 0] S00_AXI_AWPROT
  .S00_AXI_AWQOS(S00_AXI_AWQOS),                // input wire [3 : 0] S00_AXI_AWQOS
  .S00_AXI_AWVALID(S00_AXI_AWVALID),            // input wire S00_AXI_AWVALID
  .S00_AXI_AWREADY(S00_AXI_AWREADY),            // output wire S00_AXI_AWREADY
  .S00_AXI_WDATA(S00_AXI_WDATA),                // input wire [511 : 0] S00_AXI_WDATA
  .S00_AXI_WSTRB(S00_AXI_WSTRB),                // input wire [63 : 0] S00_AXI_WSTRB
  .S00_AXI_WLAST(S00_AXI_WLAST),                // input wire S00_AXI_WLAST
  .S00_AXI_WVALID(S00_AXI_WVALID),              // input wire S00_AXI_WVALID
  .S00_AXI_WREADY(S00_AXI_WREADY),              // output wire S00_AXI_WREADY
  .S00_AXI_BID(S00_AXI_BID),                    // output wire [5 : 0] S00_AXI_BID
  .S00_AXI_BRESP(S00_AXI_BRESP),                // output wire [1 : 0] S00_AXI_BRESP
  .S00_AXI_BVALID(S00_AXI_BVALID),              // output wire S00_AXI_BVALID
  .S00_AXI_BREADY(S00_AXI_BREADY),              // input wire S00_AXI_BREADY
  .S00_AXI_ARID(S00_AXI_ARID),                  // input wire [5 : 0] S00_AXI_ARID
  .S00_AXI_ARADDR(S00_AXI_ARADDR),              // input wire [63 : 0] S00_AXI_ARADDR
  .S00_AXI_ARLEN(S00_AXI_ARLEN),                // input wire [7 : 0] S00_AXI_ARLEN
  .S00_AXI_ARSIZE(S00_AXI_ARSIZE),              // input wire [2 : 0] S00_AXI_ARSIZE
  .S00_AXI_ARBURST(S00_AXI_ARBURST),            // input wire [1 : 0] S00_AXI_ARBURST
  .S00_AXI_ARLOCK(S00_AXI_ARLOCK),              // input wire S00_AXI_ARLOCK
  .S00_AXI_ARCACHE(S00_AXI_ARCACHE),            // input wire [3 : 0] S00_AXI_ARCACHE
  .S00_AXI_ARPROT(S00_AXI_ARPROT),              // input wire [2 : 0] S00_AXI_ARPROT
  .S00_AXI_ARQOS(S00_AXI_ARQOS),                // input wire [3 : 0] S00_AXI_ARQOS
  .S00_AXI_ARVALID(S00_AXI_ARVALID),            // input wire S00_AXI_ARVALID
  .S00_AXI_ARREADY(S00_AXI_ARREADY),            // output wire S00_AXI_ARREADY
  .S00_AXI_RID(S00_AXI_RID),                    // output wire [5 : 0] S00_AXI_RID
  .S00_AXI_RDATA(S00_AXI_RDATA),                // output wire [511 : 0] S00_AXI_RDATA
  .S00_AXI_RRESP(S00_AXI_RRESP),                // output wire [1 : 0] S00_AXI_RRESP
  .S00_AXI_RLAST(S00_AXI_RLAST),                // output wire S00_AXI_RLAST
  .S00_AXI_RVALID(S00_AXI_RVALID),              // output wire S00_AXI_RVALID
  .S00_AXI_RREADY(S00_AXI_RREADY),              // input wire S00_AXI_RREADY
  .S01_AXI_ARESET_OUT_N(S01_AXI_ARESET_OUT_N),  // output wire S01_AXI_ARESET_OUT_N
  .S01_AXI_ACLK(S01_AXI_ACLK),                  // input wire S01_AXI_ACLK
  .S01_AXI_AWID(S01_AXI_AWID),                  // input wire [5 : 0] S01_AXI_AWID
  .S01_AXI_AWADDR(S01_AXI_AWADDR),              // input wire [63 : 0] S01_AXI_AWADDR
  .S01_AXI_AWLEN(S01_AXI_AWLEN),                // input wire [7 : 0] S01_AXI_AWLEN
  .S01_AXI_AWSIZE(S01_AXI_AWSIZE),              // input wire [2 : 0] S01_AXI_AWSIZE
  .S01_AXI_AWBURST(S01_AXI_AWBURST),            // input wire [1 : 0] S01_AXI_AWBURST
  .S01_AXI_AWLOCK(S01_AXI_AWLOCK),              // input wire S01_AXI_AWLOCK
  .S01_AXI_AWCACHE(S01_AXI_AWCACHE),            // input wire [3 : 0] S01_AXI_AWCACHE
  .S01_AXI_AWPROT(S01_AXI_AWPROT),              // input wire [2 : 0] S01_AXI_AWPROT
  .S01_AXI_AWQOS(S01_AXI_AWQOS),                // input wire [3 : 0] S01_AXI_AWQOS
  .S01_AXI_AWVALID(S01_AXI_AWVALID),            // input wire S01_AXI_AWVALID
  .S01_AXI_AWREADY(S01_AXI_AWREADY),            // output wire S01_AXI_AWREADY
  .S01_AXI_WDATA(S01_AXI_WDATA),                // input wire [511 : 0] S01_AXI_WDATA
  .S01_AXI_WSTRB(S01_AXI_WSTRB),                // input wire [63 : 0] S01_AXI_WSTRB
  .S01_AXI_WLAST(S01_AXI_WLAST),                // input wire S01_AXI_WLAST
  .S01_AXI_WVALID(S01_AXI_WVALID),              // input wire S01_AXI_WVALID
  .S01_AXI_WREADY(S01_AXI_WREADY),              // output wire S01_AXI_WREADY
  .S01_AXI_BID(S01_AXI_BID),                    // output wire [5 : 0] S01_AXI_BID
  .S01_AXI_BRESP(S01_AXI_BRESP),                // output wire [1 : 0] S01_AXI_BRESP
  .S01_AXI_BVALID(S01_AXI_BVALID),              // output wire S01_AXI_BVALID
  .S01_AXI_BREADY(S01_AXI_BREADY),              // input wire S01_AXI_BREADY
  .S01_AXI_ARID(S01_AXI_ARID),                  // input wire [5 : 0] S01_AXI_ARID
  .S01_AXI_ARADDR(S01_AXI_ARADDR),              // input wire [63 : 0] S01_AXI_ARADDR
  .S01_AXI_ARLEN(S01_AXI_ARLEN),                // input wire [7 : 0] S01_AXI_ARLEN
  .S01_AXI_ARSIZE(S01_AXI_ARSIZE),              // input wire [2 : 0] S01_AXI_ARSIZE
  .S01_AXI_ARBURST(S01_AXI_ARBURST),            // input wire [1 : 0] S01_AXI_ARBURST
  .S01_AXI_ARLOCK(S01_AXI_ARLOCK),              // input wire S01_AXI_ARLOCK
  .S01_AXI_ARCACHE(S01_AXI_ARCACHE),            // input wire [3 : 0] S01_AXI_ARCACHE
  .S01_AXI_ARPROT(S01_AXI_ARPROT),              // input wire [2 : 0] S01_AXI_ARPROT
  .S01_AXI_ARQOS(S01_AXI_ARQOS),                // input wire [3 : 0] S01_AXI_ARQOS
  .S01_AXI_ARVALID(S01_AXI_ARVALID),            // input wire S01_AXI_ARVALID
  .S01_AXI_ARREADY(S01_AXI_ARREADY),            // output wire S01_AXI_ARREADY
  .S01_AXI_RID(S01_AXI_RID),                    // output wire [5 : 0] S01_AXI_RID
  .S01_AXI_RDATA(S01_AXI_RDATA),                // output wire [511 : 0] S01_AXI_RDATA
  .S01_AXI_RRESP(S01_AXI_RRESP),                // output wire [1 : 0] S01_AXI_RRESP
  .S01_AXI_RLAST(S01_AXI_RLAST),                // output wire S01_AXI_RLAST
  .S01_AXI_RVALID(S01_AXI_RVALID),              // output wire S01_AXI_RVALID
  .S01_AXI_RREADY(S01_AXI_RREADY),              // input wire S01_AXI_RREADY
  .M00_AXI_ARESET_OUT_N(M00_AXI_ARESET_OUT_N),  // output wire M00_AXI_ARESET_OUT_N
  .M00_AXI_ACLK(M00_AXI_ACLK),                  // input wire M00_AXI_ACLK
  .M00_AXI_AWID(M00_AXI_AWID),                  // output wire [9 : 0] M00_AXI_AWID
  .M00_AXI_AWADDR(M00_AXI_AWADDR),              // output wire [63 : 0] M00_AXI_AWADDR
  .M00_AXI_AWLEN(M00_AXI_AWLEN),                // output wire [7 : 0] M00_AXI_AWLEN
  .M00_AXI_AWSIZE(M00_AXI_AWSIZE),              // output wire [2 : 0] M00_AXI_AWSIZE
  .M00_AXI_AWBURST(M00_AXI_AWBURST),            // output wire [1 : 0] M00_AXI_AWBURST
  .M00_AXI_AWLOCK(M00_AXI_AWLOCK),              // output wire M00_AXI_AWLOCK
  .M00_AXI_AWCACHE(M00_AXI_AWCACHE),            // output wire [3 : 0] M00_AXI_AWCACHE
  .M00_AXI_AWPROT(M00_AXI_AWPROT),              // output wire [2 : 0] M00_AXI_AWPROT
  .M00_AXI_AWQOS(M00_AXI_AWQOS),                // output wire [3 : 0] M00_AXI_AWQOS
  .M00_AXI_AWVALID(M00_AXI_AWVALID),            // output wire M00_AXI_AWVALID
  .M00_AXI_AWREADY(M00_AXI_AWREADY),            // input wire M00_AXI_AWREADY
  .M00_AXI_WDATA(M00_AXI_WDATA),                // output wire [511 : 0] M00_AXI_WDATA
  .M00_AXI_WSTRB(M00_AXI_WSTRB),                // output wire [63 : 0] M00_AXI_WSTRB
  .M00_AXI_WLAST(M00_AXI_WLAST),                // output wire M00_AXI_WLAST
  .M00_AXI_WVALID(M00_AXI_WVALID),              // output wire M00_AXI_WVALID
  .M00_AXI_WREADY(M00_AXI_WREADY),              // input wire M00_AXI_WREADY
  .M00_AXI_BID(M00_AXI_BID),                    // input wire [9 : 0] M00_AXI_BID
  .M00_AXI_BRESP(M00_AXI_BRESP),                // input wire [1 : 0] M00_AXI_BRESP
  .M00_AXI_BVALID(M00_AXI_BVALID),              // input wire M00_AXI_BVALID
  .M00_AXI_BREADY(M00_AXI_BREADY),              // output wire M00_AXI_BREADY
  .M00_AXI_ARID(M00_AXI_ARID),                  // output wire [9 : 0] M00_AXI_ARID
  .M00_AXI_ARADDR(M00_AXI_ARADDR),              // output wire [63 : 0] M00_AXI_ARADDR
  .M00_AXI_ARLEN(M00_AXI_ARLEN),                // output wire [7 : 0] M00_AXI_ARLEN
  .M00_AXI_ARSIZE(M00_AXI_ARSIZE),              // output wire [2 : 0] M00_AXI_ARSIZE
  .M00_AXI_ARBURST(M00_AXI_ARBURST),            // output wire [1 : 0] M00_AXI_ARBURST
  .M00_AXI_ARLOCK(M00_AXI_ARLOCK),              // output wire M00_AXI_ARLOCK
  .M00_AXI_ARCACHE(M00_AXI_ARCACHE),            // output wire [3 : 0] M00_AXI_ARCACHE
  .M00_AXI_ARPROT(M00_AXI_ARPROT),              // output wire [2 : 0] M00_AXI_ARPROT
  .M00_AXI_ARQOS(M00_AXI_ARQOS),                // output wire [3 : 0] M00_AXI_ARQOS
  .M00_AXI_ARVALID(M00_AXI_ARVALID),            // output wire M00_AXI_ARVALID
  .M00_AXI_ARREADY(M00_AXI_ARREADY),            // input wire M00_AXI_ARREADY
  .M00_AXI_RID(M00_AXI_RID),                    // input wire [9 : 0] M00_AXI_RID
  .M00_AXI_RDATA(M00_AXI_RDATA),                // input wire [511 : 0] M00_AXI_RDATA
  .M00_AXI_RRESP(M00_AXI_RRESP),                // input wire [1 : 0] M00_AXI_RRESP
  .M00_AXI_RLAST(M00_AXI_RLAST),                // input wire M00_AXI_RLAST
  .M00_AXI_RVALID(M00_AXI_RVALID),              // input wire M00_AXI_RVALID
  .M00_AXI_RREADY(M00_AXI_RREADY)              // output wire M00_AXI_RREADY
);
// INST_TAG_END ------ End INSTANTIATION Template ---------

// You must compile the wrapper file axi_interconnect_top.v when simulating
// the core, axi_interconnect_top. When compiling the wrapper file, be sure to
// reference the Verilog simulation library.

