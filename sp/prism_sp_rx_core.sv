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

module prism_sp_rx_core #(
	parameter int IBRAM_SIZE,
	parameter int DBRAM_SIZE,
	parameter int ACPBRAM_SIZE,

	parameter int RX_DATA_FIFO_SIZE = 0,
	parameter int RX_DATA_FIFO_WIDTH = 0,

	parameter int INSTANCE
)
(
	input wire logic clock,
	input wire logic resetn,

	axi_lite_write_address_channel.slave	s_axil_aw,
	axi_lite_write_channel.slave			s_axil_w,
	axi_lite_write_response_channel.slave	s_axil_b,
	axi_lite_read_address_channel.slave		s_axil_ar,
	axi_lite_read_channel.slave				s_axil_r,

	axi_write_address_channel.master		m_axi_ma_aw,
	axi_write_channel.master				m_axi_ma_w,
	axi_write_response_channel.master		m_axi_ma_b,
	axi_read_address_channel.master			m_axi_ma_ar,
	axi_read_channel.master					m_axi_ma_r,

	axi_write_address_channel.master		m_axi_mb_aw,
	axi_write_channel.master				m_axi_mb_w,
	axi_write_response_channel.master		m_axi_mb_b,
	axi_read_address_channel.master			m_axi_mb_ar,
	axi_read_channel.master					m_axi_mb_r,

	axi_interface.master					m_axi_mx,

	axi_write_address_channel.slave			s_axi_sa_aw,
	axi_write_channel.slave					s_axi_sa_w,
	axi_write_response_channel.slave		s_axi_sa_b,
	axi_read_address_channel.slave			s_axi_sa_ar,
	axi_read_channel.slave					s_axi_sa_r,

	axi_write_address_channel.slave			s_axi_sb_aw,
	axi_write_channel.slave					s_axi_sb_w,
	axi_write_response_channel.slave		s_axi_sb_b,
	axi_read_address_channel.slave			s_axi_sb_ar,
	axi_read_channel.slave					s_axi_sb_r,

	axi_write_address_channel.master		m_axi_acp_aw,
	axi_write_channel.master				m_axi_acp_w,
	axi_write_response_channel.master		m_axi_acp_b,
	axi_read_address_channel.master			m_axi_acp_ar,
	axi_read_channel.master					m_axi_acp_r,

	axi_write_address_channel.master		m_axi_dma_aw,
	axi_write_channel.master				m_axi_dma_w,
	axi_write_response_channel.master		m_axi_dma_b,

	// Driven from the GEM receive module
	fifo_write_interface.slave				rx_data_fifo_w,
	fifo_write_interface.slave				rx_meta_fifo_w,

	output wire logic channel_irq,

	output trace_outputs_t					trace_proc,
	output trace_sp_unit_t					trace_sp_unit,
	output trace_sp_unit_rx_t				trace_sp_unit_rx,
	output trace_rx_puzzle_t				trace_rx_puzzle,
	output trace_rx_fifo_t					trace_rx_fifo
);

/*
 * Local memory interfaces
 */
local_memory_interface instruction_bram_mmr();
local_memory_interface data_bram_mmr();

wire logic cpu_reset;
wire logic [3:0] io_axi_axcache;
wire logic [3:0] dma_axi_axcache;
wire logic [SYSTEM_ADDR_WIDTH-1:0] dma_desc_base;

mmr_readwrite_interface #(.NREGS(MMR_RW_NREGS)) mmr_rw();
mmr_read_interface #(.NREGS(MMR_R_NREGS)) mmr_r();

mmr_trigger_interface #(.N(1),.WIDTH(2)) hw_mmr_t();
mmr_trigger_interface #(.N(1),.WIDTH(2)) sw_mmr_t();
mmr_trigger_interface #(.N(1),.WIDTH(2)) mmr_t();
if (ENABLE_RX_SW_MMR_T) begin
	mmr_trigger_interface_connect mmr_trigger_interface_connect_0(.m(mmr_t),.s(sw_mmr_t));
