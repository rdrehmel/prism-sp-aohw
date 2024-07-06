/*
 * Copyright (c) 2021-2023 Robert Drehmel
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

module prism_sp_tx_core #(
	parameter int IBRAM_SIZE,
	parameter int DBRAM_SIZE,
	parameter int ACPBRAM_SIZE,

	parameter int TX_DATA_FIFO_SIZE = 0,
	parameter int TX_DATA_FIFO_WIDTH = 0,

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

	axi_read_address_channel.master			m_axi_dma_ar,
	axi_read_channel.master					m_axi_dma_r,

	// Driven from the GEM send module
	fifo_read_interface.slave				tx_meta_fifo_r,
	fifo_read_interface.slave				tx_data_fifo_r,
	fifo_read_interface.slave				tx_csum_fifo_r,

	output wire logic channel_irq,

	output trace_outputs_t			trace_proc,
	output trace_sp_unit_t			trace_sp_unit,
	output trace_sp_unit_tx_t		trace_sp_unit_tx,
	output trace_tx_puzzle_t		trace_tx_puzzle,

	output trace_atf_t				trace_atf,
	output trace_atf_bds_t			trace_atf_bds,
	output trace_checksum_t			trace_csum
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
if (ENABLE_TX_SW_MMR_T) begin
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
if (ENABLE_TX_SW_MMR_I) begin
	mmr_intr_interface_connect mmr_intr_interface_connect_0(.m(mmr_i),.s(sw_mmr_i));
end
else begin
	mmr_intr_interface_connect mmr_intr_interface_connect_0(.m(mmr_i),.s(hw_mmr_i));
end

assign channel_irq = mmr_i.interrupts[0];
wire logic tx_enable;

axi_lite_mmr #(
	.IBRAM_SIZE(IBRAM_SIZE),
	.DBRAM_SIZE(DBRAM_SIZE),
	.DATA_FIFO_SIZE(TX_DATA_FIFO_SIZE),
	.DATA_FIFO_WIDTH(TX_DATA_FIFO_WIDTH),
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
	.enable(tx_enable),
	.dma_desc_base,
	.io_axi_axcache,
	.dma_axi_axcache,

	.instruction_bram_mmr,
	.data_bram_mmr
);

// This is currently redundant.
// But we might need it later in a transitional phase when both constants
// are made independent of each other.
if (TX_DATA_FIFO_WIDTH != 0) begin
	if (m_axi_dma_r.AXI_RDATA_WIDTH != TX_DATA_FIFO_WIDTH) begin
		$error("We don't support m_axi_dma_r.AXI_RDATA_WIDTH != TX_DATA_FIFO_WIDTH)");
	end
	if (TX_DATA_FIFO_WIDTH < 32) begin
		$error("We don't support a TX DATA FIFO width of less than 32.");
	end
end

fifo_read_interface #(
	.DATA_WIDTH(TX_PUZZLE_FIFO_R_DATA_WIDTH[0]),
	.DATA_COUNT_WIDTH(TX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH[0])
) puzzle_hw_fifo_r_0();
fifo_read_interface #(
	.DATA_WIDTH(TX_PUZZLE_FIFO_R_DATA_WIDTH[1]),
	.DATA_COUNT_WIDTH(TX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH[1])
) puzzle_hw_fifo_r_1();
fifo_read_interface #(
	.DATA_WIDTH(TX_PUZZLE_FIFO_R_DATA_WIDTH[2]),
	.DATA_COUNT_WIDTH(TX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH[2])
) puzzle_hw_fifo_r_2();
fifo_read_interface #(
	.DATA_WIDTH(TX_PUZZLE_FIFO_R_DATA_WIDTH[3]),
	.DATA_COUNT_WIDTH(TX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH[3])
) puzzle_hw_fifo_r_3();

fifo_write_interface #(
	.DATA_WIDTH(TX_PUZZLE_FIFO_W_DATA_WIDTH[0]),
	.DATA_COUNT_WIDTH(TX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH[0])
) puzzle_hw_fifo_w_0();
fifo_write_interface #(
	.DATA_WIDTH(TX_PUZZLE_FIFO_W_DATA_WIDTH[1]),
	.DATA_COUNT_WIDTH(TX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH[1])
) puzzle_hw_fifo_w_1();
fifo_write_interface #(
	.DATA_WIDTH(TX_PUZZLE_FIFO_W_DATA_WIDTH[2]),
	.DATA_COUNT_WIDTH(TX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH[2])
) puzzle_hw_fifo_w_2();
fifo_write_interface #(
	.DATA_WIDTH(TX_PUZZLE_FIFO_W_DATA_WIDTH[3]),
	.DATA_COUNT_WIDTH(TX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH[3])
) puzzle_hw_fifo_w_3();

fifo_read_interface #(
	.DATA_WIDTH(TX_PUZZLE_FIFO_R_DATA_WIDTH[0]),
	.DATA_COUNT_WIDTH(TX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH[0])
) puzzle_sw_fifo_r_0();
fifo_read_interface #(
	.DATA_WIDTH(TX_PUZZLE_FIFO_R_DATA_WIDTH[1]),
	.DATA_COUNT_WIDTH(TX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH[1])
) puzzle_sw_fifo_r_1();
fifo_read_interface #(
	.DATA_WIDTH(TX_PUZZLE_FIFO_R_DATA_WIDTH[2]),
	.DATA_COUNT_WIDTH(TX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH[2])
) puzzle_sw_fifo_r_2();
fifo_read_interface #(
	.DATA_WIDTH(TX_PUZZLE_FIFO_R_DATA_WIDTH[3]),
	.DATA_COUNT_WIDTH(TX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH[3])
) puzzle_sw_fifo_r_3();

fifo_write_interface #(
	.DATA_WIDTH(TX_PUZZLE_FIFO_W_DATA_WIDTH[0]),
	.DATA_COUNT_WIDTH(TX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH[0])
) puzzle_sw_fifo_w_0();
fifo_write_interface #(
	.DATA_WIDTH(TX_PUZZLE_FIFO_W_DATA_WIDTH[1]),
	.DATA_COUNT_WIDTH(TX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH[1])
) puzzle_sw_fifo_w_1();
fifo_write_interface #(
	.DATA_WIDTH(TX_PUZZLE_FIFO_W_DATA_WIDTH[2]),
	.DATA_COUNT_WIDTH(TX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH[2])
) puzzle_sw_fifo_w_2();
fifo_write_interface #(
	.DATA_WIDTH(TX_PUZZLE_FIFO_W_DATA_WIDTH[3]),
	.DATA_COUNT_WIDTH(TX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH[3])
) puzzle_sw_fifo_w_3();

fifo_read_interface #(
	.DATA_WIDTH(TX_PUZZLE_FIFO_R_DATA_WIDTH[0]),
	.DATA_COUNT_WIDTH(TX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH[0])
) puzzle_fifo_r_0();
fifo_read_interface #(
	.DATA_WIDTH(TX_PUZZLE_FIFO_R_DATA_WIDTH[1]),
	.DATA_COUNT_WIDTH(TX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH[1])
) puzzle_fifo_r_1();
fifo_read_interface #(
	.DATA_WIDTH(TX_PUZZLE_FIFO_R_DATA_WIDTH[2]),
	.DATA_COUNT_WIDTH(TX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH[2])
) puzzle_fifo_r_2();
fifo_read_interface #(
	.DATA_WIDTH(TX_PUZZLE_FIFO_R_DATA_WIDTH[3]),
	.DATA_COUNT_WIDTH(TX_PUZZLE_FIFO_R_DATA_COUNT_WIDTH[3])
) puzzle_fifo_r_3();

fifo_write_interface #(
	.DATA_WIDTH(TX_PUZZLE_FIFO_W_DATA_WIDTH[0]),
	.DATA_COUNT_WIDTH(TX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH[0])
) puzzle_fifo_w_0();
fifo_write_interface #(
	.DATA_WIDTH(TX_PUZZLE_FIFO_W_DATA_WIDTH[1]),
	.DATA_COUNT_WIDTH(TX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH[1])
) puzzle_fifo_w_1();
fifo_write_interface #(
	.DATA_WIDTH(TX_PUZZLE_FIFO_W_DATA_WIDTH[2]),
	.DATA_COUNT_WIDTH(TX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH[2])
) puzzle_fifo_w_2();
fifo_write_interface #(
	.DATA_WIDTH(TX_PUZZLE_FIFO_W_DATA_WIDTH[3]),
	.DATA_COUNT_WIDTH(TX_PUZZLE_FIFO_W_DATA_COUNT_WIDTH[3])
) puzzle_fifo_w_3();

/*
 * Interface used by the HW TX unit to start reading data from RAM
 * to the TX data FIFO.
 */
