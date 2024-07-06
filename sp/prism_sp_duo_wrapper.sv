/*
 * Copyright (c) 2021-2024 Robert Drehmel
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
import taiga_config::*;
import taiga_types::*;
import l2_config_and_types::*;
import prism_sp_config::*;

/*
 * The naming scheme of tracing macros, signals and interfaces is
 * trace_<PREFIX>__TYPE
 */
//`define ENABLE_TRACE_RX__PROC
//`define ENABLE_TRACE_RX__SP_UNIT
//`define ENABLE_TRACE_RX__SP_UNIT_RX
//`define ENABLE_TRACE_RX__RX_PUZZLE
//`define ENABLE_TRACE_RX__RX_FIFO
//`define ENABLE_TRACE_TX__PROC
//`define ENABLE_TRACE_TX__SP_UNIT
//`define ENABLE_TRACE_TX__SP_UNIT_TX
//`define ENABLE_TRACE_TX__TX_PUZZLE
//`define ENABLE_TRACE_TX__CSUM
//`define ENABLE_TRACE_TX__ATF
//`define ENABLE_TRACE_TX__ATF_BDS

module prism_sp_duo_wrapper #(
	parameter int NRXCORES = 1,
	parameter int NTXCORES = 1,
	parameter int IBRAM_SIZE = 2**15,
	parameter int DBRAM_SIZE = 2**15,
	parameter int ACPBRAM_SIZE = 2*64*8,

	parameter int C_S_AXIL_ADDR_WIDTH = 32,
	parameter int C_S_AXIL_DATA_WIDTH = 32,

	parameter int C_M_AXI_MA_ID_WIDTH = 6,
	parameter int C_M_AXI_MA_ADDR_WIDTH = 40,
	parameter int C_M_AXI_MA_DATA_WIDTH = 64,

	parameter int C_M_AXI_MB_ID_WIDTH = 6,
	parameter int C_M_AXI_MB_ADDR_WIDTH = 40,
	parameter int C_M_AXI_MB_DATA_WIDTH = 32,

	parameter int C_M_AXI_MX_ID_WIDTH = 6,
	parameter int C_M_AXI_MX_ADDR_WIDTH = 40,
	parameter int C_M_AXI_MX_DATA_WIDTH = 32,

	parameter int C_S_AXI_SA_ID_WIDTH = 16,
	parameter int C_S_AXI_SA_ADDR_WIDTH = 40,
	parameter int C_S_AXI_SA_DATA_WIDTH = 128,

	parameter int C_S_AXI_SB_ID_WIDTH = 16,
	parameter int C_S_AXI_SB_ADDR_WIDTH = 40,
	parameter int C_S_AXI_SB_DATA_WIDTH = 128,

	parameter int C_M_AXI_ACP_ID_WIDTH = 5,
	parameter int C_M_AXI_ACP_ADDR_WIDTH = 40,
	parameter int C_M_AXI_ACP_DATA_WIDTH = 128,

	parameter int C_M_AXI_DMA_ID_WIDTH = 6,
	parameter int C_M_AXI_DMA_ADDR_WIDTH = 40,
	parameter int C_M_AXI_DMA_DATA_WIDTH = 32
)
(
	input wire clock,
	input wire resetn,

	output wire control_irq,

	output wire rx_channel_irq_0,
	output wire rx_channel_irq_1,
	output wire rx_channel_irq_2,
	output wire rx_channel_irq_3,

	output wire tx_channel_irq_0,
	output wire tx_channel_irq_1,
	output wire tx_channel_irq_2,
	output wire tx_channel_irq_3,

	/*
	 * AXI-lite slave interface
	 */
	input wire s_axil_0_awvalid,
	output wire s_axil_0_awready,
	input wire [C_S_AXIL_ADDR_WIDTH-1:0] s_axil_0_awaddr,
	input wire [2:0] s_axil_0_awprot,

	input wire s_axil_0_wvalid,
	output wire s_axil_0_wready,
	input wire [C_S_AXIL_DATA_WIDTH-1:0] s_axil_0_wdata,
	input wire [(C_S_AXIL_DATA_WIDTH/8)-1:0] s_axil_0_wstrb,

	output wire s_axil_0_bvalid,
	input wire s_axil_0_bready,
	output wire [1:0] s_axil_0_bresp,

	input wire s_axil_0_arvalid,
	output wire s_axil_0_arready,
	input wire [C_S_AXIL_ADDR_WIDTH-1:0] s_axil_0_araddr,
	input wire [2:0] s_axil_0_arprot,

	output wire s_axil_0_rvalid,
	input wire s_axil_0_rready,
	output wire [C_S_AXIL_DATA_WIDTH-1:0] s_axil_0_rdata,
	output wire [1:0] s_axil_0_rresp,

	/*
	 * AXI-lite slave interface
	 */
	input wire s_axil_1_awvalid,
	output wire s_axil_1_awready,
	input wire [C_S_AXIL_ADDR_WIDTH-1:0] s_axil_1_awaddr,
	input wire [2:0] s_axil_1_awprot,

	input wire s_axil_1_wvalid,
	output wire s_axil_1_wready,
	input wire [C_S_AXIL_DATA_WIDTH-1:0] s_axil_1_wdata,
	input wire [(C_S_AXIL_DATA_WIDTH/8)-1:0] s_axil_1_wstrb,

	output wire s_axil_1_bvalid,
	input wire s_axil_1_bready,
	output wire [1:0] s_axil_1_bresp,

	input wire s_axil_1_arvalid,
	output wire s_axil_1_arready,
	input wire [C_S_AXIL_ADDR_WIDTH-1:0] s_axil_1_araddr,
	input wire [2:0] s_axil_1_arprot,

	output wire s_axil_1_rvalid,
	input wire s_axil_1_rready,
	output wire [C_S_AXIL_DATA_WIDTH-1:0] s_axil_1_rdata,
	output wire [1:0] s_axil_1_rresp,

	/*
	 * IO-A access #0
	 * Access to classic in-memory ring buffer from H/W.
	 */
	output wire [C_M_AXI_MA_ID_WIDTH-1:0] m_axi_ma_0_awid,
	output wire [C_M_AXI_MA_ADDR_WIDTH-1:0] m_axi_ma_0_awaddr,
	output wire [7:0] m_axi_ma_0_awlen,
	output wire [2:0] m_axi_ma_0_awsize,
	output wire [1:0] m_axi_ma_0_awburst,
	output wire m_axi_ma_0_awlock,
	output wire [3:0] m_axi_ma_0_awcache,
	output wire [2:0] m_axi_ma_0_awprot,
	output wire m_axi_ma_0_awvalid,
	input wire m_axi_ma_0_awready,

	output wire [C_M_AXI_MA_DATA_WIDTH-1:0] m_axi_ma_0_wdata,
	output wire [(C_M_AXI_MA_DATA_WIDTH/8)-1:0] m_axi_ma_0_wstrb,
	output wire m_axi_ma_0_wlast,
	output wire m_axi_ma_0_wvalid,
	input wire m_axi_ma_0_wready,

	input wire [C_M_AXI_MA_ID_WIDTH-1:0] m_axi_ma_0_bid,
	input wire [1:0] m_axi_ma_0_bresp,
	input wire m_axi_ma_0_bvalid,
	output wire m_axi_ma_0_bready,

	output wire [C_M_AXI_MA_ID_WIDTH-1:0] m_axi_ma_0_arid,
	output wire [C_M_AXI_MA_ADDR_WIDTH-1:0] m_axi_ma_0_araddr,
	output wire [7:0] m_axi_ma_0_arlen,
	output wire [2:0] m_axi_ma_0_arsize,
	output wire [1:0] m_axi_ma_0_arburst,
	output wire m_axi_ma_0_arlock,
	output wire [3:0] m_axi_ma_0_arcache,
	output wire [2:0] m_axi_ma_0_arprot,
	output wire m_axi_ma_0_arvalid,
	input wire m_axi_ma_0_arready,

	input wire [C_M_AXI_MA_ID_WIDTH-1:0] m_axi_ma_0_rid,
	input wire [C_M_AXI_MA_DATA_WIDTH-1:0] m_axi_ma_0_rdata,
	input wire [1:0] m_axi_ma_0_rresp,
	input wire m_axi_ma_0_rlast,
	input wire m_axi_ma_0_rvalid,
	output wire m_axi_ma_0_rready,

	/*
	 * IO-A access #1
	 * Access to classic in-memory ring buffer from H/W.
	 */
	output wire [C_M_AXI_MA_ID_WIDTH-1:0] m_axi_ma_1_awid,
	output wire [C_M_AXI_MA_ADDR_WIDTH-1:0] m_axi_ma_1_awaddr,
	output wire [7:0] m_axi_ma_1_awlen,
	output wire [2:0] m_axi_ma_1_awsize,
	output wire [1:0] m_axi_ma_1_awburst,
	output wire m_axi_ma_1_awlock,
	output wire [3:0] m_axi_ma_1_awcache,
	output wire [2:0] m_axi_ma_1_awprot,
	output wire m_axi_ma_1_awvalid,
	input wire m_axi_ma_1_awready,

	output wire [C_M_AXI_MA_DATA_WIDTH-1:0] m_axi_ma_1_wdata,
	output wire [(C_M_AXI_MA_DATA_WIDTH/8)-1:0] m_axi_ma_1_wstrb,
	output wire m_axi_ma_1_wlast,
	output wire m_axi_ma_1_wvalid,
	input wire m_axi_ma_1_wready,

	input wire [C_M_AXI_MA_ID_WIDTH-1:0] m_axi_ma_1_bid,
	input wire [1:0] m_axi_ma_1_bresp,
	input wire m_axi_ma_1_bvalid,
	output wire m_axi_ma_1_bready,

	output wire [C_M_AXI_MA_ID_WIDTH-1:0] m_axi_ma_1_arid,
	output wire [C_M_AXI_MA_ADDR_WIDTH-1:0] m_axi_ma_1_araddr,
	output wire [7:0] m_axi_ma_1_arlen,
	output wire [2:0] m_axi_ma_1_arsize,
	output wire [1:0] m_axi_ma_1_arburst,
	output wire m_axi_ma_1_arlock,
	output wire [3:0] m_axi_ma_1_arcache,
	output wire [2:0] m_axi_ma_1_arprot,
	output wire m_axi_ma_1_arvalid,
	input wire m_axi_ma_1_arready,

	input wire [C_M_AXI_MA_ID_WIDTH-1:0] m_axi_ma_1_rid,
	input wire [C_M_AXI_MA_DATA_WIDTH-1:0] m_axi_ma_1_rdata,
	input wire [1:0] m_axi_ma_1_rresp,
	input wire m_axi_ma_1_rlast,
	input wire m_axi_ma_1_rvalid,
	output wire m_axi_ma_1_rready,

	/*
	 * IO-B access #0
	 */
	output wire [C_M_AXI_MB_ID_WIDTH-1:0] m_axi_mb_0_awid,
	output wire [C_M_AXI_MB_ADDR_WIDTH-1:0] m_axi_mb_0_awaddr,
	output wire [7:0] m_axi_mb_0_awlen,
	output wire [2:0] m_axi_mb_0_awsize,
	output wire [1:0] m_axi_mb_0_awburst,
	output wire m_axi_mb_0_awlock,
	output wire [3:0] m_axi_mb_0_awcache,
	output wire [2:0] m_axi_mb_0_awprot,
	output wire m_axi_mb_0_awvalid,
	input wire m_axi_mb_0_awready,

	output wire [C_M_AXI_MB_DATA_WIDTH-1:0] m_axi_mb_0_wdata,
	output wire [(C_M_AXI_MB_DATA_WIDTH/8)-1:0] m_axi_mb_0_wstrb,
	output wire m_axi_mb_0_wlast,
	output wire m_axi_mb_0_wvalid,
	input wire m_axi_mb_0_wready,

	input wire [C_M_AXI_MB_ID_WIDTH-1:0] m_axi_mb_0_bid,
	input wire [1:0] m_axi_mb_0_bresp,
	input wire m_axi_mb_0_bvalid,
	output wire m_axi_mb_0_bready,

	output wire [C_M_AXI_MB_ID_WIDTH-1:0] m_axi_mb_0_arid,
	output wire [C_M_AXI_MB_ADDR_WIDTH-1:0] m_axi_mb_0_araddr,
	output wire [7:0] m_axi_mb_0_arlen,
	output wire [2:0] m_axi_mb_0_arsize,
	output wire [1:0] m_axi_mb_0_arburst,
	output wire m_axi_mb_0_arlock,
	output wire [3:0] m_axi_mb_0_arcache,
	output wire [2:0] m_axi_mb_0_arprot,
	output wire m_axi_mb_0_arvalid,
	input wire m_axi_mb_0_arready,

	input wire [C_M_AXI_MB_ID_WIDTH-1:0] m_axi_mb_0_rid,
	input wire [C_M_AXI_MB_DATA_WIDTH-1:0] m_axi_mb_0_rdata,
	input wire [1:0] m_axi_mb_0_rresp,
	input wire m_axi_mb_0_rlast,
	input wire m_axi_mb_0_rvalid,
	output wire m_axi_mb_0_rready,

	/*
	 * IO-B access #1
	 */
	output wire [C_M_AXI_MB_ID_WIDTH-1:0] m_axi_mb_1_awid,
	output wire [C_M_AXI_MB_ADDR_WIDTH-1:0] m_axi_mb_1_awaddr,
	output wire [7:0] m_axi_mb_1_awlen,
	output wire [2:0] m_axi_mb_1_awsize,
	output wire [1:0] m_axi_mb_1_awburst,
	output wire m_axi_mb_1_awlock,
	output wire [3:0] m_axi_mb_1_awcache,
	output wire [2:0] m_axi_mb_1_awprot,
	output wire m_axi_mb_1_awvalid,
	input wire m_axi_mb_1_awready,

	output wire [C_M_AXI_MB_DATA_WIDTH-1:0] m_axi_mb_1_wdata,
	output wire [(C_M_AXI_MB_DATA_WIDTH/8)-1:0] m_axi_mb_1_wstrb,
	output wire m_axi_mb_1_wlast,
	output wire m_axi_mb_1_wvalid,
	input wire m_axi_mb_1_wready,

	input wire [C_M_AXI_MB_ID_WIDTH-1:0] m_axi_mb_1_bid,
	input wire [1:0] m_axi_mb_1_bresp,
	input wire m_axi_mb_1_bvalid,
	output wire m_axi_mb_1_bready,

	output wire [C_M_AXI_MB_ID_WIDTH-1:0] m_axi_mb_1_arid,
	output wire [C_M_AXI_MB_ADDR_WIDTH-1:0] m_axi_mb_1_araddr,
	output wire [7:0] m_axi_mb_1_arlen,
	output wire [2:0] m_axi_mb_1_arsize,
	output wire [1:0] m_axi_mb_1_arburst,
	output wire m_axi_mb_1_arlock,
	output wire [3:0] m_axi_mb_1_arcache,
	output wire [2:0] m_axi_mb_1_arprot,
	output wire m_axi_mb_1_arvalid,
	input wire m_axi_mb_1_arready,

	input wire [C_M_AXI_MB_ID_WIDTH-1:0] m_axi_mb_1_rid,
	input wire [C_M_AXI_MB_DATA_WIDTH-1:0] m_axi_mb_1_rdata,
	input wire [1:0] m_axi_mb_1_rresp,
	input wire m_axi_mb_1_rlast,
	input wire m_axi_mb_1_rvalid,
	output wire m_axi_mb_1_rready,

	/*
	 * IO-X access #0
	 * Access to classic in-memory ring buffer from processor.
	 */
	output wire [C_M_AXI_MX_ID_WIDTH-1:0] m_axi_mx_0_awid,
	output wire [C_M_AXI_MX_ADDR_WIDTH-1:0] m_axi_mx_0_awaddr,
	output wire [7:0] m_axi_mx_0_awlen,
	output wire [2:0] m_axi_mx_0_awsize,
	output wire [1:0] m_axi_mx_0_awburst,
	output wire m_axi_mx_0_awlock,
	output wire [3:0] m_axi_mx_0_awcache,
	output wire [2:0] m_axi_mx_0_awprot,
	output wire m_axi_mx_0_awvalid,
	input wire m_axi_mx_0_awready,

	output wire [C_M_AXI_MX_DATA_WIDTH-1:0] m_axi_mx_0_wdata,
	output wire [(C_M_AXI_MX_DATA_WIDTH/8)-1:0] m_axi_mx_0_wstrb,
	output wire m_axi_mx_0_wlast,
	output wire m_axi_mx_0_wvalid,
	input wire m_axi_mx_0_wready,

	input wire [C_M_AXI_MX_ID_WIDTH-1:0] m_axi_mx_0_bid,
	input wire [1:0] m_axi_mx_0_bresp,
	input wire m_axi_mx_0_bvalid,
	output wire m_axi_mx_0_bready,

	output wire [C_M_AXI_MX_ID_WIDTH-1:0] m_axi_mx_0_arid,
	output wire [C_M_AXI_MX_ADDR_WIDTH-1:0] m_axi_mx_0_araddr,
	output wire [7:0] m_axi_mx_0_arlen,
	output wire [2:0] m_axi_mx_0_arsize,
	output wire [1:0] m_axi_mx_0_arburst,
	output wire m_axi_mx_0_arlock,
	output wire [3:0] m_axi_mx_0_arcache,
	output wire [2:0] m_axi_mx_0_arprot,
	output wire m_axi_mx_0_arvalid,
	input wire m_axi_mx_0_arready,

	input wire [C_M_AXI_MX_ID_WIDTH-1:0] m_axi_mx_0_rid,
	input wire [C_M_AXI_MX_DATA_WIDTH-1:0] m_axi_mx_0_rdata,
	input wire [1:0] m_axi_mx_0_rresp,
	input wire m_axi_mx_0_rlast,
	input wire m_axi_mx_0_rvalid,
	output wire m_axi_mx_0_rready,

	/*
	 * IO-X access #1
	 * Access to classic in-memory ring buffer from processor.
	 */
	output wire [C_M_AXI_MX_ID_WIDTH-1:0] m_axi_mx_1_awid,
	output wire [C_M_AXI_MX_ADDR_WIDTH-1:0] m_axi_mx_1_awaddr,
	output wire [7:0] m_axi_mx_1_awlen,
	output wire [2:0] m_axi_mx_1_awsize,
	output wire [1:0] m_axi_mx_1_awburst,
	output wire m_axi_mx_1_awlock,
	output wire [3:0] m_axi_mx_1_awcache,
	output wire [2:0] m_axi_mx_1_awprot,
	output wire m_axi_mx_1_awvalid,
	input wire m_axi_mx_1_awready,

	output wire [C_M_AXI_MX_DATA_WIDTH-1:0] m_axi_mx_1_wdata,
	output wire [(C_M_AXI_MX_DATA_WIDTH/8)-1:0] m_axi_mx_1_wstrb,
	output wire m_axi_mx_1_wlast,
	output wire m_axi_mx_1_wvalid,
	input wire m_axi_mx_1_wready,

	input wire [C_M_AXI_MX_ID_WIDTH-1:0] m_axi_mx_1_bid,
	input wire [1:0] m_axi_mx_1_bresp,
	input wire m_axi_mx_1_bvalid,
	output wire m_axi_mx_1_bready,

	output wire [C_M_AXI_MX_ID_WIDTH-1:0] m_axi_mx_1_arid,
	output wire [C_M_AXI_MX_ADDR_WIDTH-1:0] m_axi_mx_1_araddr,
	output wire [7:0] m_axi_mx_1_arlen,
	output wire [2:0] m_axi_mx_1_arsize,
	output wire [1:0] m_axi_mx_1_arburst,
	output wire m_axi_mx_1_arlock,
	output wire [3:0] m_axi_mx_1_arcache,
	output wire [2:0] m_axi_mx_1_arprot,
	output wire m_axi_mx_1_arvalid,
	input wire m_axi_mx_1_arready,

	input wire [C_M_AXI_MX_ID_WIDTH-1:0] m_axi_mx_1_rid,
	input wire [C_M_AXI_MX_DATA_WIDTH-1:0] m_axi_mx_1_rdata,
	input wire [1:0] m_axi_mx_1_rresp,
	input wire m_axi_mx_1_rlast,
	input wire m_axi_mx_1_rvalid,
	output wire m_axi_mx_1_rready,

	/*
	 * AXI interface for input queue access (core 0)
	 */
	input wire [C_S_AXI_SA_ID_WIDTH-1:0] s_axi_sa_0_awid,
	input wire [C_S_AXI_SA_ADDR_WIDTH-1:0] s_axi_sa_0_awaddr,
	input wire [7:0] s_axi_sa_0_awlen,
	input wire [2:0] s_axi_sa_0_awsize,
	input wire [1:0] s_axi_sa_0_awburst,
	input wire s_axi_sa_0_awlock,
	input wire [3:0] s_axi_sa_0_awcache,
	input wire [2:0] s_axi_sa_0_awprot,
	input wire s_axi_sa_0_awvalid,
	output wire s_axi_sa_0_awready,

	input wire [C_S_AXI_SA_DATA_WIDTH-1:0] s_axi_sa_0_wdata,
	input wire [(C_S_AXI_SA_DATA_WIDTH/8)-1:0] s_axi_sa_0_wstrb,
	input wire s_axi_sa_0_wlast,
	input wire s_axi_sa_0_wvalid,
	output wire s_axi_sa_0_wready,

	output wire [C_S_AXI_SA_ID_WIDTH-1:0] s_axi_sa_0_bid,
	output wire [1:0] s_axi_sa_0_bresp,
	output wire s_axi_sa_0_bvalid,
	input wire s_axi_sa_0_bready,

	input wire [C_S_AXI_SA_ID_WIDTH-1:0] s_axi_sa_0_arid,
	input wire [C_S_AXI_SA_ADDR_WIDTH-1:0] s_axi_sa_0_araddr,
	input wire [7:0] s_axi_sa_0_arlen,
	input wire [2:0] s_axi_sa_0_arsize,
	input wire [1:0] s_axi_sa_0_arburst,
	input wire s_axi_sa_0_arlock,
	input wire [3:0] s_axi_sa_0_arcache,
	input wire [2:0] s_axi_sa_0_arprot,
	input wire s_axi_sa_0_arvalid,
	output wire s_axi_sa_0_arready,

	output wire [C_S_AXI_SA_ID_WIDTH-1:0] s_axi_sa_0_rid,
	output wire [C_S_AXI_SA_DATA_WIDTH-1:0] s_axi_sa_0_rdata,
	output wire [1:0] s_axi_sa_0_rresp,
	output wire s_axi_sa_0_rlast,
	output wire s_axi_sa_0_rvalid,
	input wire s_axi_sa_0_rready,

	/*
	 * AXI interface for input queue access (core 1)
	 */
	input wire [C_S_AXI_SA_ID_WIDTH-1:0] s_axi_sa_1_awid,
	input wire [C_S_AXI_SA_ADDR_WIDTH-1:0] s_axi_sa_1_awaddr,
	input wire [7:0] s_axi_sa_1_awlen,
	input wire [2:0] s_axi_sa_1_awsize,
	input wire [1:0] s_axi_sa_1_awburst,
	input wire s_axi_sa_1_awlock,
	input wire [3:0] s_axi_sa_1_awcache,
	input wire [2:0] s_axi_sa_1_awprot,
	input wire s_axi_sa_1_awvalid,
	output wire s_axi_sa_1_awready,

	input wire [C_S_AXI_SA_DATA_WIDTH-1:0] s_axi_sa_1_wdata,
	input wire [(C_S_AXI_SA_DATA_WIDTH/8)-1:0] s_axi_sa_1_wstrb,
	input wire s_axi_sa_1_wlast,
	input wire s_axi_sa_1_wvalid,
	output wire s_axi_sa_1_wready,

	output wire [C_S_AXI_SA_ID_WIDTH-1:0] s_axi_sa_1_bid,
	output wire [1:0] s_axi_sa_1_bresp,
	output wire s_axi_sa_1_bvalid,
	input wire s_axi_sa_1_bready,

	input wire [C_S_AXI_SA_ID_WIDTH-1:0] s_axi_sa_1_arid,
	input wire [C_S_AXI_SA_ADDR_WIDTH-1:0] s_axi_sa_1_araddr,
	input wire [7:0] s_axi_sa_1_arlen,
	input wire [2:0] s_axi_sa_1_arsize,
	input wire [1:0] s_axi_sa_1_arburst,
	input wire s_axi_sa_1_arlock,
	input wire [3:0] s_axi_sa_1_arcache,
	input wire [2:0] s_axi_sa_1_arprot,
	input wire s_axi_sa_1_arvalid,
	output wire s_axi_sa_1_arready,

	output wire [C_S_AXI_SA_ID_WIDTH-1:0] s_axi_sa_1_rid,
	output wire [C_S_AXI_SA_DATA_WIDTH-1:0] s_axi_sa_1_rdata,
	output wire [1:0] s_axi_sa_1_rresp,
	output wire s_axi_sa_1_rlast,
	output wire s_axi_sa_1_rvalid,
	input wire s_axi_sa_1_rready,

	/*
	 * AXI interface for output queue access (core 0)
	 */
	input wire [C_S_AXI_SB_ID_WIDTH-1:0] s_axi_sb_0_awid,
	input wire [C_S_AXI_SB_ADDR_WIDTH-1:0] s_axi_sb_0_awaddr,
	input wire [7:0] s_axi_sb_0_awlen,
	input wire [2:0] s_axi_sb_0_awsize,
	input wire [1:0] s_axi_sb_0_awburst,
	input wire s_axi_sb_0_awlock,
	input wire [3:0] s_axi_sb_0_awcache,
	input wire [2:0] s_axi_sb_0_awprot,
	input wire s_axi_sb_0_awvalid,
	output wire s_axi_sb_0_awready,

	input wire [C_S_AXI_SB_DATA_WIDTH-1:0] s_axi_sb_0_wdata,
	input wire [(C_S_AXI_SB_DATA_WIDTH/8)-1:0] s_axi_sb_0_wstrb,
	input wire s_axi_sb_0_wlast,
	input wire s_axi_sb_0_wvalid,
	output wire s_axi_sb_0_wready,

	output wire [C_S_AXI_SB_ID_WIDTH-1:0] s_axi_sb_0_bid,
	output wire [1:0] s_axi_sb_0_bresp,
	output wire s_axi_sb_0_bvalid,
	input wire s_axi_sb_0_bready,

	input wire [C_S_AXI_SB_ID_WIDTH-1:0] s_axi_sb_0_arid,
	input wire [C_S_AXI_SB_ADDR_WIDTH-1:0] s_axi_sb_0_araddr,
	input wire [7:0] s_axi_sb_0_arlen,
	input wire [2:0] s_axi_sb_0_arsize,
	input wire [1:0] s_axi_sb_0_arburst,
	input wire s_axi_sb_0_arlock,
	input wire [3:0] s_axi_sb_0_arcache,
	input wire [2:0] s_axi_sb_0_arprot,
	input wire s_axi_sb_0_arvalid,
	output wire s_axi_sb_0_arready,

	output wire [C_S_AXI_SB_ID_WIDTH-1:0] s_axi_sb_0_rid,
	output wire [C_S_AXI_SB_DATA_WIDTH-1:0] s_axi_sb_0_rdata,
	output wire [1:0] s_axi_sb_0_rresp,
	output wire s_axi_sb_0_rlast,
	output wire s_axi_sb_0_rvalid,
	input wire s_axi_sb_0_rready,

	/*
	 * AXI interface for output queue access (core 1)
	 */
	input wire [C_S_AXI_SB_ID_WIDTH-1:0] s_axi_sb_1_awid,
	input wire [C_S_AXI_SB_ADDR_WIDTH-1:0] s_axi_sb_1_awaddr,
	input wire [7:0] s_axi_sb_1_awlen,
	input wire [2:0] s_axi_sb_1_awsize,
	input wire [1:0] s_axi_sb_1_awburst,
	input wire s_axi_sb_1_awlock,
	input wire [3:0] s_axi_sb_1_awcache,
	input wire [2:0] s_axi_sb_1_awprot,
	input wire s_axi_sb_1_awvalid,
	output wire s_axi_sb_1_awready,

	input wire [C_S_AXI_SB_DATA_WIDTH-1:0] s_axi_sb_1_wdata,
	input wire [(C_S_AXI_SB_DATA_WIDTH/8)-1:0] s_axi_sb_1_wstrb,
	input wire s_axi_sb_1_wlast,
	input wire s_axi_sb_1_wvalid,
	output wire s_axi_sb_1_wready,

	output wire [C_S_AXI_SB_ID_WIDTH-1:0] s_axi_sb_1_bid,
	output wire [1:0] s_axi_sb_1_bresp,
	output wire s_axi_sb_1_bvalid,
	input wire s_axi_sb_1_bready,

	input wire [C_S_AXI_SB_ID_WIDTH-1:0] s_axi_sb_1_arid,
	input wire [C_S_AXI_SB_ADDR_WIDTH-1:0] s_axi_sb_1_araddr,
	input wire [7:0] s_axi_sb_1_arlen,
	input wire [2:0] s_axi_sb_1_arsize,
	input wire [1:0] s_axi_sb_1_arburst,
	input wire s_axi_sb_1_arlock,
	input wire [3:0] s_axi_sb_1_arcache,
	input wire [2:0] s_axi_sb_1_arprot,
	input wire s_axi_sb_1_arvalid,
	output wire s_axi_sb_1_arready,

	output wire [C_S_AXI_SB_ID_WIDTH-1:0] s_axi_sb_1_rid,
	output wire [C_S_AXI_SB_DATA_WIDTH-1:0] s_axi_sb_1_rdata,
	output wire [1:0] s_axi_sb_1_rresp,
	output wire s_axi_sb_1_rlast,
	output wire s_axi_sb_1_rvalid,
	input wire s_axi_sb_1_rready,

	/*
	 * ACP access
	 */
	output wire [C_M_AXI_ACP_ID_WIDTH-1:0] m_axi_acp_0_awid,
	output wire [C_M_AXI_ACP_ADDR_WIDTH-1:0] m_axi_acp_0_awaddr,
	output wire [7:0] m_axi_acp_0_awlen,
	output wire [2:0] m_axi_acp_0_awsize,
	output wire [1:0] m_axi_acp_0_awburst,
	output wire m_axi_acp_0_awlock,
	output wire [3:0] m_axi_acp_0_awcache,
	output wire [2:0] m_axi_acp_0_awprot,
	// This is needed and cannot be driven 2'b11 (UG1085)
	output wire [1:0] m_axi_acp_0_awuser,
	output wire m_axi_acp_0_awvalid,
	input wire m_axi_acp_0_awready,

	output wire [C_M_AXI_ACP_DATA_WIDTH-1:0] m_axi_acp_0_wdata,
	output wire [(C_M_AXI_ACP_DATA_WIDTH/8)-1:0] m_axi_acp_0_wstrb,
	output wire m_axi_acp_0_wlast,
	output wire m_axi_acp_0_wvalid,
	input wire m_axi_acp_0_wready,

	input wire [C_M_AXI_ACP_ID_WIDTH-1:0] m_axi_acp_0_bid,
	input wire [1:0] m_axi_acp_0_bresp,
	input wire m_axi_acp_0_bvalid,
	output wire m_axi_acp_0_bready,

	output wire [C_M_AXI_ACP_ID_WIDTH-1:0] m_axi_acp_0_arid,
	output wire [C_M_AXI_ACP_ADDR_WIDTH-1:0] m_axi_acp_0_araddr,
	output wire [7:0] m_axi_acp_0_arlen,
	output wire [2:0] m_axi_acp_0_arsize,
	output wire [1:0] m_axi_acp_0_arburst,
	output wire m_axi_acp_0_arlock,
	output wire [3:0] m_axi_acp_0_arcache,
	output wire [2:0] m_axi_acp_0_arprot,
	// This is needed and cannot be driven 2'b11 (UG1085)
	output wire [1:0] m_axi_acp_0_aruser,
	output wire m_axi_acp_0_arvalid,
	input wire m_axi_acp_0_arready,

	input wire [C_M_AXI_ACP_ID_WIDTH-1:0] m_axi_acp_0_rid,
	input wire [C_M_AXI_ACP_DATA_WIDTH-1:0] m_axi_acp_0_rdata,
	input wire [1:0] m_axi_acp_0_rresp,
	input wire m_axi_acp_0_rlast,
	input wire m_axi_acp_0_rvalid,
	output wire m_axi_acp_0_rready,

	/*
	 * ACP access
	 */
	output wire [C_M_AXI_ACP_ID_WIDTH-1:0] m_axi_acp_1_awid,
	output wire [C_M_AXI_ACP_ADDR_WIDTH-1:0] m_axi_acp_1_awaddr,
	output wire [7:0] m_axi_acp_1_awlen,
	output wire [2:0] m_axi_acp_1_awsize,
	output wire [1:0] m_axi_acp_1_awburst,
	output wire m_axi_acp_1_awlock,
	output wire [3:0] m_axi_acp_1_awcache,
	output wire [2:0] m_axi_acp_1_awprot,
	// This is needed and cannot be driven 2'b11 (UG1085)
	output wire [1:0] m_axi_acp_1_awuser,
	output wire m_axi_acp_1_awvalid,
	input wire m_axi_acp_1_awready,

	output wire [C_M_AXI_ACP_DATA_WIDTH-1:0] m_axi_acp_1_wdata,
	output wire [(C_M_AXI_ACP_DATA_WIDTH/8)-1:0] m_axi_acp_1_wstrb,
	output wire m_axi_acp_1_wlast,
	output wire m_axi_acp_1_wvalid,
	input wire m_axi_acp_1_wready,

	input wire [C_M_AXI_ACP_ID_WIDTH-1:0] m_axi_acp_1_bid,
	input wire [1:0] m_axi_acp_1_bresp,
	input wire m_axi_acp_1_bvalid,
	output wire m_axi_acp_1_bready,

	output wire [C_M_AXI_ACP_ID_WIDTH-1:0] m_axi_acp_1_arid,
	output wire [C_M_AXI_ACP_ADDR_WIDTH-1:0] m_axi_acp_1_araddr,
	output wire [7:0] m_axi_acp_1_arlen,
	output wire [2:0] m_axi_acp_1_arsize,
	output wire [1:0] m_axi_acp_1_arburst,
	output wire m_axi_acp_1_arlock,
	output wire [3:0] m_axi_acp_1_arcache,
	output wire [2:0] m_axi_acp_1_arprot,
	// This is needed and cannot be driven 2'b11 (UG1085)
	output wire [1:0] m_axi_acp_1_aruser,
	output wire m_axi_acp_1_arvalid,
	input wire m_axi_acp_1_arready,

	input wire [C_M_AXI_ACP_ID_WIDTH-1:0] m_axi_acp_1_rid,
	input wire [C_M_AXI_ACP_DATA_WIDTH-1:0] m_axi_acp_1_rdata,
	input wire [1:0] m_axi_acp_1_rresp,
	input wire m_axi_acp_1_rlast,
	input wire m_axi_acp_1_rvalid,
	output wire m_axi_acp_1_rready,

	/*
	 * GEM DMA
	 */
	output wire [C_M_AXI_DMA_ID_WIDTH-1:0] m_axi_dma_0_arid,
	output wire [C_M_AXI_DMA_ADDR_WIDTH-1:0] m_axi_dma_0_araddr,
	output wire [7:0] m_axi_dma_0_arlen,
	output wire [2:0] m_axi_dma_0_arsize,
	output wire [1:0] m_axi_dma_0_arburst,
	output wire m_axi_dma_0_arlock,
	output wire [3:0] m_axi_dma_0_arcache,
	output wire [2:0] m_axi_dma_0_arprot,
	output wire m_axi_dma_0_arvalid,
	input wire m_axi_dma_0_arready,

	input wire [C_M_AXI_DMA_ID_WIDTH-1:0] m_axi_dma_0_rid,
	input wire [C_M_AXI_DMA_DATA_WIDTH-1:0] m_axi_dma_0_rdata,
	input wire [1:0] m_axi_dma_0_rresp,
	input wire m_axi_dma_0_rlast,
	input wire m_axi_dma_0_rvalid,
	output wire m_axi_dma_0_rready,

	output wire [C_M_AXI_DMA_ID_WIDTH-1:0] m_axi_dma_0_awid,
	output wire [C_M_AXI_DMA_ADDR_WIDTH-1:0] m_axi_dma_0_awaddr,
	output wire [7:0] m_axi_dma_0_awlen,
	output wire [2:0] m_axi_dma_0_awsize,
	output wire [1:0] m_axi_dma_0_awburst,
	output wire m_axi_dma_0_awlock,
	output wire [3:0] m_axi_dma_0_awcache,
	output wire [2:0] m_axi_dma_0_awprot,
	output wire m_axi_dma_0_awvalid,
	input wire m_axi_dma_0_awready,

	output wire [C_M_AXI_DMA_DATA_WIDTH-1:0] m_axi_dma_0_wdata,
	output wire [(C_M_AXI_DMA_DATA_WIDTH/8)-1:0] m_axi_dma_0_wstrb,
	output wire m_axi_dma_0_wlast,
	output wire m_axi_dma_0_wvalid,
	input wire m_axi_dma_0_wready,

	input wire [C_M_AXI_DMA_ID_WIDTH-1:0] m_axi_dma_0_bid,
	input wire [1:0] m_axi_dma_0_bresp,
	input wire m_axi_dma_0_bvalid,
	output wire m_axi_dma_0_bready,

	/*
	 * GEM Interface
	 */
	input wire gem_tx_clock,
	input wire gem_tx_resetn,
	output wire gem_tx_r_data_rdy,
	input wire gem_tx_r_rd,
	output wire gem_tx_r_valid,
	output wire [7:0] gem_tx_r_data,
	output wire gem_tx_r_sop,
	output wire gem_tx_r_eop,
	output wire gem_tx_r_err,
	output wire gem_tx_r_underflow,
	output wire gem_tx_r_flushed,
	output wire gem_tx_r_control,
	input wire [3:0] gem_tx_r_status,
	input wire gem_tx_r_fixed_lat,
	input wire gem_dma_tx_end_tog,
	output wire gem_dma_tx_status_tog,

	input wire gem_rx_clock,
	input wire gem_rx_resetn,
	input wire gem_rx_w_wr,
	input wire [31:0] gem_rx_w_data,
	input wire gem_rx_w_sop,
	input wire gem_rx_w_eop,
	input wire [44:0] gem_rx_w_status,
	input wire gem_rx_w_err,
	output wire gem_rx_w_overflow,
	input wire gem_rx_w_flush

	/*
	 *
	 * RX
	 *
	 */
`ifdef ENABLE_TRACE_RX__PROC
	// ------
	,output wire trace_rx__proc_operand_stall,
	output wire trace_rx__proc_unit_stall,
	output wire trace_rx__proc_no_id_stall,
	output wire trace_rx__proc_no_instruction_stall,
	output wire trace_rx__proc_other_stall,
	output wire trace_rx__proc_instruction_issued_dec,
	output wire trace_rx__proc_branch_operand_stall,
	output wire trace_rx__proc_alu_operand_stall,
	output wire trace_rx__proc_ls_operand_stall,
	output wire trace_rx__proc_div_operand_stall,
	output wire trace_rx__proc_alu_op,
	output wire trace_rx__proc_branch_or_jump_op,
	output wire trace_rx__proc_load_op,
	output wire trace_rx__proc_lr,
	output wire trace_rx__proc_store_op,
	output wire trace_rx__proc_sc,
	output wire trace_rx__proc_mul_op,
	output wire trace_rx__proc_div_op,
	output wire trace_rx__proc_misc_op,
	output wire trace_rx__proc_branch_correct,
	output wire trace_rx__proc_branch_misspredict,
	output wire trace_rx__proc_rs1_forwarding_needed,
	output wire trace_rx__proc_rs2_forwarding_needed,
	output wire trace_rx__proc_rs1_and_rs2_forwarding_needed,
        //unit_id_t num_instructions_completing;
        //id_t num_instructions_in_flight;
        //id_t num_of_instructions_pending_writeback;
	output wire [31:0] trace_rx__proc_instruction_pc_dec,
	output wire [31:0] trace_rx__proc_instruction_data_dec
	// ------
`endif

`ifdef ENABLE_TRACE_RX__SP_UNIT
	,output wire trace_rx__sp_unit_acp_read_start,
	output wire trace_rx__sp_unit_acp_read_status,
	output wire trace_rx__sp_unit_acp_write_start,
	output wire trace_rx__sp_unit_acp_write_status
`endif

`ifdef ENABLE_TRACE_RX__SP_UNIT_RX
	,output wire trace_rx__sp_unit_rx_rx_meta_pop,
	output wire trace_rx__sp_unit_rx_rx_meta_empty,
	output wire trace_rx__sp_unit_rx_rx_data_dma_start,
	output wire trace_rx__sp_unit_rx_rx_data_dma_status,
	output wire trace_rx__sp_unit_rx_rx_dma_busy
`endif

`ifdef ENABLE_TRACE_RX__RX_PUZZLE
	,output wire trace_rx__rxenable,
	output wire trace_rx__rxtrigger,

	output wire trace_rx__rx_puzzle_fifo_r_0_empty,
	output wire trace_rx__rx_puzzle_fifo_r_0_rd_en,
	output wire [128+64-1:0] trace_rx__rx_puzzle_fifo_r_0_rd_data,
	output wire [15:0] trace_rx__rx_puzzle_fifo_r_0_rd_data_count,
	output wire trace_rx__rx_puzzle_fifo_r_1_empty,
	output wire trace_rx__rx_puzzle_fifo_r_1_rd_en,
	output wire [128+64-1:0] trace_rx__rx_puzzle_fifo_r_1_rd_data,
	output wire [15:0] trace_rx__rx_puzzle_fifo_r_1_rd_data_count,
	output wire trace_rx__rx_puzzle_fifo_r_2_empty,
	output wire trace_rx__rx_puzzle_fifo_r_2_rd_en,
	output wire [128+64-1:0] trace_rx__rx_puzzle_fifo_r_2_rd_data,
	output wire [15:0] trace_rx__rx_puzzle_fifo_r_2_rd_data_count,
	output wire trace_rx__rx_puzzle_fifo_r_3_empty,
	output wire trace_rx__rx_puzzle_fifo_r_3_rd_en,
	output wire [128+64-1:0] trace_rx__rx_puzzle_fifo_r_3_rd_data,
	output wire [15:0] trace_rx__rx_puzzle_fifo_r_3_rd_data_count,

	output wire trace_rx__rx_puzzle_fifo_w_0_full,
	output wire trace_rx__rx_puzzle_fifo_w_0_wr_en,
	output wire [128+64-1:0] trace_rx__rx_puzzle_fifo_w_0_wr_data,
	output wire [15:0] trace_rx__rx_puzzle_fifo_w_0_wr_data_count,
	output wire trace_rx__rx_puzzle_fifo_w_1_full,
	output wire trace_rx__rx_puzzle_fifo_w_1_wr_en,
	output wire [128+64-1:0] trace_rx__rx_puzzle_fifo_w_1_wr_data,
	output wire [15:0] trace_rx__rx_puzzle_fifo_w_1_wr_data_count,
	output wire trace_rx__rx_puzzle_fifo_w_2_full,
	output wire trace_rx__rx_puzzle_fifo_w_2_wr_en,
	output wire [128+64-1:0] trace_rx__rx_puzzle_fifo_w_2_wr_data,
	output wire [15:0] trace_rx__rx_puzzle_fifo_w_2_wr_data_count,
	output wire trace_rx__rx_puzzle_fifo_w_3_full,
	output wire trace_rx__rx_puzzle_fifo_w_3_wr_en,
	output wire [128+64-1:0] trace_rx__rx_puzzle_fifo_w_3_wr_data,
	output wire [15:0] trace_rx__rx_puzzle_fifo_w_3_wr_data_count
`endif

`ifdef ENABLE_TRACE_RX__RX_PUZZLE
	,output wire trace_rx__rx_fifo_meta_fifo_r_empty,
	output wire trace_rx__rx_fifo_meta_fifo_r_rd_en,
	output wire [128+64-1:0] trace_rx__rx_fifo_meta_fifo_r_rd_data,
	output wire [15:0] trace_rx__rx_fifo_meta_fifo_r_rd_data_count,
	output wire trace_rx__rx_fifo_meta_fifo_w_full,
	output wire trace_rx__rx_fifo_meta_fifo_w_wr_en,
	output wire [128+64-1:0] trace_rx__rx_fifo_meta_fifo_w_wr_data,
	output wire [15:0] trace_rx__rx_fifo_meta_fifo_w_wr_data_count
`endif

	/*
	 *
	 * TX
	 *
	 */
`ifdef ENABLE_TRACE_TX__PROC
	// ------
	,output wire trace_tx__proc_operand_stall,
	output wire trace_tx__proc_unit_stall,
	output wire trace_tx__proc_no_id_stall,
	output wire trace_tx__proc_no_instruction_stall,
	output wire trace_tx__proc_other_stall,
	output wire trace_tx__proc_instruction_issued_dec,
	output wire trace_tx__proc_branch_operand_stall,
	output wire trace_tx__proc_alu_operand_stall,
	output wire trace_tx__proc_ls_operand_stall,
	output wire trace_tx__proc_div_operand_stall,
	output wire trace_tx__proc_alu_op,
	output wire trace_tx__proc_branch_or_jump_op,
	output wire trace_tx__proc_load_op,
	output wire trace_tx__proc_lr,
	output wire trace_tx__proc_store_op,
	output wire trace_tx__proc_sc,
	output wire trace_tx__proc_mul_op,
	output wire trace_tx__proc_div_op,
	output wire trace_tx__proc_misc_op,
	output wire trace_tx__proc_branch_correct,
	output wire trace_tx__proc_branch_misspredict,
	output wire trace_tx__proc_rs1_forwarding_needed,
	output wire trace_tx__proc_rs2_forwarding_needed,
	output wire trace_tx__proc_rs1_and_rs2_forwarding_needed,
        //unit_id_t num_instructions_completing;
        //id_t num_instructions_in_flight;
        //id_t num_of_instructions_pending_writeback;
	output wire [31:0] trace_tx__proc_instruction_pc_dec,
	output wire [31:0] trace_tx__proc_instruction_data_dec
	// ------
`endif

`ifdef ENABLE_TRACE_TX__SP_UNIT
	,output wire trace_tx__sp_unit_acp_read_start,
	output wire trace_tx__sp_unit_acp_read_status,
	output wire trace_tx__sp_unit_acp_write_start,
	output wire trace_tx__sp_unit_acp_write_status
`endif

`ifdef ENABLE_TRACE_TX__SP_UNIT_TX
	,output wire trace_tx__sp_unit_tx_tx_meta_push,
	output wire trace_tx__sp_unit_tx_tx_meta_full,
	output wire trace_tx__sp_unit_tx_tx_data_dma_start,
	output wire trace_tx__sp_unit_tx_tx_data_dma_status,
	output wire trace_tx__sp_unit_tx_tx_dma_busy
`endif

`ifdef ENABLE_TRACE_TX__TX_PUZZLE
	,output wire trace_tx__txenable,
	output wire trace_tx__txtrigger,

	output wire trace_tx__tx_puzzle_fifo_r_0_empty,
	output wire trace_tx__tx_puzzle_fifo_r_0_rd_en,
	output wire [128+64-1:0] trace_tx__tx_puzzle_fifo_r_0_rd_data,
	output wire [15:0] trace_tx__tx_puzzle_fifo_r_0_rd_data_count,
	output wire trace_tx__tx_puzzle_fifo_r_1_empty,
	output wire trace_tx__tx_puzzle_fifo_r_1_rd_en,
	output wire [128+64-1:0] trace_tx__tx_puzzle_fifo_r_1_rd_data,
	output wire [15:0] trace_tx__tx_puzzle_fifo_r_1_rd_data_count,
	output wire trace_tx__tx_puzzle_fifo_r_2_empty,
	output wire trace_tx__tx_puzzle_fifo_r_2_rd_en,
	output wire [128+64-1:0] trace_tx__tx_puzzle_fifo_r_2_rd_data,
	output wire [15:0] trace_tx__tx_puzzle_fifo_r_2_rd_data_count,
	output wire trace_tx__tx_puzzle_fifo_r_3_empty,
	output wire trace_tx__tx_puzzle_fifo_r_3_rd_en,
	output wire [128+64-1:0] trace_tx__tx_puzzle_fifo_r_3_rd_data,
	output wire [15:0] trace_tx__tx_puzzle_fifo_r_3_rd_data_count,

	output wire trace_tx__tx_puzzle_fifo_w_0_full,
	output wire trace_tx__tx_puzzle_fifo_w_0_wr_en,
	output wire [128+64-1:0] trace_tx__tx_puzzle_fifo_w_0_wr_data,
	output wire [15:0] trace_tx__tx_puzzle_fifo_w_0_wr_data_count,
	output wire trace_tx__tx_puzzle_fifo_w_1_full,
	output wire trace_tx__tx_puzzle_fifo_w_1_wr_en,
	output wire [128+64-1:0] trace_tx__tx_puzzle_fifo_w_1_wr_data,
	output wire [15:0] trace_tx__tx_puzzle_fifo_w_1_wr_data_count,
	output wire trace_tx__tx_puzzle_fifo_w_2_full,
	output wire trace_tx__tx_puzzle_fifo_w_2_wr_en,
	output wire [128+64-1:0] trace_tx__tx_puzzle_fifo_w_2_wr_data,
	output wire [15:0] trace_tx__tx_puzzle_fifo_w_2_wr_data_count,
	output wire trace_tx__tx_puzzle_fifo_w_3_full,
	output wire trace_tx__tx_puzzle_fifo_w_3_wr_en,
	output wire [128+64-1:0] trace_tx__tx_puzzle_fifo_w_3_wr_data,
	output wire [15:0] trace_tx__tx_puzzle_fifo_w_3_wr_data_count
`endif

`ifdef ENABLE_TRACE_TX__CSUM
	,output wire [1:0] trace_tx__csum_ip_state,
	output wire [2:0] trace_tx__csum_l4_state,
	output wire trace_tx__csum_p_valid,
	output wire trace_tx__csum_p_sof,
	output wire trace_tx__csum_p_eof,
	output wire trace_tx__csum_commit_checksum,
	output wire [1:0] trace_tx__csum_eth_type,
	output wire [21-1:0] trace_tx__csum_ip_sum,
	output wire [1:0] trace_tx__csum_ip_proto,
	output wire [27-1:0] trace_tx__csum_l4_sum
`endif

`ifdef ENABLE_TRACE_TX__ATF
	,output wire trace_tx__atf_stuffer_first,
	output wire trace_tx__atf_stuffer_i_valid,
	output wire trace_tx__atf_stuffer_i_sof,
	output wire trace_tx__atf_stuffer_i_eof,
	output wire [3:0] trace_tx__atf_stuffer_i_lsbyte,
	output wire [3:0] trace_tx__atf_stuffer_i_msbyte,
	output wire [127:0] trace_tx__atf_stuffer_i_data,
	output wire trace_tx__atf_stuffer_o_valid,
	output wire [127:0] trace_tx__atf_stuffer_o_data,

	output wire trace_tx__atf_axi_calc_i_valid,
	output wire [127:0] trace_tx__atf_axi_calc_i_address,
	output wire [15:0] trace_tx__atf_axi_calc_i_length,
	output wire trace_tx__atf_axi_calc_i_axhshake,
	output wire trace_tx__atf_axi_calc_o_valid,
	output wire [127:0] trace_tx__atf_axi_calc_o_axaddr,
	output wire [7:0] trace_tx__atf_axi_calc_o_axlen,

	output wire [15:0] trace_tx__atf_mem_r_len_plus_off,

	output wire [15:0] trace_tx__atf__total_beats_comb,
	output wire [15:0] trace_tx__atf_total_beats_comb,
	output wire [15:0] trace_tx__atf_total_beats,

	output wire [15:0] trace_tx__atf__total_bursts_comb,
	output wire [15:0] trace_tx__atf_total_bursts_comb,
	output wire [15:0] trace_tx__atf_total_bursts,

	output wire [7:0] trace_tx__atf_last_burst_beats,
	output wire [3:0] trace_tx__atf_last_beat_bytes
`endif

`ifdef ENABLE_TRACE_TX__ATF_BDS
	,output wire trace_tx__atf_bds_poisoned,
	output wire [127:0] trace_tx__atf_bds_stage0_data_shr_comb,
	output wire [15:0] trace_tx__atf_bds_stage0_bytemask_comb,

	output wire trace_tx__atf_bds_stage1_valid_ff,
	output wire [127:0] trace_tx__atf_bds_stage1_data_ff,
	output wire [3:0] trace_tx__atf_bds_stage1_size_ff,
	output wire [15:0] trace_tx__atf_bds_stage1_bytemask_ff,
	output wire trace_tx__atf_bds_stage1_sof_ff,
	output wire trace_tx__atf_bds_stage1_eof_ff,
	output wire [127:0] trace_tx__atf_bds_stage1_bitmask_comb,

	output wire trace_tx__atf_bds_stage2_valid_ff,
	output wire [127:0] trace_tx__atf_bds_stage2_data_ff,
	output wire [4:0] trace_tx__atf_bds_stage2_size_ff,
	output wire trace_tx__atf_bds_stage2_sof_ff,
	output wire trace_tx__atf_bds_stage2_eof_ff,
	output wire [128*2-8-1:0] trace_tx__atf_bds_stage2_data_shl_comb,

	output wire trace_tx__atf_bds_stage3_valid_ff,
	output wire trace_tx__atf_bds_stage3_sof_ff,
	output wire trace_tx__atf_bds_stage3_sof_comb,
	output wire trace_tx__atf_bds_stage3_eof_ff,
	output wire [128*2-8-1:0] trace_tx__atf_bds_stage3_data_ff,
	output wire [128*2-8-1:0] trace_tx__atf_bds_stage3_data_comb,
	output wire [4:0] trace_tx__atf_bds_stage3_size_ff,
	output wire [4:0] trace_tx__atf_bds_stage3_size_comb
`endif
);