end
else begin
	mmr_trigger_interface_connect mmr_trigger_interface_connect_0(.m(mmr_t),.s(hw_mmr_t));
end

/*
 * Select HW or SW mmr_i.
 */
mmr_intr_interface #(.N(1),.WIDTH(2)) hw_mmr_i();
mmr_intr_interface #(.N(1),.WIDTH(2)) sw_mmr_i();
mmr_intr_interface #(.N(1),.WIDTH(2)) mmr_i();
if (ENABLE_RX_SW_MMR_I) begin
	mmr_intr_interface_connect mmr_intr_interface_connect_0(.m(mmr_i),.s(sw_mmr_i));
end
else begin
	mmr_intr_interface_connect mmr_intr_interface_connect_0(.m(mmr_i),.s(hw_mmr_i));
end

assign channel_irq = mmr_i.interrupts[0];
wire logic rx_enable;

axi_lite_mmr #(
	.IBRAM_SIZE(IBRAM_SIZE),
	.DBRAM_SIZE(DBRAM_SIZE),
	.DATA_FIFO_SIZE(RX_DATA_FIFO_SIZE),
	.DATA_FIFO_WIDTH(RX_DATA_FIFO_WIDTH),
	.INSTANCE(INSTANCE)
)
axi_lite_mmr_inst(
	.clock(clock),
	.reset_n(resetn),

	.axi_aw(s_axil_aw),
	.axi_w(s_axil_w),
	.axi_b(s_axil_b),
	.axi_ar(s_axil_ar),
	.axi_r(s_axil_r),

	.mmr_rw(mmr_rw),
	.mmr_r(mmr_r),
	.mmr_t(mmr_t),
	.mmr_i(mmr_i),

	.cpu_reset(cpu_reset),
	.enable(rx_enable),
	.dma_desc_base,
	.io_axi_axcache,
	.dma_axi_axcache,

	.instruction_bram_mmr(instruction_bram_mmr),
	.data_bram_mmr(data_bram_mmr)
);

// This is currently redundant.
// But we might need it later in a transitional phase when both constants
// are made independent of each other.
if (RX_DATA_FIFO_WIDTH != 0) begin
	if (m_axi_dma_w.AXI_WDATA_WIDTH != RX_DATA_FIFO_WIDTH) begin
		$error("We don't support m_axi_dma_w.AXI_WDATA_WIDTH != RX_DATA_FIFO_WIDTH)");
	end
	if (RX_DATA_FIFO_WIDTH < 32) begin
		$error("We don't support a RX DATA FIFO width of less than 32.");
	end
end

fifo_read_interface #(
	.DATA_WIDTH(RX_PUZZLE_FIFO_R_DATA_WIDTH[0]),
	.DATA_COUNT_WIDTH(RX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH[0])
) puzzle_hw_fifo_r_0();
fifo_read_interface #(
	.DATA_WIDTH(RX_PUZZLE_FIFO_R_DATA_WIDTH[1]),
	.DATA_COUNT_WIDTH(RX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH[1])
) puzzle_hw_fifo_r_1();
fifo_read_interface #(
	.DATA_WIDTH(RX_PUZZLE_FIFO_R_DATA_WIDTH[2]),
	.DATA_COUNT_WIDTH(RX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH[2])
) puzzle_hw_fifo_r_2();
fifo_read_interface #(
	.DATA_WIDTH(RX_PUZZLE_FIFO_R_DATA_WIDTH[3]),
	.DATA_COUNT_WIDTH(RX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH[3])
) puzzle_hw_fifo_r_3();

fifo_write_interface #(
	.DATA_WIDTH(RX_PUZZLE_FIFO_W_DATA_WIDTH[0]),
	.DATA_COUNT_WIDTH(RX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH[0])
) puzzle_hw_fifo_w_0();
fifo_write_interface #(
	.DATA_WIDTH(RX_PUZZLE_FIFO_W_DATA_WIDTH[1]),
	.DATA_COUNT_WIDTH(RX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH[1])
) puzzle_hw_fifo_w_1();
fifo_write_interface #(
	.DATA_WIDTH(RX_PUZZLE_FIFO_W_DATA_WIDTH[2]),
	.DATA_COUNT_WIDTH(RX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH[2])
) puzzle_hw_fifo_w_2();
fifo_write_interface #(
	.DATA_WIDTH(RX_PUZZLE_FIFO_W_DATA_WIDTH[3]),
	.DATA_COUNT_WIDTH(RX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH[3])
) puzzle_hw_fifo_w_3();