memory_read_interface #(
	.DATA_WIDTH(TX_DATA_FIFO_WIDTH),
	.ADDR_WIDTH(SYSTEM_ADDR_WIDTH)
) hw_tx_data_mem_r();
/*
 * Interface used by the SW TX unit to start reading data from RAM
 * to the TX data FIFO.
 */
memory_read_interface #(
	.DATA_WIDTH(TX_DATA_FIFO_WIDTH),
	.ADDR_WIDTH(SYSTEM_ADDR_WIDTH)
) sw_tx_data_mem_r();
/*
 * Interface used to start reading data from RAM to the TX data FIFO.
 */
memory_read_interface #(
	.DATA_WIDTH(TX_DATA_FIFO_WIDTH),
	.ADDR_WIDTH(SYSTEM_ADDR_WIDTH)
) tx_data_mem_r();

if (ENABLE_TX_SW_TX_DATA_MEM_R) begin
	memory_read_interface_connect(.m(tx_data_mem_r), .s(sw_tx_data_mem_r));
end
else begin
	memory_read_interface_connect(.m(tx_data_mem_r), .s(hw_tx_data_mem_r));
end

/*
 * Interface used by the HW TX unit to write descriptors to the
 * TX meta FIFO.
 */
fifo_write_interface #(
	.DATA_WIDTH(TX_META_FIFO_WIDTH),
	.DATA_COUNT_WIDTH(TX_META_FIFO_DATA_COUNT_WIDTH)
) hw_tx_meta_fifo_w();
/*
 * Interface used by the SW TX unit to write descriptors to the
 * TX meta FIFO.
 */