/*
 * Do some sanity checks because configuration is mostly done in the
 * prism_sp_config package, but has to be compatible with AXI interface
 * widths that are necessarily defined by the top-level parameters.
 *
 * (Vivado IP integrator seems to be unable to use constants defined
 *  in a package for the top-level signals).
 */
if (C_M_AXI_DMA_DATA_WIDTH != RX_DATA_FIFO_WIDTH) begin
	$fatal("C_M_AXI_DMA_DATA_WIDTH (%d) and RX_DATA_FIFO_WIDTH (%d) differ.\n",
		C_M_AXI_DMA_DATA_WIDTH, RX_DATA_FIFO_WIDTH);
end

if (C_M_AXI_DMA_DATA_WIDTH != TX_DATA_FIFO_WIDTH) begin
	$fatal("C_M_AXI_DMA_DATA_WIDTH (%d) and TX_DATA_FIFO_WIDTH (%d) differ.\n",
		C_M_AXI_DMA_DATA_WIDTH, TX_DATA_FIFO_WIDTH);
end

localparam int NCORES = NRXCORES + NTXCORES;

localparam int IBRAM_WIDTH = 32;
localparam int DBRAM_WIDTH = 32;

axi_lite_write_address_channel #(.AXI_AWADDR_WIDTH(C_S_AXIL_ADDR_WIDTH)) s_axil_aw[NCORES]();
assign s_axil_aw[0].awvalid = s_axil_0_awvalid;
assign s_axil_0_awready = s_axil_aw[0].awready;
assign s_axil_aw[0].awaddr = s_axil_0_awaddr;
assign s_axil_aw[0].awprot = s_axil_0_awprot;