fifo_read_interface #(
	.DATA_WIDTH(RX_PUZZLE_FIFO_R_DATA_WIDTH[0]),
	.DATA_COUNT_WIDTH(RX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH[0])
) puzzle_sw_fifo_r_0();
fifo_read_interface #(
	.DATA_WIDTH(RX_PUZZLE_FIFO_R_DATA_WIDTH[1]),
	.DATA_COUNT_WIDTH(RX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH[1])
) puzzle_sw_fifo_r_1();
fifo_read_interface #(
	.DATA_WIDTH(RX_PUZZLE_FIFO_R_DATA_WIDTH[2]),
	.DATA_COUNT_WIDTH(RX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH[2])
) puzzle_sw_fifo_r_2();
fifo_read_interface #(
	.DATA_WIDTH(RX_PUZZLE_FIFO_R_DATA_WIDTH[3]),
	.DATA_COUNT_WIDTH(RX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH[3])
) puzzle_sw_fifo_r_3();

fifo_write_interface #(
	.DATA_WIDTH(RX_PUZZLE_FIFO_W_DATA_WIDTH[0]),
	.DATA_COUNT_WIDTH(RX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH[0])
) puzzle_sw_fifo_w_0();
fifo_write_interface #(
	.DATA_WIDTH(RX_PUZZLE_FIFO_W_DATA_WIDTH[1]),
	.DATA_COUNT_WIDTH(RX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH[1])
) puzzle_sw_fifo_w_1();
fifo_write_interface #(
	.DATA_WIDTH(RX_PUZZLE_FIFO_W_DATA_WIDTH[2]),
	.DATA_COUNT_WIDTH(RX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH[2])
) puzzle_sw_fifo_w_2();
fifo_write_interface #(
	.DATA_WIDTH(RX_PUZZLE_FIFO_W_DATA_WIDTH[3]),
	.DATA_COUNT_WIDTH(RX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH[3])
) puzzle_sw_fifo_w_3();

fifo_read_interface #(
	.DATA_WIDTH(RX_PUZZLE_FIFO_R_DATA_WIDTH[0]),
	.DATA_COUNT_WIDTH(RX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH[0])
) puzzle_fifo_r_0();
fifo_read_interface #(
	.DATA_WIDTH(RX_PUZZLE_FIFO_R_DATA_WIDTH[1]),
	.DATA_COUNT_WIDTH(RX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH[1])
) puzzle_fifo_r_1();
fifo_read_interface #(
	.DATA_WIDTH(RX_PUZZLE_FIFO_R_DATA_WIDTH[2]),
	.DATA_COUNT_WIDTH(RX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH[2])
) puzzle_fifo_r_2();
fifo_read_interface #(
	.DATA_WIDTH(RX_PUZZLE_FIFO_R_DATA_WIDTH[3]),
	.DATA_COUNT_WIDTH(RX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH[3])
) puzzle_fifo_r_3();

fifo_write_interface #(
	.DATA_WIDTH(RX_PUZZLE_FIFO_W_DATA_WIDTH[0]),
	.DATA_COUNT_WIDTH(RX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH[0])
) puzzle_fifo_w_0();
fifo_write_interface #(
	.DATA_WIDTH(RX_PUZZLE_FIFO_W_DATA_WIDTH[1]),
	.DATA_COUNT_WIDTH(RX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH[1])
) puzzle_fifo_w_1();
fifo_write_interface #(
	.DATA_WIDTH(RX_PUZZLE_FIFO_W_DATA_WIDTH[2]),
	.DATA_COUNT_WIDTH(RX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH[2])
) puzzle_fifo_w_2();
fifo_write_interface #(
	.DATA_WIDTH(RX_PUZZLE_FIFO_W_DATA_WIDTH[3]),
	.DATA_COUNT_WIDTH(RX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH[3])
) puzzle_fifo_w_3();