fifo_write_interface #(
	.DATA_WIDTH(TX_META_FIFO_WIDTH),
	.DATA_COUNT_WIDTH(TX_META_FIFO_DATA_COUNT_WIDTH)
) sw_tx_meta_fifo_w();
/*
 * Interface used to write descriptors to the TX meta FIFO.
 */
fifo_write_interface #(
	.DATA_WIDTH(TX_META_FIFO_WIDTH),
	.DATA_COUNT_WIDTH(TX_META_FIFO_DATA_COUNT_WIDTH)
) tx_meta_fifo_w();

if (ENABLE_TX_SW_TX_META_FIFO_W) begin
	fifo_write_interface_connect(.m(tx_meta_fifo_w), .s(sw_tx_meta_fifo_w));
end
else begin
	fifo_write_interface_connect(.m(tx_meta_fifo_w), .s(hw_tx_meta_fifo_w));
end

/*
 * Interfaces used by the HW TX unit to write to the TX data FIFO.
 * That's not entirely true. We just need it to get the number of
 * written elements.
 */
fifo_write_interface #(
	.DATA_WIDTH(TX_DATA_FIFO_WIDTH),
	.DATA_COUNT_WIDTH(TX_DATA_FIFO_DATA_COUNT_WIDTH)
) hw_tx_data_fifo_w();
/*
 * Interfaces used by the SW TX unit to write to the TX data FIFO.
 * That's not entirely true. We just need it to get the number of
 * written elements.
 */
fifo_write_interface #(
	.DATA_WIDTH(TX_DATA_FIFO_WIDTH),
	.DATA_COUNT_WIDTH(TX_DATA_FIFO_DATA_COUNT_WIDTH)
) sw_tx_data_fifo_w();
/*
 * Interfaces used to write to the TX data FIFO. That's not entirely
 * true. We just need it to get the number of written elements.
 */