assign s_axil_aw[1].awvalid = s_axil_1_awvalid;
assign s_axil_1_awready = s_axil_aw[1].awready;
assign s_axil_aw[1].awaddr = s_axil_1_awaddr;
assign s_axil_aw[1].awprot = s_axil_1_awprot;

axi_lite_write_channel #(.AXI_WDATA_WIDTH(C_S_AXIL_DATA_WIDTH)) s_axil_w[NCORES]();
assign s_axil_w[0].wvalid = s_axil_0_wvalid;
assign s_axil_0_wready = s_axil_w[0].wready;
assign s_axil_w[0].wdata = s_axil_0_wdata;
assign s_axil_w[0].wstrb = s_axil_0_wstrb;

assign s_axil_w[1].wvalid = s_axil_1_wvalid;
assign s_axil_1_wready = s_axil_w[1].wready;
assign s_axil_w[1].wdata = s_axil_1_wdata;
assign s_axil_w[1].wstrb = s_axil_1_wstrb;

axi_lite_write_response_channel s_axil_b[NCORES]();
assign s_axil_0_bvalid = s_axil_b[0].bvalid;
assign s_axil_b[0].bready = s_axil_0_bready;
assign s_axil_0_bresp = s_axil_b[0].bresp;

assign s_axil_1_bvalid = s_axil_b[1].bvalid;
assign s_axil_b[1].bready = s_axil_1_bready;
assign s_axil_1_bresp = s_axil_b[1].bresp;