/*
 * Interface used by the HW RX unit to read descriptors from the
 * RX meta FIFO.
 */
fifo_read_interface #(
	.DATA_WIDTH(RX_META_FIFO_WIDTH),
	.DATA_COUNT_WIDTH(RX_META_FIFO_DATA_COUNT_WIDTH)
) hw_rx_meta_fifo_r();
/*
 * Interface used by the SW RX unit to read descriptors from the
 * RX meta FIFO.
 */
fifo_read_interface #(
	.DATA_WIDTH(RX_META_FIFO_WIDTH),
	.DATA_COUNT_WIDTH(RX_META_FIFO_DATA_COUNT_WIDTH)
) sw_rx_meta_fifo_r();
/*
 * Interface used to read descriptors from the RX meta FIFO.
 */
fifo_read_interface #(
	.DATA_WIDTH(RX_META_FIFO_WIDTH),
	.DATA_COUNT_WIDTH(RX_META_FIFO_DATA_COUNT_WIDTH)
) rx_meta_fifo_r();

if (ENABLE_RX_SW_RX_META_FIFO_R) begin
	fifo_read_interface_connect(.m(rx_meta_fifo_r), .s(sw_rx_meta_fifo_r));
end
else begin
	fifo_read_interface_connect(.m(rx_meta_fifo_r), .s(hw_rx_meta_fifo_r));
end

/*
 * Interface used by the HW RX unit to start writing data from the
 * RX data FIFO to RAM.
 */
memory_write_interface #(
	.DATA_WIDTH(RX_DATA_FIFO_WIDTH),
	.ADDR_WIDTH(SYSTEM_ADDR_WIDTH)
) hw_rx_data_mem_w();
/*
 * Interface used by the SW RX unit to start writing data from the
 * RX data FIFO to RAM.
 */
memory_write_interface #(
	.DATA_WIDTH(RX_DATA_FIFO_WIDTH),
	.ADDR_WIDTH(SYSTEM_ADDR_WIDTH)
) sw_rx_data_mem_w();
/*
 * Interface used to start writing data from the RX data FIFO to RAM.
 */
memory_write_interface #(
	.DATA_WIDTH(RX_DATA_FIFO_WIDTH),
	.ADDR_WIDTH(SYSTEM_ADDR_WIDTH)
) rx_data_mem_w();

if (ENABLE_RX_SW_RX_DATA_MEM_W) begin
	memory_write_interface_connect(.m(rx_data_mem_w), .s(sw_rx_data_mem_w));
end
else begin
	memory_write_interface_connect(.m(rx_data_mem_w), .s(hw_rx_data_mem_w));
end

prism_sp_puzzle_fifo_mixer #(
	.NFIFOS(NRXPUZZLEFIFOS),
	.ENABLE_PUZZLE_FIFO_R(ENABLE_RX_PUZZLE_SW_FIFO_R),
	.ENABLE_PUZZLE_FIFO_W(ENABLE_RX_PUZZLE_SW_FIFO_W)
) prism_sp_puzzle_fifo_mixer_0 (
	.clock,
	.resetn,

	.puzzle_hw_fifo_r_0,
	.puzzle_hw_fifo_w_0,
	.puzzle_hw_fifo_r_1,
	.puzzle_hw_fifo_w_1,
	.puzzle_hw_fifo_r_2,
	.puzzle_hw_fifo_w_2,
	.puzzle_hw_fifo_r_3,
	.puzzle_hw_fifo_w_3,

	.puzzle_sw_fifo_r_0,
	.puzzle_sw_fifo_w_0,
	.puzzle_sw_fifo_r_1,
	.puzzle_sw_fifo_w_1,
	.puzzle_sw_fifo_r_2,
	.puzzle_sw_fifo_w_2,
	.puzzle_sw_fifo_r_3,
	.puzzle_sw_fifo_w_3,

	.puzzle_fifo_r_0,
	.puzzle_fifo_w_0,
	.puzzle_fifo_r_1,
	.puzzle_fifo_w_1,
	.puzzle_fifo_r_2,
	.puzzle_fifo_w_2,
	.puzzle_fifo_r_3,
	.puzzle_fifo_w_3
);