fifo_write_interface #(
	.DATA_WIDTH(TX_DATA_FIFO_WIDTH),
	.DATA_COUNT_WIDTH(TX_DATA_FIFO_DATA_COUNT_WIDTH)
) tx_data_fifo_w();

if (ENABLE_TX_SW_TX_DATA_FIFO_W) begin
	fifo_write_interface_connect(.m(tx_data_fifo_w), .s(sw_tx_data_fifo_w));
end
else begin
	fifo_write_interface_connect(.m(tx_data_fifo_w), .s(hw_tx_data_fifo_w));
end

prism_sp_puzzle_fifo_mixer #(
	.NFIFOS(NTXPUZZLEFIFOS),
	.ENABLE_PUZZLE_FIFO_R(ENABLE_TX_PUZZLE_SW_FIFO_R),
	.ENABLE_PUZZLE_FIFO_W(ENABLE_TX_PUZZLE_SW_FIFO_W)
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

prism_sp_tx_puzzle_hw
prism_sp_tx_puzzle_hw_0 (
	.clock,
	.resetn,

	.tx_enable,
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

	// Interfaces used by the TX unit
	.tx_data_fifo_w(hw_tx_data_fifo_w),
	.tx_data_mem_r(hw_tx_data_mem_r),
	.tx_meta_fifo_w(hw_tx_meta_fifo_w),

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
	.NFIFOS(NTXPUZZLEFIFOS),
	.FIFO_WRITE_DEPTH(TX_PUZZLE_FIFO_WRITE_DEPTH)
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

assign trace_tx_puzzle.tx_enable = tx_enable;
assign trace_tx_puzzle.tx_trigger = mmr_t.tsr[0][0];

assign trace_tx_puzzle.puzzle_fifo_r_0_empty = puzzle_fifo_r_0.empty;
assign trace_tx_puzzle.puzzle_fifo_r_0_rd_en = puzzle_fifo_r_0.rd_en;
assign trace_tx_puzzle.puzzle_fifo_r_0_rd_data = puzzle_fifo_r_0.rd_data;
assign trace_tx_puzzle.puzzle_fifo_r_0_rd_data_count = puzzle_fifo_r_0.rd_data_count;

assign trace_tx_puzzle.puzzle_fifo_r_1_empty = puzzle_fifo_r_1.empty;
assign trace_tx_puzzle.puzzle_fifo_r_1_rd_en = puzzle_fifo_r_1.rd_en;
assign trace_tx_puzzle.puzzle_fifo_r_1_rd_data = puzzle_fifo_r_1.rd_data;
assign trace_tx_puzzle.puzzle_fifo_r_1_rd_data_count = puzzle_fifo_r_1.rd_data_count;

assign trace_tx_puzzle.puzzle_fifo_r_2_empty = puzzle_fifo_r_2.empty;
assign trace_tx_puzzle.puzzle_fifo_r_2_rd_en = puzzle_fifo_r_2.rd_en;
assign trace_tx_puzzle.puzzle_fifo_r_2_rd_data = puzzle_fifo_r_2.rd_data;
assign trace_tx_puzzle.puzzle_fifo_r_2_rd_data_count = puzzle_fifo_r_2.rd_data_count;

assign trace_tx_puzzle.puzzle_fifo_r_3_empty = puzzle_fifo_r_3.empty;
assign trace_tx_puzzle.puzzle_fifo_r_3_rd_en = puzzle_fifo_r_3.rd_en;
assign trace_tx_puzzle.puzzle_fifo_r_3_rd_data = puzzle_fifo_r_3.rd_data;
assign trace_tx_puzzle.puzzle_fifo_r_3_rd_data_count = puzzle_fifo_r_3.rd_data_count;

assign trace_tx_puzzle.puzzle_fifo_w_0_full = puzzle_fifo_w_0.full;
assign trace_tx_puzzle.puzzle_fifo_w_0_wr_en = puzzle_fifo_w_0.wr_en;
assign trace_tx_puzzle.puzzle_fifo_w_0_wr_data = puzzle_fifo_w_0.wr_data;
assign trace_tx_puzzle.puzzle_fifo_w_0_wr_data_count = puzzle_fifo_w_0.wr_data_count;

assign trace_tx_puzzle.puzzle_fifo_w_1_full = puzzle_fifo_w_1.full;
assign trace_tx_puzzle.puzzle_fifo_w_1_wr_en = puzzle_fifo_w_1.wr_en;
assign trace_tx_puzzle.puzzle_fifo_w_1_wr_data = puzzle_fifo_w_1.wr_data;
assign trace_tx_puzzle.puzzle_fifo_w_1_wr_data_count = puzzle_fifo_w_1.wr_data_count;

assign trace_tx_puzzle.puzzle_fifo_w_2_full = puzzle_fifo_w_2.full;
assign trace_tx_puzzle.puzzle_fifo_w_2_wr_en = puzzle_fifo_w_2.wr_en;
assign trace_tx_puzzle.puzzle_fifo_w_2_wr_data = puzzle_fifo_w_2.wr_data;
assign trace_tx_puzzle.puzzle_fifo_w_2_wr_data_count = puzzle_fifo_w_2.wr_data_count;

assign trace_tx_puzzle.puzzle_fifo_w_3_full = puzzle_fifo_w_3.full;
assign trace_tx_puzzle.puzzle_fifo_w_3_wr_en = puzzle_fifo_w_3.wr_en;
assign trace_tx_puzzle.puzzle_fifo_w_3_wr_data = puzzle_fifo_w_3.wr_data;
assign trace_tx_puzzle.puzzle_fifo_w_3_wr_data_count = puzzle_fifo_w_3.wr_data_count;

if (ENABLE_TX_RISCV_PROCESSOR) begin
	memory_write_interface #(
		.DATA_WIDTH(0),
		.ADDR_WIDTH(0)
	) dummy_rx_data_mem_w();
	fifo_read_interface #(
		.DATA_WIDTH(0),
		.DATA_COUNT_WIDTH(0)
	) dummy_rx_meta_fifo_r();

	prism_sp_processor #(
		.IBRAM_SIZE(IBRAM_SIZE),
		.DBRAM_SIZE(DBRAM_SIZE),
		.ACPBRAM_SIZE(ACPBRAM_SIZE),
		.USE_SP_UNIT_RX(0),
		.USE_SP_UNIT_TX(1),
		.NPUZZLEFIFOS(NTXPUZZLEFIFOS)
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
		.rx_data_mem_w(dummy_rx_data_mem_w),
		.rx_meta_fifo_r(dummy_rx_meta_fifo_r),
		// Interfaces used by the TX unit
		.tx_data_fifo_w(sw_tx_data_fifo_w),
		.tx_data_mem_r(sw_tx_data_mem_r),
		.tx_meta_fifo_w(sw_tx_meta_fifo_w),

		// Interfaces used by the common unit
		.mmr_rw,
		.mmr_r,
		.mmr_t(sw_mmr_t),
		.mmr_i(sw_mmr_i),

		// Interfaces used by the ACP unit
		.m_axi_acp_aw,
		.m_axi_acp_w,
		.m_axi_acp_b,
		.m_axi_acp_ar,
		.m_axi_acp_r,

		.trace_proc,
		.trace_sp_unit,
		.trace_sp_unit_tx
	);