axi_lite_read_address_channel #(.AXI_ARADDR_WIDTH(C_S_AXIL_ADDR_WIDTH)) s_axil_ar[NCORES]();
assign s_axil_ar[0].arvalid = s_axil_0_arvalid;
assign s_axil_0_arready = s_axil_ar[0].arready;
assign s_axil_ar[0].araddr = s_axil_0_araddr;
assign s_axil_ar[0].arprot = s_axil_0_arprot;

assign s_axil_ar[1].arvalid = s_axil_1_arvalid;
assign s_axil_1_arready = s_axil_ar[1].arready;
assign s_axil_ar[1].araddr = s_axil_1_araddr;
assign s_axil_ar[1].arprot = s_axil_1_arprot;

axi_lite_read_channel #(.AXI_RDATA_WIDTH(C_S_AXIL_DATA_WIDTH)) s_axil_r[NCORES]();
assign s_axil_0_rvalid = s_axil_r[0].rvalid;
assign s_axil_r[0].rready = s_axil_0_rready;
assign s_axil_0_rdata = s_axil_r[0].rdata;
assign s_axil_0_rresp = s_axil_r[0].rresp;

assign s_axil_1_rvalid = s_axil_r[1].rvalid;
assign s_axil_r[1].rready = s_axil_1_rready;
assign s_axil_1_rdata = s_axil_r[1].rdata;
assign s_axil_1_rresp = s_axil_r[1].rresp;

/*
 * AXI HWIO
 */
axi_write_address_channel #(
	.AXI_AWID_WIDTH(C_M_AXI_MA_ID_WIDTH),
	.AXI_AWADDR_WIDTH(C_M_AXI_MA_ADDR_WIDTH)
) m_axi_ma_aw[NCORES]();
axi_write_channel #(
	.AXI_WDATA_WIDTH(C_M_AXI_MA_DATA_WIDTH)
) m_axi_ma_w[NCORES]();
axi_write_response_channel #(
	.AXI_BID_WIDTH(C_M_AXI_MA_ID_WIDTH)
) m_axi_ma_b[NCORES]();
axi_read_address_channel #(
	.AXI_ARID_WIDTH(C_M_AXI_MA_ID_WIDTH),
	.AXI_ARADDR_WIDTH(C_M_AXI_MA_ADDR_WIDTH)
) m_axi_ma_ar[NCORES]();
axi_read_channel #(
	.AXI_RID_WIDTH(C_M_AXI_MA_ID_WIDTH),
	.AXI_RDATA_WIDTH(C_M_AXI_MA_DATA_WIDTH)
) m_axi_ma_r[NCORES]();

// AW
assign m_axi_ma_0_awid =			m_axi_ma_aw[0].awid;
assign m_axi_ma_0_awaddr =			m_axi_ma_aw[0].awaddr;
assign m_axi_ma_0_awlen =			m_axi_ma_aw[0].awlen;
assign m_axi_ma_0_awsize =			m_axi_ma_aw[0].awsize;
assign m_axi_ma_0_awburst =		m_axi_ma_aw[0].awburst;
assign m_axi_ma_0_awlock =			m_axi_ma_aw[0].awlock;
assign m_axi_ma_0_awcache =		m_axi_ma_aw[0].awcache;
assign m_axi_ma_0_awprot =			m_axi_ma_aw[0].awprot;
assign m_axi_ma_0_awvalid =		m_axi_ma_aw[0].awvalid;
assign m_axi_ma_aw[0].awready =	m_axi_ma_0_awready;
// W
assign m_axi_ma_0_wdata =			m_axi_ma_w[0].wdata;
assign m_axi_ma_0_wstrb =			m_axi_ma_w[0].wstrb;
assign m_axi_ma_0_wlast =			m_axi_ma_w[0].wlast;
assign m_axi_ma_0_wvalid =			m_axi_ma_w[0].wvalid;
assign m_axi_ma_w[0].wready =		m_axi_ma_0_wready;
// B
assign m_axi_ma_b[0].bid =			m_axi_ma_0_bid;
assign m_axi_ma_b[0].bresp =		m_axi_ma_0_bresp;
assign m_axi_ma_b[0].bvalid =		m_axi_ma_0_bvalid;
assign m_axi_ma_0_bready =			m_axi_ma_b[0].bready;
// AR
assign m_axi_ma_0_arid =			m_axi_ma_ar[0].arid;
assign m_axi_ma_0_araddr =			m_axi_ma_ar[0].araddr;
assign m_axi_ma_0_arlen =			m_axi_ma_ar[0].arlen;
assign m_axi_ma_0_arsize =			m_axi_ma_ar[0].arsize;
assign m_axi_ma_0_arburst =		m_axi_ma_ar[0].arburst;
assign m_axi_ma_0_arlock =			m_axi_ma_ar[0].arlock;
assign m_axi_ma_0_arcache =		m_axi_ma_ar[0].arcache;
assign m_axi_ma_0_arprot =			m_axi_ma_ar[0].arprot;
assign m_axi_ma_0_arvalid =		m_axi_ma_ar[0].arvalid;
assign m_axi_ma_ar[0].arready =	m_axi_ma_0_arready;
// R
assign m_axi_ma_r[0].rid =			m_axi_ma_0_rid;
assign m_axi_ma_r[0].rdata =		m_axi_ma_0_rdata;
assign m_axi_ma_r[0].rresp =		m_axi_ma_0_rresp;
assign m_axi_ma_r[0].rlast =		m_axi_ma_0_rlast;
assign m_axi_ma_r[0].rvalid =		m_axi_ma_0_rvalid;
assign m_axi_ma_0_rready =			m_axi_ma_r[0].rready;

// AW
assign m_axi_ma_1_awid =			m_axi_ma_aw[1].awid;
assign m_axi_ma_1_awaddr =			m_axi_ma_aw[1].awaddr;
assign m_axi_ma_1_awlen =			m_axi_ma_aw[1].awlen;
assign m_axi_ma_1_awsize =			m_axi_ma_aw[1].awsize;
assign m_axi_ma_1_awburst =		m_axi_ma_aw[1].awburst;
assign m_axi_ma_1_awlock =			m_axi_ma_aw[1].awlock;
assign m_axi_ma_1_awcache =		m_axi_ma_aw[1].awcache;
assign m_axi_ma_1_awprot =			m_axi_ma_aw[1].awprot;
assign m_axi_ma_1_awvalid =		m_axi_ma_aw[1].awvalid;
assign m_axi_ma_aw[1].awready =	m_axi_ma_1_awready;
// W
assign m_axi_ma_1_wdata =			m_axi_ma_w[1].wdata;
assign m_axi_ma_1_wstrb =			m_axi_ma_w[1].wstrb;
assign m_axi_ma_1_wlast =			m_axi_ma_w[1].wlast;
assign m_axi_ma_1_wvalid =			m_axi_ma_w[1].wvalid;
assign m_axi_ma_w[1].wready =		m_axi_ma_1_wready;
// B
assign m_axi_ma_b[1].bid =			m_axi_ma_1_bid;
assign m_axi_ma_b[1].bresp =		m_axi_ma_1_bresp;
assign m_axi_ma_b[1].bvalid =		m_axi_ma_1_bvalid;
assign m_axi_ma_1_bready =			m_axi_ma_b[1].bready;
// AR
assign m_axi_ma_1_arid =			m_axi_ma_ar[1].arid;
assign m_axi_ma_1_araddr =			m_axi_ma_ar[1].araddr;
assign m_axi_ma_1_arlen =			m_axi_ma_ar[1].arlen;
assign m_axi_ma_1_arsize =			m_axi_ma_ar[1].arsize;
assign m_axi_ma_1_arburst =		m_axi_ma_ar[1].arburst;
assign m_axi_ma_1_arlock =			m_axi_ma_ar[1].arlock;
assign m_axi_ma_1_arcache =		m_axi_ma_ar[1].arcache;
assign m_axi_ma_1_arprot =			m_axi_ma_ar[1].arprot;
assign m_axi_ma_1_arvalid =		m_axi_ma_ar[1].arvalid;
assign m_axi_ma_ar[1].arready =	m_axi_ma_1_arready;
// R
assign m_axi_ma_r[1].rid =			m_axi_ma_1_rid;
assign m_axi_ma_r[1].rdata =		m_axi_ma_1_rdata;
assign m_axi_ma_r[1].rresp =		m_axi_ma_1_rresp;
assign m_axi_ma_r[1].rlast =		m_axi_ma_1_rlast;
assign m_axi_ma_r[1].rvalid =		m_axi_ma_1_rvalid;
assign m_axi_ma_1_rready =			m_axi_ma_r[1].rready;

/*
 * AXI HWIO
 */
axi_write_address_channel #(
	.AXI_AWID_WIDTH(C_M_AXI_MB_ID_WIDTH),
	.AXI_AWADDR_WIDTH(C_M_AXI_MB_ADDR_WIDTH)
) m_axi_mb_aw[NCORES]();
axi_write_channel #(
	.AXI_WDATA_WIDTH(C_M_AXI_MB_DATA_WIDTH)
) m_axi_mb_w[NCORES]();
axi_write_response_channel #(
	.AXI_BID_WIDTH(C_M_AXI_MB_ID_WIDTH)
) m_axi_mb_b[NCORES]();
axi_read_address_channel #(
	.AXI_ARID_WIDTH(C_M_AXI_MB_ID_WIDTH),
	.AXI_ARADDR_WIDTH(C_M_AXI_MB_ADDR_WIDTH)
) m_axi_mb_ar[NCORES]();
axi_read_channel #(
	.AXI_RID_WIDTH(C_M_AXI_MB_ID_WIDTH),
	.AXI_RDATA_WIDTH(C_M_AXI_MB_DATA_WIDTH)
) m_axi_mb_r[NCORES]();

// AW
assign m_axi_mb_0_awid =			m_axi_mb_aw[0].awid;
assign m_axi_mb_0_awaddr =			m_axi_mb_aw[0].awaddr;
assign m_axi_mb_0_awlen =			m_axi_mb_aw[0].awlen;
assign m_axi_mb_0_awsize =			m_axi_mb_aw[0].awsize;
assign m_axi_mb_0_awburst =		m_axi_mb_aw[0].awburst;
assign m_axi_mb_0_awlock =			m_axi_mb_aw[0].awlock;
assign m_axi_mb_0_awcache =		m_axi_mb_aw[0].awcache;
assign m_axi_mb_0_awprot =			m_axi_mb_aw[0].awprot;
assign m_axi_mb_0_awvalid =		m_axi_mb_aw[0].awvalid;
assign m_axi_mb_aw[0].awready =	m_axi_mb_0_awready;
// W
assign m_axi_mb_0_wdata =			m_axi_mb_w[0].wdata;
assign m_axi_mb_0_wstrb =			m_axi_mb_w[0].wstrb;
assign m_axi_mb_0_wlast =			m_axi_mb_w[0].wlast;
assign m_axi_mb_0_wvalid =			m_axi_mb_w[0].wvalid;
assign m_axi_mb_w[0].wready =		m_axi_mb_0_wready;
// B
assign m_axi_mb_b[0].bid =			m_axi_mb_0_bid;
assign m_axi_mb_b[0].bresp =		m_axi_mb_0_bresp;
assign m_axi_mb_b[0].bvalid =		m_axi_mb_0_bvalid;
assign m_axi_mb_0_bready =			m_axi_mb_b[0].bready;
// AR
assign m_axi_mb_0_arid =			m_axi_mb_ar[0].arid;
assign m_axi_mb_0_araddr =			m_axi_mb_ar[0].araddr;
assign m_axi_mb_0_arlen =			m_axi_mb_ar[0].arlen;
assign m_axi_mb_0_arsize =			m_axi_mb_ar[0].arsize;
assign m_axi_mb_0_arburst =		m_axi_mb_ar[0].arburst;
assign m_axi_mb_0_arlock =			m_axi_mb_ar[0].arlock;
assign m_axi_mb_0_arcache =		m_axi_mb_ar[0].arcache;
assign m_axi_mb_0_arprot =			m_axi_mb_ar[0].arprot;
assign m_axi_mb_0_arvalid =		m_axi_mb_ar[0].arvalid;
assign m_axi_mb_ar[0].arready =	m_axi_mb_0_arready;
// R
assign m_axi_mb_r[0].rid =			m_axi_mb_0_rid;
assign m_axi_mb_r[0].rdata =		m_axi_mb_0_rdata;
assign m_axi_mb_r[0].rresp =		m_axi_mb_0_rresp;
assign m_axi_mb_r[0].rlast =		m_axi_mb_0_rlast;
assign m_axi_mb_r[0].rvalid =		m_axi_mb_0_rvalid;
assign m_axi_mb_0_rready =			m_axi_mb_r[0].rready;

// AW
assign m_axi_mb_1_awid =			m_axi_mb_aw[1].awid;
assign m_axi_mb_1_awaddr =			m_axi_mb_aw[1].awaddr;
assign m_axi_mb_1_awlen =			m_axi_mb_aw[1].awlen;
assign m_axi_mb_1_awsize =			m_axi_mb_aw[1].awsize;
assign m_axi_mb_1_awburst =		m_axi_mb_aw[1].awburst;
assign m_axi_mb_1_awlock =			m_axi_mb_aw[1].awlock;
assign m_axi_mb_1_awcache =		m_axi_mb_aw[1].awcache;
assign m_axi_mb_1_awprot =			m_axi_mb_aw[1].awprot;
assign m_axi_mb_1_awvalid =		m_axi_mb_aw[1].awvalid;
assign m_axi_mb_aw[1].awready =	m_axi_mb_1_awready;
// W
assign m_axi_mb_1_wdata =			m_axi_mb_w[1].wdata;
assign m_axi_mb_1_wstrb =			m_axi_mb_w[1].wstrb;
assign m_axi_mb_1_wlast =			m_axi_mb_w[1].wlast;
assign m_axi_mb_1_wvalid =			m_axi_mb_w[1].wvalid;
assign m_axi_mb_w[1].wready =		m_axi_mb_1_wready;
// B
assign m_axi_mb_b[1].bid =			m_axi_mb_1_bid;
assign m_axi_mb_b[1].bresp =		m_axi_mb_1_bresp;
assign m_axi_mb_b[1].bvalid =		m_axi_mb_1_bvalid;
assign m_axi_mb_1_bready =			m_axi_mb_b[1].bready;
// AR
assign m_axi_mb_1_arid =			m_axi_mb_ar[1].arid;
assign m_axi_mb_1_araddr =			m_axi_mb_ar[1].araddr;
assign m_axi_mb_1_arlen =			m_axi_mb_ar[1].arlen;
assign m_axi_mb_1_arsize =			m_axi_mb_ar[1].arsize;
assign m_axi_mb_1_arburst =		m_axi_mb_ar[1].arburst;
assign m_axi_mb_1_arlock =			m_axi_mb_ar[1].arlock;
assign m_axi_mb_1_arcache =		m_axi_mb_ar[1].arcache;
assign m_axi_mb_1_arprot =			m_axi_mb_ar[1].arprot;
assign m_axi_mb_1_arvalid =		m_axi_mb_ar[1].arvalid;
assign m_axi_mb_ar[1].arready =	m_axi_mb_1_arready;
// R
assign m_axi_mb_r[1].rid =			m_axi_mb_1_rid;
assign m_axi_mb_r[1].rdata =		m_axi_mb_1_rdata;
assign m_axi_mb_r[1].rresp =		m_axi_mb_1_rresp;
assign m_axi_mb_r[1].rlast =		m_axi_mb_1_rlast;
assign m_axi_mb_r[1].rvalid =		m_axi_mb_1_rvalid;
assign m_axi_mb_1_rready =			m_axi_mb_r[1].rready;

/*
 * AXI IO
 */
axi_interface #(
	.C_M_AXI_ADDR_WIDTH(C_M_AXI_MX_ADDR_WIDTH),
	.C_M_AXI_DATA_WIDTH(C_M_AXI_MX_DATA_WIDTH)
) m_axi_mx[NCORES]();