prism_sp_rx_puzzle_hw
prism_sp_rx_puzzle_hw_0 (
	.clock,
	.resetn,

	.rx_enable,
	.dma_desc_base,

	.mmr_i(hw_mmr_i),
	.mmr_t(hw_mmr_t),

	.fifo_r_0(puzzle_hw_fifo_r_0),
	.fifo_w_0(puzzle_hw_fifo_w_0),
	.fifo_r_1(puzzle_hw_fifo_r_1),
	.fifo_w_1(puzzle_hw_fifo_w_1),
	.fifo_r_2(puzzle_hw_fifo_r_2),
	.fifo_w_2(puzzle_hw_fifo_w_2),
	.fifo_r_3(puzzle_hw_fifo_r_3),
	.fifo_w_3(puzzle_hw_fifo_w_3),

	// Interfaces used by the RX unit
	.rx_data_mem_w(hw_rx_data_mem_w),
	.rx_meta_fifo_r(hw_rx_meta_fifo_r),

	.axi_ma_aw(m_axi_ma_aw),
	.axi_ma_w(m_axi_ma_w),
	.axi_ma_b(m_axi_ma_b),
	.axi_ma_ar(m_axi_ma_ar),
	.axi_ma_r(m_axi_ma_r),

	.axi_mb_aw(m_axi_mb_aw),
	.axi_mb_w(m_axi_mb_w),
	.axi_mb_b(m_axi_mb_b),
	.axi_mb_ar(m_axi_mb_ar),
	.axi_mb_r(m_axi_mb_r),

	.axi_sa_aw(s_axi_sa_aw),
	.axi_sa_w(s_axi_sa_w),
	.axi_sa_b(s_axi_sa_b),
	.axi_sa_ar(s_axi_sa_ar),
	.axi_sa_r(s_axi_sa_r),

	.axi_sb_aw(s_axi_sb_aw),
	.axi_sb_w(s_axi_sb_w),
	.axi_sb_b(s_axi_sb_b),
	.axi_sb_ar(s_axi_sb_ar),
	.axi_sb_r(s_axi_sb_r)
);

prism_sp_puzzle_fifos #(
	.NFIFOS(NRXPUZZLEFIFOS),
	.FIFO_WRITE_DEPTH(RX_PUZZLE_FIFO_WRITE_DEPTH)
) prism_sp_puzzle_fifos_0 (
	.clock,
	.resetn,

	.fifo_r_0(puzzle_fifo_r_0),
	.fifo_w_0(puzzle_fifo_w_0),
	.fifo_r_1(puzzle_fifo_r_1),
	.fifo_w_1(puzzle_fifo_w_1),
	.fifo_r_2(puzzle_fifo_r_2),
	.fifo_w_2(puzzle_fifo_w_2),
	.fifo_r_3(puzzle_fifo_r_3),
	.fifo_w_3(puzzle_fifo_w_3)
);

assign trace_rx_puzzle.rx_enable = rx_enable;
assign trace_rx_puzzle.rx_trigger = mmr_t.tsr[0][0];

assign trace_rx_puzzle.puzzle_fifo_r_0_empty = puzzle_fifo_r_0.empty;
assign trace_rx_puzzle.puzzle_fifo_r_0_rd_en = puzzle_fifo_r_0.rd_en;
assign trace_rx_puzzle.puzzle_fifo_r_0_rd_data = puzzle_fifo_r_0.rd_data;
assign trace_rx_puzzle.puzzle_fifo_r_0_rd_data_count = puzzle_fifo_r_0.rd_data_count;