end // ENABLE_TX_RISCV_PROCESSOR

/*
 * --------  --------  --------  --------
 * Clock Domain Crossing
 * --------  --------  --------  --------
 */
/*
 * From the manual:
 *
 * USE_ADV_FEATURES[0]=1 enables overflow flag; Default value of this bit is 1
 * USE_ADV_FEATURES[1]=1 enables prog_full flag; Default value of this bit is 1
 * USE_ADV_FEATURES[2]=1 enables wr_data_count; Default value of this bit is 1
 * USE_ADV_FEATURES[3]=1 enables almost_full flag; Default value of this bit is 0
 * USE_ADV_FEATURES[4]=1 enables wr_ack flag; Default value of this bit is 0
 * USE_ADV_FEATURES[8]=1 enables underflow flag; Default value of this bit is 1
 * USE_ADV_FEATURES[9]=1 enables prog_empty flag; Default value of this bit is 1
 * USE_ADV_FEATURES[10]=1 enables rd_data_count; Default value of this bit is 1
 * USE_ADV_FEATURES[11]=1 enables almost_empty flag; Default value of this bit is 0
 * USE_ADV_FEATURES[12]=1 enables data_valid flag; Default value of this bit is 0
 */
`ifdef VERILATOR
`else
/*
 * TX meta FIFO adv. features:
 * overflow			0
 * prog_full		0
 * wr_data_count	1
 * =4
 * almost_full		0
 * wr_ack			0
 * underflow		0
 * =0
 * prog_empty		0
 * rd_data_count	1
 * almost_empty		0
 * =2
 * data_valid		0
 * =0
 * ----
 * =0204
 */