// AW
assign m_axi_mx_0_awid =		m_axi_mx[0].awid;
assign m_axi_mx_0_awaddr =		m_axi_mx[0].awaddr;
assign m_axi_mx_0_awlen =		m_axi_mx[0].awlen;
assign m_axi_mx_0_awsize =		m_axi_mx[0].awsize;
assign m_axi_mx_0_awburst =	m_axi_mx[0].awburst;
assign m_axi_mx_0_awlock =		m_axi_mx[0].awlock;
assign m_axi_mx_0_awcache =	m_axi_mx[0].awcache;
assign m_axi_mx_0_awprot =		m_axi_mx[0].awprot;
assign m_axi_mx_0_awvalid =	m_axi_mx[0].awvalid;
assign m_axi_mx[0].awready =	m_axi_mx_0_awready;
// W
assign m_axi_mx_0_wdata =		m_axi_mx[0].wdata;
assign m_axi_mx_0_wstrb =		m_axi_mx[0].wstrb;
assign m_axi_mx_0_wlast =		m_axi_mx[0].wlast;
assign m_axi_mx_0_wvalid =		m_axi_mx[0].wvalid;
assign m_axi_mx[0].wready =	m_axi_mx_0_wready;
// B
assign m_axi_mx[0].bid =		m_axi_mx_0_bid;
assign m_axi_mx[0].bresp =		m_axi_mx_0_bresp;
assign m_axi_mx[0].bvalid =	m_axi_mx_0_bvalid;
assign m_axi_mx_0_bready =		m_axi_mx[0].bready;
// AR
assign m_axi_mx_0_arid =		m_axi_mx[0].arid;
assign m_axi_mx_0_araddr =		m_axi_mx[0].araddr;
assign m_axi_mx_0_arlen =		m_axi_mx[0].arlen;
assign m_axi_mx_0_arsize =		m_axi_mx[0].arsize;
assign m_axi_mx_0_arburst =	m_axi_mx[0].arburst;
assign m_axi_mx_0_arlock =		m_axi_mx[0].arlock;
assign m_axi_mx_0_arcache =	m_axi_mx[0].arcache;
assign m_axi_mx_0_arprot =		m_axi_mx[0].arprot;
assign m_axi_mx_0_arvalid =	m_axi_mx[0].arvalid;
assign m_axi_mx[0].arready =	m_axi_mx_0_arready;
// R
assign m_axi_mx[0].rid =		m_axi_mx_0_rid;
assign m_axi_mx[0].rdata =		m_axi_mx_0_rdata;
assign m_axi_mx[0].rresp =		m_axi_mx_0_rresp;
assign m_axi_mx[0].rlast =		m_axi_mx_0_rlast;
assign m_axi_mx[0].rvalid =	m_axi_mx_0_rvalid;
assign m_axi_mx_0_rready =		m_axi_mx[0].rready;

// AW
assign m_axi_mx_1_awid =		m_axi_mx[1].awid;
assign m_axi_mx_1_awaddr =		m_axi_mx[1].awaddr;
assign m_axi_mx_1_awlen =		m_axi_mx[1].awlen;
assign m_axi_mx_1_awsize =		m_axi_mx[1].awsize;
assign m_axi_mx_1_awburst =	m_axi_mx[1].awburst;
assign m_axi_mx_1_awlock =		m_axi_mx[1].awlock;
assign m_axi_mx_1_awcache =	m_axi_mx[1].awcache;
assign m_axi_mx_1_awprot =		m_axi_mx[1].awprot;
assign m_axi_mx_1_awvalid =	m_axi_mx[1].awvalid;
assign m_axi_mx[1].awready =	m_axi_mx_1_awready;
// W
assign m_axi_mx_1_wdata =		m_axi_mx[1].wdata;
assign m_axi_mx_1_wstrb =		m_axi_mx[1].wstrb;
assign m_axi_mx_1_wlast =		m_axi_mx[1].wlast;
assign m_axi_mx_1_wvalid =		m_axi_mx[1].wvalid;
assign m_axi_mx[1].wready =	m_axi_mx_1_wready;
// B
assign m_axi_mx[1].bid =		m_axi_mx_1_bid;
assign m_axi_mx[1].bresp =		m_axi_mx_1_bresp;
assign m_axi_mx[1].bvalid =	m_axi_mx_1_bvalid;
assign m_axi_mx_1_bready =		m_axi_mx[1].bready;
// AR
assign m_axi_mx_1_arid =		m_axi_mx[1].arid;
assign m_axi_mx_1_araddr =		m_axi_mx[1].araddr;
assign m_axi_mx_1_arlen =		m_axi_mx[1].arlen;
assign m_axi_mx_1_arsize =		m_axi_mx[1].arsize;
assign m_axi_mx_1_arburst =	m_axi_mx[1].arburst;
assign m_axi_mx_1_arlock =		m_axi_mx[1].arlock;
assign m_axi_mx_1_arcache =	m_axi_mx[1].arcache;
assign m_axi_mx_1_arprot =		m_axi_mx[1].arprot;
assign m_axi_mx_1_arvalid =	m_axi_mx[1].arvalid;
assign m_axi_mx[1].arready =	m_axi_mx_1_arready;
// R
assign m_axi_mx[1].rid =		m_axi_mx_1_rid;
assign m_axi_mx[1].rdata =		m_axi_mx_1_rdata;
assign m_axi_mx[1].rresp =		m_axi_mx_1_rresp;
assign m_axi_mx[1].rlast =		m_axi_mx_1_rlast;
assign m_axi_mx[1].rvalid =	m_axi_mx_1_rvalid;
assign m_axi_mx_1_rready =		m_axi_mx[1].rready;

/*
 * AXI IQ (Input Queue) #0
 */
axi_write_address_channel #(
	.AXI_AWID_WIDTH(C_S_AXI_SA_ID_WIDTH),
	.AXI_AWADDR_WIDTH(C_S_AXI_SA_ADDR_WIDTH)
) s_axi_sa_aw[NCORES]();
axi_write_channel #(
	.AXI_WDATA_WIDTH(C_S_AXI_SA_DATA_WIDTH)
) s_axi_sa_w[NCORES]();
axi_write_response_channel #(
	.AXI_BID_WIDTH(C_S_AXI_SA_ID_WIDTH)
) s_axi_sa_b[NCORES]();
axi_read_address_channel #(
	.AXI_ARID_WIDTH(C_S_AXI_SA_ID_WIDTH),
	.AXI_ARADDR_WIDTH(C_S_AXI_SA_ADDR_WIDTH)
) s_axi_sa_ar[NCORES]();
axi_read_channel #(
	.AXI_RID_WIDTH(C_S_AXI_SA_ID_WIDTH),
	.AXI_RDATA_WIDTH(C_S_AXI_SA_DATA_WIDTH)
) s_axi_sa_r[NCORES]();

// AW
assign s_axi_sa_aw[0].awid =		s_axi_sa_0_awid;
assign s_axi_sa_aw[0].awaddr =		s_axi_sa_0_awaddr;
assign s_axi_sa_aw[0].awlen =		s_axi_sa_0_awlen;
assign s_axi_sa_aw[0].awsize =		s_axi_sa_0_awsize;
assign s_axi_sa_aw[0].awburst =		s_axi_sa_0_awburst;
assign s_axi_sa_aw[0].awlock =		s_axi_sa_0_awlock;
assign s_axi_sa_aw[0].awcache =		s_axi_sa_0_awcache;
assign s_axi_sa_aw[0].awprot =		s_axi_sa_0_awprot;
assign s_axi_sa_aw[0].awvalid =		s_axi_sa_0_awvalid;
assign s_axi_sa_0_awready =			s_axi_sa_aw[0].awready;
// W
assign s_axi_sa_w[0].wdata =		s_axi_sa_0_wdata;
assign s_axi_sa_w[0].wstrb =		s_axi_sa_0_wstrb;
assign s_axi_sa_w[0].wlast =		s_axi_sa_0_wlast;
assign s_axi_sa_w[0].wvalid =		s_axi_sa_0_wvalid;
assign s_axi_sa_0_wready =			s_axi_sa_w[0].wready;
// B
assign s_axi_sa_0_bid =				s_axi_sa_b[0].bid;
assign s_axi_sa_0_bresp =			s_axi_sa_b[0].bresp;
assign s_axi_sa_0_bvalid =			s_axi_sa_b[0].bvalid;
assign s_axi_sa_b[0].bready =		s_axi_sa_0_bready;
// AR
assign s_axi_sa_ar[0].arid =		s_axi_sa_0_arid;
assign s_axi_sa_ar[0].araddr =		s_axi_sa_0_araddr;
assign s_axi_sa_ar[0].arlen =		s_axi_sa_0_arlen;
assign s_axi_sa_ar[0].arsize =		s_axi_sa_0_arsize;
assign s_axi_sa_ar[0].arburst =		s_axi_sa_0_arburst;
assign s_axi_sa_ar[0].arlock =		s_axi_sa_0_arlock;
assign s_axi_sa_ar[0].arcache =		s_axi_sa_0_arcache;
assign s_axi_sa_ar[0].arprot =		s_axi_sa_0_arprot;
assign s_axi_sa_ar[0].arvalid =		s_axi_sa_0_arvalid;
assign s_axi_sa_0_arready =			s_axi_sa_ar[0].arready;
// R
assign s_axi_sa_0_rid =				s_axi_sa_r[0].rid;
assign s_axi_sa_0_rdata =			s_axi_sa_r[0].rdata;
assign s_axi_sa_0_rresp =			s_axi_sa_r[0].rresp;
assign s_axi_sa_0_rlast =			s_axi_sa_r[0].rlast;
assign s_axi_sa_0_rvalid =			s_axi_sa_r[0].rvalid;
assign s_axi_sa_r[0].rready =		s_axi_sa_0_rready;

// AW
assign s_axi_sa_aw[1].awid =		s_axi_sa_1_awid;
assign s_axi_sa_aw[1].awaddr =		s_axi_sa_1_awaddr;
assign s_axi_sa_aw[1].awlen =		s_axi_sa_1_awlen;
assign s_axi_sa_aw[1].awsize =		s_axi_sa_1_awsize;
assign s_axi_sa_aw[1].awburst =		s_axi_sa_1_awburst;
assign s_axi_sa_aw[1].awlock =		s_axi_sa_1_awlock;
assign s_axi_sa_aw[1].awcache =		s_axi_sa_1_awcache;
assign s_axi_sa_aw[1].awprot =		s_axi_sa_1_awprot;
assign s_axi_sa_aw[1].awvalid =		s_axi_sa_1_awvalid;
assign s_axi_sa_1_awready =			s_axi_sa_aw[1].awready;
// W
assign s_axi_sa_w[1].wdata =		s_axi_sa_1_wdata;
assign s_axi_sa_w[1].wstrb =		s_axi_sa_1_wstrb;
assign s_axi_sa_w[1].wlast =		s_axi_sa_1_wlast;
assign s_axi_sa_w[1].wvalid =		s_axi_sa_1_wvalid;
assign s_axi_sa_1_wready =			s_axi_sa_w[1].wready;
// B
assign s_axi_sa_1_bid =				s_axi_sa_b[1].bid;
assign s_axi_sa_1_bresp =			s_axi_sa_b[1].bresp;
assign s_axi_sa_1_bvalid =			s_axi_sa_b[1].bvalid;
assign s_axi_sa_b[1].bready =		s_axi_sa_1_bready;
// AR
assign s_axi_sa_ar[1].arid =		s_axi_sa_1_arid;
assign s_axi_sa_ar[1].araddr =		s_axi_sa_1_araddr;
assign s_axi_sa_ar[1].arlen =		s_axi_sa_1_arlen;
assign s_axi_sa_ar[1].arsize =		s_axi_sa_1_arsize;
assign s_axi_sa_ar[1].arburst =		s_axi_sa_1_arburst;
assign s_axi_sa_ar[1].arlock =		s_axi_sa_1_arlock;
assign s_axi_sa_ar[1].arcache =		s_axi_sa_1_arcache;
assign s_axi_sa_ar[1].arprot =		s_axi_sa_1_arprot;
assign s_axi_sa_ar[1].arvalid =		s_axi_sa_1_arvalid;
assign s_axi_sa_1_arready =			s_axi_sa_ar[1].arready;
// R
assign s_axi_sa_1_rid =				s_axi_sa_r[1].rid;
assign s_axi_sa_1_rdata =			s_axi_sa_r[1].rdata;
assign s_axi_sa_1_rresp =			s_axi_sa_r[1].rresp;
assign s_axi_sa_1_rlast =			s_axi_sa_r[1].rlast;
assign s_axi_sa_1_rvalid =			s_axi_sa_r[1].rvalid;
assign s_axi_sa_r[1].rready =		s_axi_sa_1_rready;

/*
 * AXI OQ (Output Queue) #0
 */
axi_write_address_channel #(
	.AXI_AWADDR_WIDTH(C_S_AXI_SB_ADDR_WIDTH),
	.AXI_AWID_WIDTH(C_S_AXI_SB_ID_WIDTH)
) s_axi_sb_aw[NCORES]();
axi_write_channel #(
	.AXI_WDATA_WIDTH(C_S_AXI_SB_DATA_WIDTH)
) s_axi_sb_w[NCORES]();
axi_write_response_channel #(
	.AXI_BID_WIDTH(C_S_AXI_SB_ID_WIDTH)
) s_axi_sb_b[NCORES]();
axi_read_address_channel #(
	.AXI_ARID_WIDTH(C_S_AXI_SB_ID_WIDTH),
	.AXI_ARADDR_WIDTH(C_S_AXI_SB_ADDR_WIDTH)
) s_axi_sb_ar[NCORES]();
axi_read_channel #(
	.AXI_RID_WIDTH(C_S_AXI_SB_ID_WIDTH),
	.AXI_RDATA_WIDTH(C_S_AXI_SB_DATA_WIDTH)
) s_axi_sb_r[NCORES]();

// AW
assign s_axi_sb_aw[0].awid =		s_axi_sb_0_awid;
assign s_axi_sb_aw[0].awaddr =		s_axi_sb_0_awaddr;
assign s_axi_sb_aw[0].awlen =		s_axi_sb_0_awlen;
assign s_axi_sb_aw[0].awsize =		s_axi_sb_0_awsize;
assign s_axi_sb_aw[0].awburst =		s_axi_sb_0_awburst;
assign s_axi_sb_aw[0].awlock =		s_axi_sb_0_awlock;
assign s_axi_sb_aw[0].awcache =		s_axi_sb_0_awcache;
assign s_axi_sb_aw[0].awprot =		s_axi_sb_0_awprot;
assign s_axi_sb_aw[0].awvalid =		s_axi_sb_0_awvalid;
assign s_axi_sb_0_awready =			s_axi_sb_aw[0].awready;
// W
assign s_axi_sb_w[0].wdata =		s_axi_sb_0_wdata;
assign s_axi_sb_w[0].wstrb =		s_axi_sb_0_wstrb;
assign s_axi_sb_w[0].wlast =		s_axi_sb_0_wlast;
assign s_axi_sb_w[0].wvalid =		s_axi_sb_0_wvalid;
assign s_axi_sb_0_wready =			s_axi_sb_w[0].wready;
// B
assign s_axi_sb_0_bid =				s_axi_sb_b[0].bid;
assign s_axi_sb_0_bresp =			s_axi_sb_b[0].bresp;
assign s_axi_sb_0_bvalid =			s_axi_sb_b[0].bvalid;
assign s_axi_sb_b[0].bready =		s_axi_sb_0_bready;
// AR
assign s_axi_sb_ar[0].arid =		s_axi_sb_0_arid;
assign s_axi_sb_ar[0].araddr =		s_axi_sb_0_araddr;
assign s_axi_sb_ar[0].arlen =		s_axi_sb_0_arlen;
assign s_axi_sb_ar[0].arsize =		s_axi_sb_0_arsize;
assign s_axi_sb_ar[0].arburst =		s_axi_sb_0_arburst;
assign s_axi_sb_ar[0].arlock =		s_axi_sb_0_arlock;
assign s_axi_sb_ar[0].arcache =		s_axi_sb_0_arcache;
assign s_axi_sb_ar[0].arprot =		s_axi_sb_0_arprot;
assign s_axi_sb_ar[0].arvalid =		s_axi_sb_0_arvalid;
assign s_axi_sb_0_arready =			s_axi_sb_ar[0].arready;
// R
assign s_axi_sb_0_rid =				s_axi_sb_r[0].rid;
assign s_axi_sb_0_rdata =			s_axi_sb_r[0].rdata;
assign s_axi_sb_0_rresp =			s_axi_sb_r[0].rresp;
assign s_axi_sb_0_rlast =			s_axi_sb_r[0].rlast;
assign s_axi_sb_0_rvalid =			s_axi_sb_r[0].rvalid;
assign s_axi_sb_r[0].rready =		s_axi_sb_0_rready;

// AW
assign s_axi_sb_aw[1].awid =		s_axi_sb_1_awid;
assign s_axi_sb_aw[1].awaddr =		s_axi_sb_1_awaddr;
assign s_axi_sb_aw[1].awlen =		s_axi_sb_1_awlen;
assign s_axi_sb_aw[1].awsize =		s_axi_sb_1_awsize;
assign s_axi_sb_aw[1].awburst =		s_axi_sb_1_awburst;
assign s_axi_sb_aw[1].awlock =		s_axi_sb_1_awlock;
assign s_axi_sb_aw[1].awcache =		s_axi_sb_1_awcache;
assign s_axi_sb_aw[1].awprot =		s_axi_sb_1_awprot;
assign s_axi_sb_aw[1].awvalid =		s_axi_sb_1_awvalid;
assign s_axi_sb_1_awready =			s_axi_sb_aw[1].awready;
// W
assign s_axi_sb_w[1].wdata =		s_axi_sb_1_wdata;
assign s_axi_sb_w[1].wstrb =		s_axi_sb_1_wstrb;
assign s_axi_sb_w[1].wlast =		s_axi_sb_1_wlast;
assign s_axi_sb_w[1].wvalid =		s_axi_sb_1_wvalid;
assign s_axi_sb_1_wready =			s_axi_sb_w[1].wready;
// B
assign s_axi_sb_1_bid =				s_axi_sb_b[1].bid;
assign s_axi_sb_1_bresp =			s_axi_sb_b[1].bresp;
assign s_axi_sb_1_bvalid =			s_axi_sb_b[1].bvalid;
assign s_axi_sb_b[1].bready =		s_axi_sb_1_bready;
// AR
assign s_axi_sb_ar[1].arid =		s_axi_sb_1_arid;
assign s_axi_sb_ar[1].araddr =		s_axi_sb_1_araddr;
assign s_axi_sb_ar[1].arlen =		s_axi_sb_1_arlen;
assign s_axi_sb_ar[1].arsize =		s_axi_sb_1_arsize;
assign s_axi_sb_ar[1].arburst =		s_axi_sb_1_arburst;
assign s_axi_sb_ar[1].arlock =		s_axi_sb_1_arlock;
assign s_axi_sb_ar[1].arcache =		s_axi_sb_1_arcache;
assign s_axi_sb_ar[1].arprot =		s_axi_sb_1_arprot;
assign s_axi_sb_ar[1].arvalid =		s_axi_sb_1_arvalid;
assign s_axi_sb_1_arready =			s_axi_sb_ar[1].arready;
// R
assign s_axi_sb_1_rid =				s_axi_sb_r[1].rid;
assign s_axi_sb_1_rdata =			s_axi_sb_r[1].rdata;
assign s_axi_sb_1_rresp =			s_axi_sb_r[1].rresp;
assign s_axi_sb_1_rlast =			s_axi_sb_r[1].rlast;
assign s_axi_sb_1_rvalid =			s_axi_sb_r[1].rvalid;
assign s_axi_sb_r[1].rready =		s_axi_sb_1_rready;