assign trace_rx_puzzle.puzzle_fifo_r_1_empty = puzzle_fifo_r_1.empty;
assign trace_rx_puzzle.puzzle_fifo_r_1_rd_en = puzzle_fifo_r_1.rd_en;
assign trace_rx_puzzle.puzzle_fifo_r_1_rd_data = puzzle_fifo_r_1.rd_data;
assign trace_rx_puzzle.puzzle_fifo_r_1_rd_data_count = puzzle_fifo_r_1.rd_data_count;

assign trace_rx_puzzle.puzzle_fifo_r_2_empty = puzzle_fifo_r_2.empty;
assign trace_rx_puzzle.puzzle_fifo_r_2_rd_en = puzzle_fifo_r_2.rd_en;
assign trace_rx_puzzle.puzzle_fifo_r_2_rd_data = puzzle_fifo_r_2.rd_data;
assign trace_rx_puzzle.puzzle_fifo_r_2_rd_data_count = puzzle_fifo_r_2.rd_data_count;

assign trace_rx_puzzle.puzzle_fifo_r_3_empty = puzzle_fifo_r_3.empty;
assign trace_rx_puzzle.puzzle_fifo_r_3_rd_en = puzzle_fifo_r_3.rd_en;
assign trace_rx_puzzle.puzzle_fifo_r_3_rd_data = puzzle_fifo_r_3.rd_data;
assign trace_rx_puzzle.puzzle_fifo_r_3_rd_data_count = puzzle_fifo_r_3.rd_data_count;

assign trace_rx_puzzle.puzzle_fifo_w_0_full = puzzle_fifo_w_0.full;
assign trace_rx_puzzle.puzzle_fifo_w_0_wr_en = puzzle_fifo_w_0.wr_en;
assign trace_rx_puzzle.puzzle_fifo_w_0_wr_data = puzzle_fifo_w_0.wr_data;
assign trace_rx_puzzle.puzzle_fifo_w_0_wr_data_count = puzzle_fifo_w_0.wr_data_count;

assign trace_rx_puzzle.puzzle_fifo_w_1_full = puzzle_fifo_w_1.full;
assign trace_rx_puzzle.puzzle_fifo_w_1_wr_en = puzzle_fifo_w_1.wr_en;
assign trace_rx_puzzle.puzzle_fifo_w_1_wr_data = puzzle_fifo_w_1.wr_data;
assign trace_rx_puzzle.puzzle_fifo_w_1_wr_data_count = puzzle_fifo_w_1.wr_data_count;

assign trace_rx_puzzle.puzzle_fifo_w_2_full = puzzle_fifo_w_2.full;
assign trace_rx_puzzle.puzzle_fifo_w_2_wr_en = puzzle_fifo_w_2.wr_en;
assign trace_rx_puzzle.puzzle_fifo_w_2_wr_data = puzzle_fifo_w_2.wr_data;
assign trace_rx_puzzle.puzzle_fifo_w_2_wr_data_count = puzzle_fifo_w_2.wr_data_count;

assign trace_rx_puzzle.puzzle_fifo_w_3_full = puzzle_fifo_w_3.full;
assign trace_rx_puzzle.puzzle_fifo_w_3_wr_en = puzzle_fifo_w_3.wr_en;
assign trace_rx_puzzle.puzzle_fifo_w_3_wr_data = puzzle_fifo_w_3.wr_data;
assign trace_rx_puzzle.puzzle_fifo_w_3_wr_data_count = puzzle_fifo_w_3.wr_data_count;