// Make interface
fifo_write_interface #(
	.DATA_WIDTH(TX_CSUM_FIFO_WIDTH),
	// XXX magic numbers
	.DATA_COUNT_WIDTH(1)
) tx_csum_fifo_w();

xpm_fifo_async #(
	.CDC_SYNC_STAGES(2),
	.DOUT_RESET_VALUE("0"),
	.ECC_MODE("no_ecc"),
	.FIFO_MEMORY_TYPE("auto"),
	.FIFO_READ_LATENCY(0),
	.FIFO_WRITE_DEPTH(TX_META_FIFO_DEPTH),
	.FULL_RESET_VALUE(0),
	// GEM TX clock domain
	//.RD_DATA_COUNT_WIDTH(tx_meta_fifo_r.DATA_COUNT_WIDTH),
	.RD_DATA_COUNT_WIDTH(1),
	.READ_DATA_WIDTH(tx_meta_fifo_r.DATA_WIDTH),
	.READ_MODE("fwft"),
	.RELATED_CLOCKS(0),
	.SIM_ASSERT_CHK(0),
	.USE_ADV_FEATURES("0204"),
	.WAKEUP_TIME(0),
	// Processor clock domain
	.WR_DATA_COUNT_WIDTH(tx_meta_fifo_w.DATA_COUNT_WIDTH),
	.WRITE_DATA_WIDTH(tx_meta_fifo_w.DATA_WIDTH)
) tx_meta_fifo (
	// reset is synchronized to wr_clk!
	.rst(~resetn),

	.rd_clk(tx_meta_fifo_r.clock),
	.rd_en(tx_meta_fifo_r.rd_en),
	.dout(tx_meta_fifo_r.rd_data),
	.empty(tx_meta_fifo_r.empty),
	.rd_data_count(tx_meta_fifo_r.rd_data_count), 

	.wr_clk(clock),
	.wr_en(tx_meta_fifo_w.wr_en),
	.din(tx_meta_fifo_w.wr_data),
	.full(tx_meta_fifo_w.full),
	.wr_data_count(tx_meta_fifo_w.wr_data_count)
);

xpm_fifo_async #(
	.CDC_SYNC_STAGES(2),
	.DOUT_RESET_VALUE("0"),
	.ECC_MODE("no_ecc"),
	.FIFO_MEMORY_TYPE("auto"),
	.FIFO_READ_LATENCY(0),
	.FIFO_WRITE_DEPTH(TX_CSUM_FIFO_DEPTH),
	.FULL_RESET_VALUE(0),
	//.RD_DATA_COUNT_WIDTH(tx_csum_fifo_r.DATA_COUNT_WIDTH),
	.RD_DATA_COUNT_WIDTH(1),
	.READ_DATA_WIDTH(tx_csum_fifo_r.DATA_WIDTH),
	.READ_MODE("fwft"),
	.SIM_ASSERT_CHK(0),
	.USE_ADV_FEATURES("0204"),
	.WAKEUP_TIME(0),
	.WR_DATA_COUNT_WIDTH(tx_csum_fifo_w.DATA_COUNT_WIDTH),
	.WRITE_DATA_WIDTH(tx_csum_fifo_w.DATA_WIDTH)
) tx_csum_fifo (
	.rst(~resetn),

	.rd_clk(tx_csum_fifo_r.clock),
	.rd_en(tx_csum_fifo_r.rd_en),
	.dout(tx_csum_fifo_r.rd_data),
	.empty(tx_csum_fifo_r.empty),
	.almost_empty(tx_csum_fifo_r.almost_empty),
	.rd_data_count(tx_csum_fifo_r.rd_data_count),

	.wr_clk(clock),
	.wr_en(tx_csum_fifo_w.wr_en),
	.din(tx_csum_fifo_w.wr_data),
	.full(tx_csum_fifo_w.full),
	.almost_full(tx_csum_fifo_w.almost_full),
	.wr_data_count(tx_csum_fifo_w.wr_data_count)
);