/*
 * AXI ACP #0
 */
axi_write_address_channel #(
	.AXI_AWADDR_WIDTH(C_M_AXI_ACP_ADDR_WIDTH)
) m_axi_acp_aw[NCORES]();
axi_write_channel #(
	.AXI_WDATA_WIDTH(C_M_AXI_ACP_DATA_WIDTH)
) m_axi_acp_w[NCORES]();
axi_write_response_channel m_axi_acp_b[NCORES]();
axi_read_address_channel #(
	.AXI_ARADDR_WIDTH(C_M_AXI_ACP_ADDR_WIDTH)
) m_axi_acp_ar[NCORES]();
axi_read_channel #(
	.AXI_RDATA_WIDTH(C_M_AXI_ACP_DATA_WIDTH)
) m_axi_acp_r[NCORES]();

// AW
assign m_axi_acp_0_awid =		m_axi_acp_aw[0].awid;
assign m_axi_acp_0_awaddr =		m_axi_acp_aw[0].awaddr;
assign m_axi_acp_0_awlen =		m_axi_acp_aw[0].awlen;
assign m_axi_acp_0_awsize =		m_axi_acp_aw[0].awsize;
assign m_axi_acp_0_awburst =	m_axi_acp_aw[0].awburst;
assign m_axi_acp_0_awlock =		m_axi_acp_aw[0].awlock;
assign m_axi_acp_0_awcache =	m_axi_acp_aw[0].awcache;
assign m_axi_acp_0_awprot =		m_axi_acp_aw[0].awprot;
assign m_axi_acp_0_awuser =		m_axi_acp_aw[0].awuser;
assign m_axi_acp_0_awvalid =	m_axi_acp_aw[0].awvalid;
assign m_axi_acp_aw[0].awready =	m_axi_acp_0_awready;
// W
assign m_axi_acp_0_wdata =		m_axi_acp_w[0].wdata;
assign m_axi_acp_0_wstrb =		m_axi_acp_w[0].wstrb;
assign m_axi_acp_0_wlast =		m_axi_acp_w[0].wlast;
assign m_axi_acp_0_wvalid =		m_axi_acp_w[0].wvalid;
assign m_axi_acp_w[0].wready =	m_axi_acp_0_wready;
// B
assign m_axi_acp_b[0].bid =		m_axi_acp_0_bid;
assign m_axi_acp_b[0].bresp =	m_axi_acp_0_bresp;
assign m_axi_acp_b[0].bvalid =	m_axi_acp_0_bvalid;
assign m_axi_acp_0_bready =		m_axi_acp_b[0].bready;
// AR
assign m_axi_acp_0_arid =		m_axi_acp_ar[0].arid;
assign m_axi_acp_0_araddr =		m_axi_acp_ar[0].araddr;
assign m_axi_acp_0_arlen =		m_axi_acp_ar[0].arlen;
assign m_axi_acp_0_arsize =		m_axi_acp_ar[0].arsize;
assign m_axi_acp_0_arburst =	m_axi_acp_ar[0].arburst;
assign m_axi_acp_0_arlock =		m_axi_acp_ar[0].arlock;
assign m_axi_acp_0_arcache =	m_axi_acp_ar[0].arcache;
assign m_axi_acp_0_arprot =		m_axi_acp_ar[0].arprot;
assign m_axi_acp_0_aruser =		m_axi_acp_ar[0].aruser;
assign m_axi_acp_0_arvalid =	m_axi_acp_ar[0].arvalid;
assign m_axi_acp_ar[0].arready = m_axi_acp_0_arready;
// R
assign m_axi_acp_r[0].rid =		m_axi_acp_0_rid;
assign m_axi_acp_r[0].rdata =	m_axi_acp_0_rdata;
assign m_axi_acp_r[0].rresp =	m_axi_acp_0_rresp;
assign m_axi_acp_r[0].rlast =	m_axi_acp_0_rlast;
assign m_axi_acp_r[0].rvalid =	m_axi_acp_0_rvalid;
assign m_axi_acp_0_rready =		m_axi_acp_r[0].rready;

// AW
assign m_axi_acp_1_awid =		m_axi_acp_aw[1].awid;
assign m_axi_acp_1_awaddr =		m_axi_acp_aw[1].awaddr;
assign m_axi_acp_1_awlen =		m_axi_acp_aw[1].awlen;
assign m_axi_acp_1_awsize =		m_axi_acp_aw[1].awsize;
assign m_axi_acp_1_awburst =	m_axi_acp_aw[1].awburst;
assign m_axi_acp_1_awlock =		m_axi_acp_aw[1].awlock;
assign m_axi_acp_1_awcache =	m_axi_acp_aw[1].awcache;
assign m_axi_acp_1_awprot =		m_axi_acp_aw[1].awprot;
assign m_axi_acp_1_awuser =		m_axi_acp_aw[1].awuser;
assign m_axi_acp_1_awvalid =	m_axi_acp_aw[1].awvalid;
assign m_axi_acp_aw[1].awready =	m_axi_acp_1_awready;
// W
assign m_axi_acp_1_wdata =		m_axi_acp_w[1].wdata;
assign m_axi_acp_1_wstrb =		m_axi_acp_w[1].wstrb;
assign m_axi_acp_1_wlast =		m_axi_acp_w[1].wlast;
assign m_axi_acp_1_wvalid =		m_axi_acp_w[1].wvalid;
assign m_axi_acp_w[1].wready =	m_axi_acp_1_wready;
// B
assign m_axi_acp_b[1].bid =		m_axi_acp_1_bid;
assign m_axi_acp_b[1].bvalid =	m_axi_acp_1_bvalid;
assign m_axi_acp_b[1].bresp =	m_axi_acp_1_bresp;
assign m_axi_acp_1_bready =		m_axi_acp_b[1].bready;
// AR
assign m_axi_acp_1_arid =		m_axi_acp_ar[1].arid;
assign m_axi_acp_1_araddr =		m_axi_acp_ar[1].araddr;
assign m_axi_acp_1_arlen =		m_axi_acp_ar[1].arlen;
assign m_axi_acp_1_arsize =		m_axi_acp_ar[1].arsize;
assign m_axi_acp_1_arburst =	m_axi_acp_ar[1].arburst;
assign m_axi_acp_1_arlock =		m_axi_acp_ar[1].arlock;
assign m_axi_acp_1_arcache =	m_axi_acp_ar[1].arcache;
assign m_axi_acp_1_arprot =		m_axi_acp_ar[1].arprot;
assign m_axi_acp_1_aruser =		m_axi_acp_ar[1].aruser;
assign m_axi_acp_1_arvalid =	m_axi_acp_ar[1].arvalid;
assign m_axi_acp_ar[1].arready =	m_axi_acp_1_arready;
// R
assign m_axi_acp_r[1].rid =		m_axi_acp_1_rid;
assign m_axi_acp_r[1].rdata =	m_axi_acp_1_rdata;
assign m_axi_acp_r[1].rresp =	m_axi_acp_1_rresp;
assign m_axi_acp_r[1].rlast =	m_axi_acp_1_rlast;
assign m_axi_acp_r[1].rvalid =	m_axi_acp_1_rvalid;
assign m_axi_acp_1_rready =		m_axi_acp_r[1].rready;

/*
 * AXI DMA
 */
axi_write_address_channel #(
	.AXI_AWID_WIDTH(C_M_AXI_DMA_ID_WIDTH),
	.AXI_AWADDR_WIDTH(C_M_AXI_DMA_ADDR_WIDTH)
) m_axi_dma_aw[NRXCORES]();
axi_write_channel #(
	.AXI_WDATA_WIDTH(C_M_AXI_DMA_DATA_WIDTH)
) m_axi_dma_w[NRXCORES]();
axi_write_response_channel #(
	.AXI_BID_WIDTH(C_M_AXI_DMA_ID_WIDTH)
) m_axi_dma_b[NRXCORES]();

axi_read_address_channel #(
	.AXI_ARID_WIDTH(C_M_AXI_DMA_ID_WIDTH),
	.AXI_ARADDR_WIDTH(C_M_AXI_DMA_ADDR_WIDTH)
) m_axi_dma_ar[NTXCORES]();
axi_read_channel #(
	.AXI_RID_WIDTH(C_M_AXI_DMA_ID_WIDTH),
	.AXI_RDATA_WIDTH(C_M_AXI_DMA_DATA_WIDTH)
) m_axi_dma_r[NTXCORES]();

// AW
assign m_axi_dma_0_awid =		m_axi_dma_aw[0].awid;
assign m_axi_dma_0_awaddr =		m_axi_dma_aw[0].awaddr;
assign m_axi_dma_0_awlen =		m_axi_dma_aw[0].awlen;
assign m_axi_dma_0_awsize =		m_axi_dma_aw[0].awsize;
assign m_axi_dma_0_awburst =	m_axi_dma_aw[0].awburst;
assign m_axi_dma_0_awlock =		m_axi_dma_aw[0].awlock;
assign m_axi_dma_0_awcache =	m_axi_dma_aw[0].awcache;
assign m_axi_dma_0_awprot =		m_axi_dma_aw[0].awprot;
assign m_axi_dma_0_awvalid =	m_axi_dma_aw[0].awvalid;
assign m_axi_dma_aw[0].awready = m_axi_dma_0_awready;
// W
assign m_axi_dma_0_wdata =		m_axi_dma_w[0].wdata;
assign m_axi_dma_0_wstrb =		m_axi_dma_w[0].wstrb;
assign m_axi_dma_0_wlast =		m_axi_dma_w[0].wlast;
assign m_axi_dma_0_wvalid =		m_axi_dma_w[0].wvalid;
assign m_axi_dma_w[0].wready =	m_axi_dma_0_wready;
// B
assign m_axi_dma_b[0].bid =		m_axi_dma_0_bid;
assign m_axi_dma_b[0].bresp =	m_axi_dma_0_bresp;
assign m_axi_dma_b[0].bvalid =	m_axi_dma_0_bvalid;
assign m_axi_dma_0_bready =		m_axi_dma_b[0].bready;
// AR
assign m_axi_dma_0_arid =		m_axi_dma_ar[0].arid;
assign m_axi_dma_0_araddr =		m_axi_dma_ar[0].araddr;
assign m_axi_dma_0_arlen =		m_axi_dma_ar[0].arlen;
assign m_axi_dma_0_arsize =		m_axi_dma_ar[0].arsize;
assign m_axi_dma_0_arburst =	m_axi_dma_ar[0].arburst;
assign m_axi_dma_0_arlock =		m_axi_dma_ar[0].arlock;
assign m_axi_dma_0_arcache =	m_axi_dma_ar[0].arcache;
assign m_axi_dma_0_arprot =		m_axi_dma_ar[0].arprot;
assign m_axi_dma_0_arvalid =	m_axi_dma_ar[0].arvalid;
assign m_axi_dma_ar[0].arready = m_axi_dma_0_arready;
// R
assign m_axi_dma_r[0].rid =		m_axi_dma_0_rid;
assign m_axi_dma_r[0].rdata =	m_axi_dma_0_rdata;
assign m_axi_dma_r[0].rresp =	m_axi_dma_0_rresp;
assign m_axi_dma_r[0].rlast =	m_axi_dma_0_rlast;
assign m_axi_dma_r[0].rvalid =	m_axi_dma_0_rvalid;
assign m_axi_dma_0_rready =		m_axi_dma_r[0].rready;

/*
 * GEM
 */
gem_tx_interface gem_tx();
assign gem_tx.tx_clock = gem_tx_clock;
assign gem_tx.tx_resetn = gem_tx_resetn;
assign gem_tx_r_data_rdy = gem_tx.tx_r_data_rdy;
assign gem_tx.tx_r_rd = gem_tx_r_rd;
assign gem_tx_r_valid = gem_tx.tx_r_valid;
assign gem_tx_r_data = gem_tx.tx_r_data;
assign gem_tx_r_sop = gem_tx.tx_r_sop;
assign gem_tx_r_eop = gem_tx.tx_r_eop;
assign gem_tx_r_err = gem_tx.tx_r_err;
assign gem_tx_r_underflow = gem_tx.tx_r_underflow;
assign gem_tx_r_flushed = gem_tx.tx_r_flushed;
assign gem_tx_r_control = gem_tx.tx_r_control;
assign gem_tx.tx_r_status = gem_tx_r_status;
assign gem_tx.tx_r_fixed_lat = gem_tx_r_fixed_lat;
assign gem_tx.dma_tx_end_tog = gem_dma_tx_end_tog;
assign gem_dma_tx_status_tog = gem_tx.dma_tx_status_tog;

gem_rx_interface gem_rx();
assign gem_rx.rx_clock = gem_rx_clock;
assign gem_rx.rx_resetn = gem_rx_resetn;
assign gem_rx.rx_w_wr = gem_rx_w_wr;
assign gem_rx.rx_w_data = gem_rx_w_data;
assign gem_rx.rx_w_sop = gem_rx_w_sop;
assign gem_rx.rx_w_eop = gem_rx_w_eop;
assign gem_rx.rx_w_status = gem_rx_w_status;
assign gem_rx.rx_w_err = gem_rx_w_err;
assign gem_rx_w_overflow = gem_rx.rx_w_overflow;
assign gem_rx.rx_w_flush = gem_rx_w_flush;

wire logic rx_control_irq;
wire logic tx_control_irq;
assign control_irq = rx_control_irq | tx_control_irq;

wire logic [NRXCORES-1:0] rx_channel_irqs;
assign rx_channel_irq_0 = rx_channel_irqs[0];
assign rx_channel_irq_1 = rx_channel_irqs[1];
assign rx_channel_irq_2 = rx_channel_irqs[2];
assign rx_channel_irq_3 = rx_channel_irqs[3];
wire logic [NTXCORES-1:0] tx_channel_irqs;
assign tx_channel_irq_0 = tx_channel_irqs[0];
assign tx_channel_irq_1 = tx_channel_irqs[1];
assign tx_channel_irq_2 = tx_channel_irqs[2];
assign tx_channel_irq_3 = tx_channel_irqs[3];

localparam int RXLOWIDX = 0;
localparam int RXHIGHIDX = NRXCORES-1;
localparam int TXLOWIDX = RXHIGHIDX+1;
localparam int TXHIGHIDX = TXLOWIDX+NTXCORES-1;

// Naming is trace_[PREFIX_]TYPE
// RX tracing
trace_outputs_t					trace_rx__proc [NRXCORES];
trace_sp_unit_t					trace_rx__sp_unit [NRXCORES];
trace_sp_unit_rx_t				trace_rx__sp_unit_rx [NRXCORES];
trace_rx_puzzle_t				trace_rx__rx_puzzle [NRXCORES];
trace_rx_fifo_t					trace_rx__rx_fifo [NRXCORES];
// TX-only tracing
trace_outputs_t					trace_tx__proc [NTXCORES];
trace_sp_unit_t					trace_tx__sp_unit [NTXCORES];
trace_sp_unit_tx_t				trace_tx__sp_unit_tx [NTXCORES];
trace_tx_puzzle_t				trace_tx__tx_puzzle [NTXCORES];
// TX-specific tracing
trace_checksum_t				trace_tx__csum [NTXCORES];
trace_atf_t						trace_tx__atf [NTXCORES];
trace_atf_bds_t					trace_tx__atf_bds [NTXCORES];

/*
 * RX
 */
`ifdef ENABLE_RX__PROC_TRACE
localparam int TRACE_RX__PROC_IDX = 0;
assign trace_rx__proc_operand_stall =					trace_rx__proc[TRACE_RX__PROC_IDX].events.operand_stall;
assign trace_rx__proc_unit_stall =						trace_rx__proc[TRACE_RX__PROC_IDX].events.unit_stall;
assign trace_rx__proc_no_id_stall =						trace_rx__proc[TRACE_RX__PROC_IDX].events.no_id_stall;
assign trace_rx__proc_no_instruction_stall =			trace_rx__proc[TRACE_RX__PROC_IDX].events.no_instruction_stall;
assign trace_rx__proc_other_stall =						trace_rx__proc[TRACE_RX__PROC_IDX].events.other_stall;
assign trace_rx__proc_instruction_issued_dec =			trace_rx__proc[TRACE_RX__PROC_IDX].events.instruction_issued_dec;
assign trace_rx__proc_branch_operand_stall =			trace_rx__proc[TRACE_RX__PROC_IDX].events.branch_operand_stall;
assign trace_rx__proc_alu_operand_stall =				trace_rx__proc[TRACE_RX__PROC_IDX].events.alu_operand_stall;
assign trace_rx__proc_ls_operand_stall =				trace_rx__proc[TRACE_RX__PROC_IDX].events.ls_operand_stall;
assign trace_rx__proc_div_operand_stall =				trace_rx__proc[TRACE_RX__PROC_IDX].events.div_operand_stall;
assign trace_rx__proc_alu_op =							trace_rx__proc[TRACE_RX__PROC_IDX].events.alu_op;
assign trace_rx__proc_branch_or_jump_op =				trace_rx__proc[TRACE_RX__PROC_IDX].events.branch_or_jump_op;
assign trace_rx__proc_load_op =							trace_rx__proc[TRACE_RX__PROC_IDX].events.load_op;
assign trace_rx__proc_lr =								trace_rx__proc[TRACE_RX__PROC_IDX].events.lr;
assign trace_rx__proc_store_op =						trace_rx__proc[TRACE_RX__PROC_IDX].events.store_op;
assign trace_rx__proc_sc =								trace_rx__proc[TRACE_RX__PROC_IDX].events.sc;
assign trace_rx__proc_mul_op =							trace_rx__proc[TRACE_RX__PROC_IDX].events.mul_op;
assign trace_rx__proc_div_op =							trace_rx__proc[TRACE_RX__PROC_IDX].events.div_op;
assign trace_rx__proc_misc_op =							trace_rx__proc[TRACE_RX__PROC_IDX].events.misc_op;
assign trace_rx__proc_branch_correct =					trace_rx__proc[TRACE_RX__PROC_IDX].events.branch_correct;
assign trace_rx__proc_branch_misspredict =				trace_rx__proc[TRACE_RX__PROC_IDX].events.branch_misspredict;
assign trace_rx__proc_return_correct =					trace_rx__proc[TRACE_RX__PROC_IDX].events.return_correct;
assign trace_rx__proc_return_misspredict =				trace_rx__proc[TRACE_RX__PROC_IDX].events.return_misspredict;
assign trace_rx__proc_rs1_forwarding_needed =			trace_rx__proc[TRACE_RX__PROC_IDX].events.rs1_forwarding_needed;
assign trace_rx__proc_rs2_forwarding_needed =			trace_rx__proc[TRACE_RX__PROC_IDX].events.rs2_forwarding_needed;
assign trace_rx__proc_rs1_and_rs2_forwarding_needed =	trace_rx__proc[TRACE_RX__PROC_IDX].events.rs1_and_rs2_forwarding_needed;
assign trace_rx__proc_instruction_pc_dec =				trace_rx__proc[TRACE_RX__PROC_IDX].instruction_pc_dec;
assign trace_rx__proc_instruction_data_dec =			trace_rx__proc[TRACE_RX__PROC_IDX].instruction_data_dec;
`endif