if (ENABLE_RX_RISCV_PROCESSOR) begin
	fifo_write_interface #(
		.DATA_WIDTH(0),
		.DATA_COUNT_WIDTH(0)
	) dummy_tx_data_fifo_w();
	memory_read_interface #(
		.DATA_WIDTH(0),
		.ADDR_WIDTH(0)
	) dummy_tx_data_mem_r();
	fifo_write_interface #(
		.DATA_WIDTH(0),
		.DATA_COUNT_WIDTH(0)
	) dummy_tx_meta_fifo_w();

	prism_sp_processor #(
		.IBRAM_SIZE(IBRAM_SIZE),
		.DBRAM_SIZE(DBRAM_SIZE),
		.ACPBRAM_SIZE(ACPBRAM_SIZE),
		.USE_SP_UNIT_RX(1),
		.USE_SP_UNIT_TX(0),
		.NPUZZLEFIFOS(NRXPUZZLEFIFOS)
	) prism_sp_processor_0(
		.clock,
		.resetn,
		.cpu_reset,

		.io_axi_axcache,
		.m_axi_io(m_axi_mx),
		.instruction_bram_mmr,
		.data_bram_mmr,

		.puzzle_sw_fifo_r_0,
		.puzzle_sw_fifo_w_0,
		.puzzle_sw_fifo_r_1,
		.puzzle_sw_fifo_w_1,
		.puzzle_sw_fifo_r_2,
		.puzzle_sw_fifo_w_2,
		.puzzle_sw_fifo_r_3,
		.puzzle_sw_fifo_w_3,

		// Interfaces used by the RX unit
		.rx_data_mem_w(sw_rx_data_mem_w),
		.rx_meta_fifo_r(sw_rx_meta_fifo_r),
		// Interfaces used by the TX unit
		.tx_data_fifo_w(dummy_tx_data_fifo_w),
		.tx_data_mem_r(dummy_tx_data_mem_r),
		.tx_meta_fifo_w(dummy_tx_meta_fifo_w),

		// Interfaces used by the common unit
		.mmr_rw,
		.mmr_r,
		.mmr_i(sw_mmr_i),
		.mmr_t(hw_mmr_t),

		// Interfaces used by the ACP unit
		.m_axi_acp_aw,
		.m_axi_acp_w,
		.m_axi_acp_b,
		.m_axi_acp_ar,
		.m_axi_acp_r,

		.trace_proc,
		.trace_sp_unit,
		.trace_sp_unit_rx
	);
end // ENABLE_RX_RISCV_PROCESSOR

/*
 * --------  --------  --------  --------
 * Clock Domain Crossing
 * --------  --------  --------  --------
 */
`ifdef VERILATOR
`else
xpm_fifo_async #(
	.CDC_SYNC_STAGES(2),
	.DOUT_RESET_VALUE("0"),
	.ECC_MODE("no_ecc"),
	.FIFO_MEMORY_TYPE("auto"),
	.FIFO_READ_LATENCY(0),
	.FIFO_WRITE_DEPTH(RX_META_FIFO_DEPTH),
	.FULL_RESET_VALUE(0),
	.PROG_EMPTY_THRESH(10),
	.PROG_FULL_THRESH(10),
	// Processor clock domain
	.RD_DATA_COUNT_WIDTH(rx_meta_fifo_r.DATA_COUNT_WIDTH),
	.READ_DATA_WIDTH(rx_meta_fifo_r.DATA_WIDTH),
	.READ_MODE("fwft"),
	.RELATED_CLOCKS(0),
	.SIM_ASSERT_CHK(0),
	.USE_ADV_FEATURES("0707"),
	.WAKEUP_TIME(0),
	// GEM RX clock domain
	//.WR_DATA_COUNT_WIDTH(rx_meta_fifo_w.DATA_COUNT_WIDTH),
	.WR_DATA_COUNT_WIDTH(1),
	.WRITE_DATA_WIDTH(rx_meta_fifo_w.DATA_WIDTH)
) rx_meta_fifo (
	// reset is synchronized to wr_clk!
	.rst(rx_meta_fifo_w.reset),

	.rd_clk(clock),
	.rd_en(rx_meta_fifo_r.rd_en),
	.dout(rx_meta_fifo_r.rd_data),
	.empty(rx_meta_fifo_r.empty),
	.rd_data_count(rx_meta_fifo_r.rd_data_count),

	.wr_clk(rx_meta_fifo_w.clock),
	.wr_en(rx_meta_fifo_w.wr_en),
	.din(rx_meta_fifo_w.wr_data),
	.full(rx_meta_fifo_w.full),
	.wr_data_count(rx_meta_fifo_w.wr_data_count)

	// for future reference:
	//
	//.almost_empty(almost_empty),
	//.almost_full(almost_full),
	//.data_valid(data_valid),
	//.dbiterr(dbiterr),
	//.overflow(overflow),
	//.prog_empty(prog_empty),
	//.prog_full(prog_full),
	//.rd_rst_busy(rd_rst_busy),
	//.sbiterr(sbiterr),
	//.underflow(underflow),
	//.wr_ack(wr_ack),
	//.wr_rst_busy(wr_rst_busy),
	//.injectdbiterr(injectdbiterr),
	//.injectsbiterr(injectsbiterr),
	//.sleep(sleep),
);