xpm_fifo_async #(
	.CDC_SYNC_STAGES(2),
	.DOUT_RESET_VALUE("0"),
	.ECC_MODE("no_ecc"),
	.FIFO_MEMORY_TYPE("auto"),
	.FIFO_READ_LATENCY(0),
	.FIFO_WRITE_DEPTH(TX_DATA_FIFO_DEPTH),
	.FULL_RESET_VALUE(0),
	// GEM TX clock domain
	//.RD_DATA_COUNT_WIDTH(tx_data_fifo_r.DATA_COUNT_WIDTH),
	.RD_DATA_COUNT_WIDTH(1),
	.READ_DATA_WIDTH(tx_data_fifo_r.DATA_WIDTH),
	.READ_MODE("fwft"),
	.RELATED_CLOCKS(0),
	.SIM_ASSERT_CHK(0),
	.USE_ADV_FEATURES("0204"),
	.WAKEUP_TIME(0),
	// Processor clock domain
	.WR_DATA_COUNT_WIDTH(tx_data_fifo_w.DATA_COUNT_WIDTH),
	.WRITE_DATA_WIDTH(tx_data_fifo_w.DATA_WIDTH)
) tx_data_fifo (
	// reset is synchronized to wr_clk!
	.rst(~resetn),

	.rd_clk(tx_data_fifo_r.clock),
	.rd_en(tx_data_fifo_r.rd_en),
	.dout(tx_data_fifo_r.rd_data),
	.rd_data_count(tx_data_fifo_r.rd_data_count),

	.wr_clk(clock),
	.wr_en(tx_data_fifo_w.wr_en),
	.din(tx_data_fifo_w.wr_data),
	.wr_data_count(tx_data_fifo_w.wr_data_count)
);
`endif

wire logic csum_i_valid;
wire logic [tx_data_fifo_w.DATA_WIDTH-1:0] csum_i_data;
wire logic csum_i_sof;
wire logic csum_i_eof;

prism_sp_tx_checksum #(
	.DATA_WIDTH($bits(csum_i_data))
) prism_sp_tx_checksum_0 (
	.clock,
	.resetn,
	.i_valid(csum_i_valid),
	.i_data(csum_i_data),
	.i_sof(csum_i_sof),
	.i_eof(csum_i_eof),
	.tx_csum_fifo_w,

	.trace_csum
);

wire logic [3:0] dma_axi_arcache;
if (USE_TX_HWCOHERENCY)
	assign dma_axi_arcache[3:2] = 2'b11;
else
	assign dma_axi_arcache[3:2] = 2'b00;
assign dma_axi_arcache[1:0] = 2'b11;

axi_to_fifo_v5#(
	.FIFO_SIZE(TX_DATA_FIFO_SIZE)
) axi_to_fifo_0(
	.clock,
	.resetn,
	.mem_r(tx_data_mem_r),
	.fifo_w(tx_data_fifo_w),

	.ext_valid(csum_i_valid),
	.ext_data(csum_i_data),
	.ext_sof(csum_i_sof),
	.ext_eof(csum_i_eof),

	.axi_arcache(dma_axi_arcache),
	.axi_ar(m_axi_dma_ar),
	.axi_r(m_axi_dma_r),

	.trace_atf,
	.trace_atf_bds
);

endmodule