`ifdef ENABLE_TRACE_RX__SP_UNIT
localparam int TRACE_RX__SP_UNIT_IDX = 0;
assign trace_rx__sp_unit_acp_read_start =				trace_rx__sp_unit[TRACE_RX__SP_UNIT_IDX].acp_read_start;
assign trace_rx__sp_unit_acp_read_status =				trace_rx__sp_unit[TRACE_RX__SP_UNIT_IDX].acp_read_status;
assign trace_rx__sp_unit_acp_write_start =				trace_rx__sp_unit[TRACE_RX__SP_UNIT_IDX].acp_write_start;
assign trace_rx__sp_unit_acp_write_status =				trace_rx__sp_unit[TRACE_RX__SP_UNIT_IDX].acp_write_status;
`endif

`ifdef ENABLE_TRACE_RX__SP_UNIT_RX
localparam int TRACE_RX__SP_UNIT_RX_IDX = 0;
assign trace_rx__sp_unit_rx_rx_meta_pop =				trace_rx__sp_unit_rx[TRACE_RX__SP_UNIT_RX_IDX].rx_meta_pop;
assign trace_rx__sp_unit_rx_rx_meta_empty =				trace_rx__sp_unit_rx[TRACE_RX__SP_UNIT_RX_IDX].rx_meta_empty;
assign trace_rx__sp_unit_rx_rx_data_dma_start =			trace_rx__sp_unit_rx[TRACE_RX__SP_UNIT_RX_IDX].rx_data_dma_start;
assign trace_rx__sp_unit_rx_rx_data_dma_status =		trace_rx__sp_unit_rx[TRACE_RX__SP_UNIT_RX_IDX].rx_data_dma_status;
assign trace_rx__sp_unit_rx_rx_dma_busy =				trace_rx__sp_unit_rx[TRACE_RX__SP_UNIT_RX_IDX].rx_dma_busy;
`endif

`ifdef ENABLE_TRACE_RX__RX_PUZZLE
localparam int TRACE_RX__RX_PUZZLE_IDX = 0;
assign trace_rx__rxenable =								trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].rx_enable;
assign trace_rx__rxtrigger =							trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].rx_trigger;

assign trace_rx__rx_puzzle_fifo_r_0_empty =				trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].puzzle_fifo_r_0_empty;
assign trace_rx__rx_puzzle_fifo_r_0_rd_en =				trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].puzzle_fifo_r_0_rd_en;
assign trace_rx__rx_puzzle_fifo_r_0_rd_data =			trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].puzzle_fifo_r_0_rd_data;
assign trace_rx__rx_puzzle_fifo_r_0_rd_data_count =		trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].puzzle_fifo_r_0_rd_data_count;
assign trace_rx__rx_puzzle_fifo_r_1_empty =				trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].puzzle_fifo_r_1_empty;
assign trace_rx__rx_puzzle_fifo_r_1_rd_en =				trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].puzzle_fifo_r_1_rd_en;
assign trace_rx__rx_puzzle_fifo_r_1_rd_data =			trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].puzzle_fifo_r_1_rd_data;
assign trace_rx__rx_puzzle_fifo_r_1_rd_data_count =		trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].puzzle_fifo_r_1_rd_data_count;
assign trace_rx__rx_puzzle_fifo_r_2_empty =				trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].puzzle_fifo_r_2_empty;
assign trace_rx__rx_puzzle_fifo_r_2_rd_en =				trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].puzzle_fifo_r_2_rd_en;
assign trace_rx__rx_puzzle_fifo_r_2_rd_data =			trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].puzzle_fifo_r_2_rd_data;
assign trace_rx__rx_puzzle_fifo_r_2_rd_data_count =		trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].puzzle_fifo_r_2_rd_data_count;
assign trace_rx__rx_puzzle_fifo_r_3_empty =				trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].puzzle_fifo_r_3_empty;
assign trace_rx__rx_puzzle_fifo_r_3_rd_en =				trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].puzzle_fifo_r_3_rd_en;
assign trace_rx__rx_puzzle_fifo_r_3_rd_data =			trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].puzzle_fifo_r_3_rd_data;
assign trace_rx__rx_puzzle_fifo_r_3_rd_data_count =		trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].puzzle_fifo_r_3_rd_data_count;

assign trace_rx__rx_puzzle_fifo_w_0_full =				trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].puzzle_fifo_w_0_full;
assign trace_rx__rx_puzzle_fifo_w_0_wr_en =				trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].puzzle_fifo_w_0_wr_en;
assign trace_rx__rx_puzzle_fifo_w_0_wr_data =			trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].puzzle_fifo_w_0_wr_data;
assign trace_rx__rx_puzzle_fifo_w_0_wr_data_count =		trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].puzzle_fifo_w_0_wr_data_count;
assign trace_rx__rx_puzzle_fifo_w_1_full =				trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].puzzle_fifo_w_1_full;
assign trace_rx__rx_puzzle_fifo_w_1_wr_data =			trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].puzzle_fifo_w_1_wr_data;
assign trace_rx__rx_puzzle_fifo_w_1_wr_en =				trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].puzzle_fifo_w_1_wr_en;
assign trace_rx__rx_puzzle_fifo_w_1_wr_data_count =		trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].puzzle_fifo_w_1_wr_data_count;
assign trace_rx__rx_puzzle_fifo_w_2_full =				trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].puzzle_fifo_w_2_full;
assign trace_rx__rx_puzzle_fifo_w_2_wr_en =				trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].puzzle_fifo_w_2_wr_en;
assign trace_rx__rx_puzzle_fifo_w_2_wr_data =			trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].puzzle_fifo_w_2_wr_data;
assign trace_rx__rx_puzzle_fifo_w_2_wr_data_count =		trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].puzzle_fifo_w_2_wr_data_count;
assign trace_rx__rx_puzzle_fifo_w_3_full =				trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].puzzle_fifo_w_3_full;
assign trace_rx__rx_puzzle_fifo_w_3_wr_en =				trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].puzzle_fifo_w_3_wr_en;
assign trace_rx__rx_puzzle_fifo_w_3_wr_data =			trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].puzzle_fifo_w_3_wr_data;
assign trace_rx__rx_puzzle_fifo_w_3_wr_data_count =		trace_rx__rx_puzzle[TRACE_RX__RX_PUZZLE_IDX].puzzle_fifo_w_3_wr_data_count;
`endif

`ifdef ENABLE_TRACE_RX__RX_FIFO
localparam int TRACE_RX__RX_FIFO_IDX = 0;
assign trace_rx__rx_fifo_meta_fifo_r_empty =			trace_rx__rx_fifo[TRACE_RX__RX_FIFO_IDX].meta_fifo_r_empty;
assign trace_rx__rx_fifo_meta_fifo_r_rd_en =			trace_rx__rx_fifo[TRACE_RX__RX_FIFO_IDX].meta_fifo_r_rd_en;
assign trace_rx__rx_fifo_meta_fifo_r_rd_data =			trace_rx__rx_fifo[TRACE_RX__RX_FIFO_IDX].meta_fifo_r_rd_data;
assign trace_rx__rx_fifo_meta_fifo_r_rd_data_count =	trace_rx__rx_fifo[TRACE_RX__RX_FIFO_IDX].meta_fifo_r_rd_data_count;
assign trace_rx__rx_fifo_meta_fifo_w_full =				trace_rx__rx_fifo[TRACE_RX__RX_FIFO_IDX].meta_fifo_w_full;
assign trace_rx__rx_fifo_meta_fifo_w_wr_en =			trace_rx__rx_fifo[TRACE_RX__RX_FIFO_IDX].meta_fifo_w_wr_en;
assign trace_rx__rx_fifo_meta_fifo_w_wr_data =			trace_rx__rx_fifo[TRACE_RX__RX_FIFO_IDX].meta_fifo_w_wr_data;
assign trace_rx__rx_fifo_meta_fifo_w_wr_data_count =	trace_rx__rx_fifo[TRACE_RX__RX_FIFO_IDX].meta_fifo_w_wr_data_count;
`endif

/*
 * TX
 */
`ifdef ENABLE_TX__PROC_TRACE
localparam int TRACE_TX__PROC_IDX = 0;
assign trace_tx__proc_operand_stall =					trace_tx__proc[TRACE_TX__PROC_IDX].events.operand_stall;
assign trace_tx__proc_unit_stall =						trace_tx__proc[TRACE_TX__PROC_IDX].events.unit_stall;
assign trace_tx__proc_no_id_stall =						trace_tx__proc[TRACE_TX__PROC_IDX].events.no_id_stall;
assign trace_tx__proc_no_instruction_stall =			trace_tx__proc[TRACE_TX__PROC_IDX].events.no_instruction_stall;
assign trace_tx__proc_other_stall =						trace_tx__proc[TRACE_TX__PROC_IDX].events.other_stall;
assign trace_tx__proc_instruction_issued_dec =			trace_tx__proc[TRACE_TX__PROC_IDX].events.instruction_issued_dec;
assign trace_tx__proc_branch_operand_stall =			trace_tx__proc[TRACE_TX__PROC_IDX].events.branch_operand_stall;
assign trace_tx__proc_alu_operand_stall =				trace_tx__proc[TRACE_TX__PROC_IDX].events.alu_operand_stall;
assign trace_tx__proc_ls_operand_stall =				trace_tx__proc[TRACE_TX__PROC_IDX].events.ls_operand_stall;
assign trace_tx__proc_div_operand_stall =				trace_tx__proc[TRACE_TX__PROC_IDX].events.div_operand_stall;
assign trace_tx__proc_alu_op =							trace_tx__proc[TRACE_TX__PROC_IDX].events.alu_op;
assign trace_tx__proc_branch_or_jump_op =				trace_tx__proc[TRACE_TX__PROC_IDX].events.branch_or_jump_op;
assign trace_tx__proc_load_op =							trace_tx__proc[TRACE_TX__PROC_IDX].events.load_op;
assign trace_tx__proc_lr =								trace_tx__proc[TRACE_TX__PROC_IDX].events.lr;
assign trace_tx__proc_store_op =						trace_tx__proc[TRACE_TX__PROC_IDX].events.store_op;
assign trace_tx__proc_sc =								trace_tx__proc[TRACE_TX__PROC_IDX].events.sc;
assign trace_tx__proc_mul_op =							trace_tx__proc[TRACE_TX__PROC_IDX].events.mul_op;
assign trace_tx__proc_div_op =							trace_tx__proc[TRACE_TX__PROC_IDX].events.div_op;
assign trace_tx__proc_misc_op =							trace_tx__proc[TRACE_TX__PROC_IDX].events.misc_op;
assign trace_tx__proc_branch_correct =					trace_tx__proc[TRACE_TX__PROC_IDX].events.branch_correct;
assign trace_tx__proc_branch_misspredict =				trace_tx__proc[TRACE_TX__PROC_IDX].events.branch_misspredict;
assign trace_tx__proc_return_correct =					trace_tx__proc[TRACE_TX__PROC_IDX].events.return_correct;
assign trace_tx__proc_return_misspredict =				trace_tx__proc[TRACE_TX__PROC_IDX].events.return_misspredict;
assign trace_tx__proc_rs1_forwarding_needed =			trace_tx__proc[TRACE_TX__PROC_IDX].events.rs1_forwarding_needed;
assign trace_tx__proc_rs2_forwarding_needed =			trace_tx__proc[TRACE_TX__PROC_IDX].events.rs2_forwarding_needed;
assign trace_tx__proc_rs1_and_rs2_forwarding_needed =	trace_tx__proc[TRACE_TX__PROC_IDX].events.rs1_and_rs2_forwarding_needed;
assign trace_tx__proc_instruction_pc_dec =				trace_tx__proc[TRACE_TX__PROC_IDX].instruction_pc_dec;
assign trace_tx__proc_instruction_data_dec =			trace_tx__proc[TRACE_TX__PROC_IDX].instruction_data_dec;
`endif

`ifdef ENABLE_TRACE_TX__SP_UNIT
localparam int TRACE_TX__SP_UNIT_IDX = 0;
assign trace_tx__sp_unit_acp_read_start =				trace_tx__sp_unit[TRACE_TX__SP_UNIT_IDX].acp_read_start;
assign trace_tx__sp_unit_acp_read_status =				trace_tx__sp_unit[TRACE_TX__SP_UNIT_IDX].acp_read_status;
assign trace_tx__sp_unit_acp_write_start =				trace_tx__sp_unit[TRACE_TX__SP_UNIT_IDX].acp_write_start;
assign trace_tx__sp_unit_acp_write_status =				trace_tx__sp_unit[TRACE_TX__SP_UNIT_IDX].acp_write_status;
`endif

`ifdef ENABLE_TRACE_TX__SP_UNIT_TX
localparam int TRACE_TX__SP_UNIT_TX_IDX = 0;
assign trace_tx__sp_unit_tx_tx_meta_push =				trace_tx__sp_unit_tx[TRACE_TX__SP_UNIT_TX_IDX].tx_meta_push;
assign trace_tx__sp_unit_tx_tx_meta_full =				trace_tx__sp_unit_tx[TRACE_TX__SP_UNIT_TX_IDX].tx_meta_full;
assign trace_tx__sp_unit_tx_tx_data_dma_start =			trace_tx__sp_unit_tx[TRACE_TX__SP_UNIT_TX_IDX].tx_data_dma_start;
assign trace_tx__sp_unit_tx_tx_data_dma_status =		trace_tx__sp_unit_tx[TRACE_TX__SP_UNIT_TX_IDX].tx_data_dma_status;
assign trace_tx__sp_unit_tx_tx_dma_busy =				trace_tx__sp_unit_tx[TRACE_TX__SP_UNIT_TX_IDX].tx_dma_busy;
`endif

`ifdef ENABLE_TRACE_TX__TX_PUZZLE
localparam int TRACE_TX__TX_PUZZLE_IDX = 0;
assign trace_tx__txenable =								trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].tx_enable;
assign trace_tx__txtrigger =							trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].tx_trigger;

assign trace_tx__tx_puzzle_fifo_r_0_empty =				trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].puzzle_fifo_r_0_empty;
assign trace_tx__tx_puzzle_fifo_r_0_rd_en =				trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].puzzle_fifo_r_0_rd_en;
assign trace_tx__tx_puzzle_fifo_r_0_rd_data =			trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].puzzle_fifo_r_0_rd_data;
assign trace_tx__tx_puzzle_fifo_r_0_rd_data_count =		trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].puzzle_fifo_r_0_rd_data_count;
assign trace_tx__tx_puzzle_fifo_r_1_empty =				trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].puzzle_fifo_r_1_empty;
assign trace_tx__tx_puzzle_fifo_r_1_rd_en =				trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].puzzle_fifo_r_1_rd_en;
assign trace_tx__tx_puzzle_fifo_r_1_rd_data =			trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].puzzle_fifo_r_1_rd_data;
assign trace_tx__tx_puzzle_fifo_r_1_rd_data_count =		trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].puzzle_fifo_r_1_rd_data_count;
assign trace_tx__tx_puzzle_fifo_r_2_empty =				trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].puzzle_fifo_r_2_empty;
assign trace_tx__tx_puzzle_fifo_r_2_rd_en =				trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].puzzle_fifo_r_2_rd_en;
assign trace_tx__tx_puzzle_fifo_r_2_rd_data =			trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].puzzle_fifo_r_2_rd_data;
assign trace_tx__tx_puzzle_fifo_r_2_rd_data_count =		trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].puzzle_fifo_r_2_rd_data_count;
assign trace_tx__tx_puzzle_fifo_r_3_empty =				trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].puzzle_fifo_r_3_empty;
assign trace_tx__tx_puzzle_fifo_r_3_rd_en =				trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].puzzle_fifo_r_3_rd_en;
assign trace_tx__tx_puzzle_fifo_r_3_rd_data =			trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].puzzle_fifo_r_3_rd_data;
assign trace_tx__tx_puzzle_fifo_r_3_rd_data_count =		trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].puzzle_fifo_r_3_rd_data_count;

assign trace_tx__tx_puzzle_fifo_w_0_full =				trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].puzzle_fifo_w_0_full;
assign trace_tx__tx_puzzle_fifo_w_0_wr_en =				trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].puzzle_fifo_w_0_wr_en;
assign trace_tx__tx_puzzle_fifo_w_0_wr_data =			trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].puzzle_fifo_w_0_wr_data;
assign trace_tx__tx_puzzle_fifo_w_0_wr_data_count =		trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].puzzle_fifo_w_0_wr_data_count;
assign trace_tx__tx_puzzle_fifo_w_1_full =				trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].puzzle_fifo_w_1_full;
assign trace_tx__tx_puzzle_fifo_w_1_wr_data =			trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].puzzle_fifo_w_1_wr_data;
assign trace_tx__tx_puzzle_fifo_w_1_wr_en =				trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].puzzle_fifo_w_1_wr_en;
assign trace_tx__tx_puzzle_fifo_w_1_wr_data_count =		trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].puzzle_fifo_w_1_wr_data_count;
assign trace_tx__tx_puzzle_fifo_w_2_full =				trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].puzzle_fifo_w_2_full;
assign trace_tx__tx_puzzle_fifo_w_2_wr_en =				trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].puzzle_fifo_w_2_wr_en;
assign trace_tx__tx_puzzle_fifo_w_2_wr_data =			trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].puzzle_fifo_w_2_wr_data;
assign trace_tx__tx_puzzle_fifo_w_2_wr_data_count =		trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].puzzle_fifo_w_2_wr_data_count;
assign trace_tx__tx_puzzle_fifo_w_3_full =				trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].puzzle_fifo_w_3_full;
assign trace_tx__tx_puzzle_fifo_w_3_wr_en =				trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].puzzle_fifo_w_3_wr_en;
assign trace_tx__tx_puzzle_fifo_w_3_wr_data =			trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].puzzle_fifo_w_3_wr_data;
assign trace_tx__tx_puzzle_fifo_w_3_wr_data_count =		trace_tx__tx_puzzle[TRACE_TX__TX_PUZZLE_IDX].puzzle_fifo_w_3_wr_data_count;
`endif