assign trace_rx_fifo.meta_fifo_r_empty = rx_meta_fifo_r.empty;
assign trace_rx_fifo.meta_fifo_r_rd_en = rx_meta_fifo_r.rd_en;
assign trace_rx_fifo.meta_fifo_r_rd_data = rx_meta_fifo_r.rd_data;
assign trace_rx_fifo.meta_fifo_r_rd_data_count = rx_meta_fifo_r.rd_data_count;

assign trace_rx_fifo.meta_fifo_w_full = rx_meta_fifo_w.full;
assign trace_rx_fifo.meta_fifo_w_wr_en = rx_meta_fifo_w.wr_en;
assign trace_rx_fifo.meta_fifo_w_wr_data = rx_meta_fifo_w.wr_data;
assign trace_rx_fifo.meta_fifo_w_wr_data_count = rx_meta_fifo_w.wr_data_count;

/*
 * Interface to connect the RX data FIFO with the FIFO-to-AXI module.
 */
fifo_read_interface #(
	.DATA_WIDTH(RX_DATA_FIFO_WIDTH),
	.DATA_COUNT_WIDTH(RX_DATA_FIFO_DATA_COUNT_WIDTH)
) rx_data_fifo_r();

xpm_fifo_async #(
	.CDC_SYNC_STAGES(2),
	.DOUT_RESET_VALUE("0"),
	.ECC_MODE("no_ecc"),
	.FIFO_MEMORY_TYPE("auto"),
	.FIFO_READ_LATENCY(0),
	.FIFO_WRITE_DEPTH(RX_DATA_FIFO_DEPTH),
	.FULL_RESET_VALUE(0),
	.PROG_EMPTY_THRESH(10),
	.PROG_FULL_THRESH(10),
	// Processor clock domain
	.RD_DATA_COUNT_WIDTH(rx_data_fifo_r.DATA_COUNT_WIDTH),
	.READ_DATA_WIDTH(RX_DATA_FIFO_WIDTH),
	.READ_MODE("fwft"),
	.RELATED_CLOCKS(0),
	.SIM_ASSERT_CHK(0),
	.USE_ADV_FEATURES("0707"),
	.WAKEUP_TIME(0),
	// GEM RX clock domain
	//.WR_DATA_COUNT_WIDTH(1),
	.WR_DATA_COUNT_WIDTH(rx_data_fifo_w.DATA_COUNT_WIDTH),
	.WRITE_DATA_WIDTH(RX_DATA_FIFO_WIDTH)
) rx_data_fifo (
	// reset is synchronized to wr_clk!
	.rst(rx_data_fifo_w.reset),

	.rd_clk(clock),
	.rd_en(rx_data_fifo_r.rd_en),
	.dout(rx_data_fifo_r.rd_data),
	.rd_data_count(rx_data_fifo_r.rd_data_count),

	.wr_clk(rx_data_fifo_w.clock),
	.wr_en(rx_data_fifo_w.wr_en),
	.din(rx_data_fifo_w.wr_data),
	.wr_data_count(rx_data_fifo_w.wr_data_count)
);
`endif

fifo_to_axi_v5
fifo_to_axi_0(
	.clock,
	.resetn,
	.mem_w(rx_data_mem_w),
	.fifo_r(rx_data_fifo_r),
	.axi_awcache(dma_axi_awcache),
	.axi_aw(m_axi_dma_aw),
	.axi_w(m_axi_dma_w),
	.axi_b(m_axi_dma_b)
);

endmodule