`ifdef ENABLE_TRACE_TX__CSUM
localparam int TRACE_TX__CSUM_IDX = 0;
assign trace_tx__csum_ip_state =			trace_tx__csum[TRACE_TX__CSUM_IDX].ip_state;
assign trace_tx__csum_l4_state =			trace_tx__csum[TRACE_TX__CSUM_IDX].l4_state;
assign trace_tx__csum_p_valid =				trace_tx__csum[TRACE_TX__CSUM_IDX].p_valid;
assign trace_tx__csum_p_sof =				trace_tx__csum[TRACE_TX__CSUM_IDX].p_sof;
assign trace_tx__csum_p_eof =				trace_tx__csum[TRACE_TX__CSUM_IDX].p_eof;
assign trace_tx__csum_commit_checksum =		trace_tx__csum[TRACE_TX__CSUM_IDX].commit_checksum;
assign trace_tx__csum_eth_type =			trace_tx__csum[TRACE_TX__CSUM_IDX].eth_type;
assign trace_tx__csum_ip_sum =				trace_tx__csum[TRACE_TX__CSUM_IDX].ip_sum;
assign trace_tx__csum_ip_proto =			trace_tx__csum[TRACE_TX__CSUM_IDX].ip_proto;
assign trace_tx__csum_l4_sum =				trace_tx__csum[TRACE_TX__CSUM_IDX].l4_sum;
`endif

`ifdef ENABLE_TRACE_TX__ATF
localparam int TRACE_TX__ATF_IDX = 0;
assign trace_tx__atf_stuffer_first =			trace_tx__atf[TRACE_TX__ATF_IDX].stuffer_first;
assign trace_tx__atf_stuffer_i_valid =			trace_tx__atf[TRACE_TX__ATF_IDX].stuffer_i_valid;
assign trace_tx__atf_stuffer_i_sof =			trace_tx__atf[TRACE_TX__ATF_IDX].stuffer_i_sof;
assign trace_tx__atf_stuffer_i_eof =			trace_tx__atf[TRACE_TX__ATF_IDX].stuffer_i_eof;
assign trace_tx__atf_stuffer_i_lsbyte =			trace_tx__atf[TRACE_TX__ATF_IDX].stuffer_i_lsbyte;
assign trace_tx__atf_stuffer_i_msbyte =			trace_tx__atf[TRACE_TX__ATF_IDX].stuffer_i_msbyte;
assign trace_tx__atf_stuffer_i_data =			trace_tx__atf[TRACE_TX__ATF_IDX].stuffer_i_data;
assign trace_tx__atf_stuffer_o_valid =			trace_tx__atf[TRACE_TX__ATF_IDX].stuffer_o_valid;
assign trace_tx__atf_stuffer_o_data =			trace_tx__atf[TRACE_TX__ATF_IDX].stuffer_o_data;
assign trace_tx__atf_axi_calc_i_valid =			trace_tx__atf[TRACE_TX__ATF_IDX].axi_calc_i_valid;
assign trace_tx__atf_axi_calc_i_address =		trace_tx__atf[TRACE_TX__ATF_IDX].axi_calc_i_address;
assign trace_tx__atf_axi_calc_i_length =		trace_tx__atf[TRACE_TX__ATF_IDX].axi_calc_i_length;
assign trace_tx__atf_axi_calc_i_axhshake =		trace_tx__atf[TRACE_TX__ATF_IDX].axi_calc_i_axhshake;
assign trace_tx__atf_axi_calc_o_valid =			trace_tx__atf[TRACE_TX__ATF_IDX].axi_calc_o_valid;
assign trace_tx__atf_axi_calc_o_axaddr =		trace_tx__atf[TRACE_TX__ATF_IDX].axi_calc_o_axaddr;
assign trace_tx__atf_axi_calc_o_axlen = 		trace_tx__atf[TRACE_TX__ATF_IDX].axi_calc_o_axlen;
assign trace_tx__atf_mem_r_len_plus_off =		trace_tx__atf[TRACE_TX__ATF_IDX].mem_r_len_plus_off;
assign trace_tx__atf__total_beats_comb =		trace_tx__atf[TRACE_TX__ATF_IDX]._total_beats_comb;
assign trace_tx__atf_total_beats_comb =			trace_tx__atf[TRACE_TX__ATF_IDX].total_beats_comb;
assign trace_tx__atf_total_beats =				trace_tx__atf[TRACE_TX__ATF_IDX].total_beats;
assign trace_tx__atf_total_bursts_comb =		trace_tx__atf[TRACE_TX__ATF_IDX].total_bursts_comb;
assign trace_tx__atf_total_bursts =				trace_tx__atf[TRACE_TX__ATF_IDX].total_bursts;
assign trace_tx__atf_last_burst_beats =			trace_tx__atf[TRACE_TX__ATF_IDX].last_burst_beats;
assign trace_tx__atf_last_beat_bytes =			trace_tx__atf[TRACE_TX__ATF_IDX].last_beat_bytes;
`endif

`ifdef ENABLE_TRACE_TX__ATF_BDS
localparam int TRACE_TX__ATF_BDS_IDX = 0;
assign trace_tx__atf_bds_poisoned =					trace_tx__atf_bds[TRACE_TX__ATF_BDS_IDX].poisoned;
assign trace_tx__atf_bds_stage0_data_shr_comb =		trace_tx__atf_bds[TRACE_TX__ATF_BDS_IDX].stage0_data_shr_comb;
assign trace_tx__atf_bds_stage0_bytemask_comb =		trace_tx__atf_bds[TRACE_TX__ATF_BDS_IDX].stage0_bytemask_comb;
assign trace_tx__atf_bds_stage1_valid_ff =			trace_tx__atf_bds[TRACE_TX__ATF_BDS_IDX].stage1_valid_ff;
assign trace_tx__atf_bds_stage1_data_ff =			trace_tx__atf_bds[TRACE_TX__ATF_BDS_IDX].stage1_data_ff;
assign trace_tx__atf_bds_stage1_size_ff =			trace_tx__atf_bds[TRACE_TX__ATF_BDS_IDX].stage1_size_ff;
assign trace_tx__atf_bds_stage1_bytemask_ff =		trace_tx__atf_bds[TRACE_TX__ATF_BDS_IDX].stage1_bytemask_ff;
assign trace_tx__atf_bds_stage1_sof_ff =			trace_tx__atf_bds[TRACE_TX__ATF_BDS_IDX].stage1_sof_ff;
assign trace_tx__atf_bds_stage1_eof_ff =			trace_tx__atf_bds[TRACE_TX__ATF_BDS_IDX].stage1_eof_ff;
assign trace_tx__atf_bds_stage1_bitmask_comb =		trace_tx__atf_bds[TRACE_TX__ATF_BDS_IDX].stage1_bitmask_comb;
assign trace_tx__atf_bds_stage2_valid_ff =			trace_tx__atf_bds[TRACE_TX__ATF_BDS_IDX].stage2_valid_ff;
assign trace_tx__atf_bds_stage2_data_ff =			trace_tx__atf_bds[TRACE_TX__ATF_BDS_IDX].stage2_data_ff;
assign trace_tx__atf_bds_stage2_size_ff =			trace_tx__atf_bds[TRACE_TX__ATF_BDS_IDX].stage2_size_ff;
assign trace_tx__atf_bds_stage2_sof_ff =			trace_tx__atf_bds[TRACE_TX__ATF_BDS_IDX].stage2_sof_ff;
assign trace_tx__atf_bds_stage2_eof_ff =			trace_tx__atf_bds[TRACE_TX__ATF_BDS_IDX].stage2_eof_ff;
assign trace_tx__atf_bds_stage2_data_shl_comb =		trace_tx__atf_bds[TRACE_TX__ATF_BDS_IDX].stage2_data_shl_comb;
assign trace_tx__atf_bds_stage3_valid_ff =			trace_tx__atf_bds[TRACE_TX__ATF_BDS_IDX].stage3_valid_ff;
assign trace_tx__atf_bds_stage3_sof_ff =			trace_tx__atf_bds[TRACE_TX__ATF_BDS_IDX].stage3_sof_ff;
assign trace_tx__atf_bds_stage3_sof_comb =			trace_tx__atf_bds[TRACE_TX__ATF_BDS_IDX].stage3_sof_comb;
assign trace_tx__atf_bds_stage3_eof_ff =			trace_tx__atf_bds[TRACE_TX__ATF_BDS_IDX].stage3_eof_ff;
assign trace_tx__atf_bds_stage3_data_ff =			trace_tx__atf_bds[TRACE_TX__ATF_BDS_IDX].stage3_data_ff;
assign trace_tx__atf_bds_stage3_data_comb =			trace_tx__atf_bds[TRACE_TX__ATF_BDS_IDX].stage3_data_comb;
assign trace_tx__atf_bds_stage3_size_ff =			trace_tx__atf_bds[TRACE_TX__ATF_BDS_IDX].stage3_size_ff;
assign trace_tx__atf_bds_stage3_size_comb =			trace_tx__atf_bds[TRACE_TX__ATF_BDS_IDX].stage3_size_comb;
`endif

prism_sp_rx_top #(
	.IBRAM_SIZE(IBRAM_SIZE),
	.DBRAM_SIZE(DBRAM_SIZE),
	.ACPBRAM_SIZE(ACPBRAM_SIZE),
	.RX_DATA_FIFO_SIZE(RX_DATA_FIFO_SIZE),
	.RX_DATA_FIFO_WIDTH(C_M_AXI_DMA_DATA_WIDTH),
	.NRXCORES(NRXCORES)
) prism_sp_rx_top_0 (
	.clock(clock),
	.resetn(resetn),

	.control_irq(rx_control_irq),
	.channel_irqs(rx_channel_irqs),

	.s_axil_aw(s_axil_aw[RXLOWIDX:RXHIGHIDX]),
	.s_axil_w(s_axil_w[RXLOWIDX:RXHIGHIDX]),
	.s_axil_b(s_axil_b[RXLOWIDX:RXHIGHIDX]),
	.s_axil_ar(s_axil_ar[RXLOWIDX:RXHIGHIDX]),
	.s_axil_r(s_axil_r[RXLOWIDX:RXHIGHIDX]),

	.m_axi_ma_aw(m_axi_ma_aw[RXLOWIDX:RXHIGHIDX]),
	.m_axi_ma_w(m_axi_ma_w[RXLOWIDX:RXHIGHIDX]),
	.m_axi_ma_b(m_axi_ma_b[RXLOWIDX:RXHIGHIDX]),
	.m_axi_ma_ar(m_axi_ma_ar[RXLOWIDX:RXHIGHIDX]),
	.m_axi_ma_r(m_axi_ma_r[RXLOWIDX:RXHIGHIDX]),

	.m_axi_mb_aw(m_axi_mb_aw[RXLOWIDX:RXHIGHIDX]),
	.m_axi_mb_w(m_axi_mb_w[RXLOWIDX:RXHIGHIDX]),
	.m_axi_mb_b(m_axi_mb_b[RXLOWIDX:RXHIGHIDX]),
	.m_axi_mb_ar(m_axi_mb_ar[RXLOWIDX:RXHIGHIDX]),
	.m_axi_mb_r(m_axi_mb_r[RXLOWIDX:RXHIGHIDX]),

	.m_axi_mx(m_axi_mx[RXLOWIDX:RXHIGHIDX]),

	.s_axi_sa_aw(s_axi_sa_aw[RXLOWIDX:RXHIGHIDX]),
	.s_axi_sa_w(s_axi_sa_w[RXLOWIDX:RXHIGHIDX]),
	.s_axi_sa_b(s_axi_sa_b[RXLOWIDX:RXHIGHIDX]),
	.s_axi_sa_ar(s_axi_sa_ar[RXLOWIDX:RXHIGHIDX]),
	.s_axi_sa_r(s_axi_sa_r[RXLOWIDX:RXHIGHIDX]),

	.s_axi_sb_aw(s_axi_sb_aw[RXLOWIDX:RXHIGHIDX]),
	.s_axi_sb_w(s_axi_sb_w[RXLOWIDX:RXHIGHIDX]),
	.s_axi_sb_b(s_axi_sb_b[RXLOWIDX:RXHIGHIDX]),
	.s_axi_sb_ar(s_axi_sb_ar[RXLOWIDX:RXHIGHIDX]),
	.s_axi_sb_r(s_axi_sb_r[RXLOWIDX:RXHIGHIDX]),

	.m_axi_acp_aw(m_axi_acp_aw[RXLOWIDX:RXHIGHIDX]),
	.m_axi_acp_w(m_axi_acp_w[RXLOWIDX:RXHIGHIDX]),
	.m_axi_acp_b(m_axi_acp_b[RXLOWIDX:RXHIGHIDX]),
	.m_axi_acp_ar(m_axi_acp_ar[RXLOWIDX:RXHIGHIDX]),
	.m_axi_acp_r(m_axi_acp_r[RXLOWIDX:RXHIGHIDX]),

	.m_axi_dma_aw,
	.m_axi_dma_w,
	.m_axi_dma_b,

	.gem_rx,

	.trace_proc(trace_rx__proc),
	.trace_sp_unit(trace_rx__sp_unit),
	.trace_sp_unit_rx(trace_rx__sp_unit_rx),
	.trace_rx_puzzle(trace_rx__rx_puzzle),
	.trace_rx_fifo(trace_rx__rx_fifo)
);

prism_sp_tx_top #(
	.IBRAM_SIZE(IBRAM_SIZE),
	.DBRAM_SIZE(DBRAM_SIZE),
	.ACPBRAM_SIZE(ACPBRAM_SIZE),
	.TX_DATA_FIFO_SIZE(TX_DATA_FIFO_SIZE),
	.TX_DATA_FIFO_WIDTH(C_M_AXI_DMA_DATA_WIDTH),
	.NTXCORES(NTXCORES)
) prism_sp_tx_top_0 (
	.clock(clock),
	.resetn(resetn),

	.control_irq(tx_control_irq),
	.channel_irqs(tx_channel_irqs),

	.s_axil_aw(s_axil_aw[TXLOWIDX:TXHIGHIDX]),
	.s_axil_w(s_axil_w[TXLOWIDX:TXHIGHIDX]),
	.s_axil_b(s_axil_b[TXLOWIDX:TXHIGHIDX]),
	.s_axil_ar(s_axil_ar[TXLOWIDX:TXHIGHIDX]),
	.s_axil_r(s_axil_r[TXLOWIDX:TXHIGHIDX]),

	.m_axi_ma_aw(m_axi_ma_aw[TXLOWIDX:TXHIGHIDX]),
	.m_axi_ma_w(m_axi_ma_w[TXLOWIDX:TXHIGHIDX]),
	.m_axi_ma_b(m_axi_ma_b[TXLOWIDX:TXHIGHIDX]),
	.m_axi_ma_ar(m_axi_ma_ar[TXLOWIDX:TXHIGHIDX]),
	.m_axi_ma_r(m_axi_ma_r[TXLOWIDX:TXHIGHIDX]),

	.m_axi_mb_aw(m_axi_mb_aw[TXLOWIDX:TXHIGHIDX]),
	.m_axi_mb_w(m_axi_mb_w[TXLOWIDX:TXHIGHIDX]),
	.m_axi_mb_b(m_axi_mb_b[TXLOWIDX:TXHIGHIDX]),
	.m_axi_mb_ar(m_axi_mb_ar[TXLOWIDX:TXHIGHIDX]),
	.m_axi_mb_r(m_axi_mb_r[TXLOWIDX:TXHIGHIDX]),

	.m_axi_mx(m_axi_mx[TXLOWIDX:TXHIGHIDX]),

	.s_axi_sa_aw(s_axi_sa_aw[TXLOWIDX:TXHIGHIDX]),
	.s_axi_sa_w(s_axi_sa_w[TXLOWIDX:TXHIGHIDX]),
	.s_axi_sa_b(s_axi_sa_b[TXLOWIDX:TXHIGHIDX]),
	.s_axi_sa_ar(s_axi_sa_ar[TXLOWIDX:TXHIGHIDX]),
	.s_axi_sa_r(s_axi_sa_r[TXLOWIDX:TXHIGHIDX]),

	.s_axi_sb_aw(s_axi_sb_aw[TXLOWIDX:TXHIGHIDX]),
	.s_axi_sb_w(s_axi_sb_w[TXLOWIDX:TXHIGHIDX]),
	.s_axi_sb_b(s_axi_sb_b[TXLOWIDX:TXHIGHIDX]),
	.s_axi_sb_ar(s_axi_sb_ar[TXLOWIDX:TXHIGHIDX]),
	.s_axi_sb_r(s_axi_sb_r[TXLOWIDX:TXHIGHIDX]),

	.m_axi_acp_aw(m_axi_acp_aw[TXLOWIDX:TXHIGHIDX]),
	.m_axi_acp_w(m_axi_acp_w[TXLOWIDX:TXHIGHIDX]),
	.m_axi_acp_b(m_axi_acp_b[TXLOWIDX:TXHIGHIDX]),
	.m_axi_acp_ar(m_axi_acp_ar[TXLOWIDX:TXHIGHIDX]),
	.m_axi_acp_r(m_axi_acp_r[TXLOWIDX:TXHIGHIDX]),

	.m_axi_dma_ar,
	.m_axi_dma_r,

	.gem_tx,

	.trace_proc(trace_tx__proc),
	.trace_sp_unit(trace_tx__sp_unit),
	.trace_sp_unit_tx(trace_tx__sp_unit_tx),
	.trace_tx_puzzle(trace_tx__tx_puzzle),

	.trace_atf(trace_tx__atf),
	.trace_atf_bds(trace_tx__atf_bds),
	.trace_csum(trace_tx__csum)
);

endmodule
