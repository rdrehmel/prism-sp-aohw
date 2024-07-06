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
import prism_sp_config::*;

module prism_sp_tx_top #(
	parameter int IBRAM_SIZE = 2**15,
	parameter int DBRAM_SIZE = 2**15,
	parameter int ACPBRAM_SIZE = 2*64*8,
	parameter int NTXCORES = 1,

	parameter int TX_DATA_FIFO_SIZE,
	parameter int TX_DATA_FIFO_WIDTH
)
(
	input wire logic clock,
	input wire logic resetn,

	output wire logic control_irq,
	output wire logic [NTXCORES-1:0] channel_irqs,

	axi_lite_write_address_channel.slave	s_axil_aw [NTXCORES],
	axi_lite_write_channel.slave			s_axil_w [NTXCORES],
	axi_lite_write_response_channel.slave	s_axil_b [NTXCORES],
	axi_lite_read_address_channel.slave		s_axil_ar [NTXCORES],
	axi_lite_read_channel.slave				s_axil_r [NTXCORES],

	axi_write_address_channel.master		m_axi_ma_aw [NTXCORES],
	axi_write_channel.master				m_axi_ma_w [NTXCORES],
	axi_write_response_channel.master		m_axi_ma_b [NTXCORES],
	axi_read_address_channel.master			m_axi_ma_ar [NTXCORES],
	axi_read_channel.master					m_axi_ma_r [NTXCORES],

	axi_write_address_channel.master		m_axi_mb_aw [NTXCORES],
	axi_write_channel.master				m_axi_mb_w [NTXCORES],
	axi_write_response_channel.master		m_axi_mb_b [NTXCORES],
	axi_read_address_channel.master			m_axi_mb_ar [NTXCORES],
	axi_read_channel.master					m_axi_mb_r [NTXCORES],

	axi_interface.master					m_axi_mx [NTXCORES],

	axi_write_address_channel.slave			s_axi_sa_aw [NTXCORES],
	axi_write_channel.slave					s_axi_sa_w [NTXCORES],
	axi_write_response_channel.slave		s_axi_sa_b [NTXCORES],
	axi_read_address_channel.slave			s_axi_sa_ar [NTXCORES],
	axi_read_channel.slave					s_axi_sa_r [NTXCORES],

	axi_write_address_channel.slave			s_axi_sb_aw [NTXCORES],
	axi_write_channel.slave					s_axi_sb_w [NTXCORES],
	axi_write_response_channel.slave		s_axi_sb_b [NTXCORES],
	axi_read_address_channel.slave			s_axi_sb_ar [NTXCORES],
	axi_read_channel.slave					s_axi_sb_r [NTXCORES],

	axi_write_address_channel.master		m_axi_acp_aw [NTXCORES],
	axi_write_channel.master				m_axi_acp_w [NTXCORES],
	axi_write_response_channel.master		m_axi_acp_b [NTXCORES],
	axi_read_address_channel.master			m_axi_acp_ar [NTXCORES],
	axi_read_channel.master					m_axi_acp_r [NTXCORES],

	axi_read_address_channel.master			m_axi_dma_ar [NTXCORES],
	axi_read_channel.master					m_axi_dma_r [NTXCORES],

	gem_tx_interface.master gem_tx,

	output trace_outputs_t			trace_proc [NTXCORES],
	output trace_sp_unit_t			trace_sp_unit [NTXCORES],
	output trace_sp_unit_tx_t		trace_sp_unit_tx [NTXCORES],
	output trace_tx_puzzle_t		trace_tx_puzzle [NTXCORES],

	output trace_atf_t				trace_atf [NTXCORES],
	output trace_atf_bds_t			trace_atf_bds [NTXCORES],
	output trace_checksum_t			trace_csum [NTXCORES]
);

// This is tied to zero for now.
// Currently, we rely on the GEM device itself to set the default ISR for
// non-RX and non-TX complete IRQs.
assign control_irq = 1'b0;

fifo_read_interface #(
	.DATA_WIDTH(TX_META_FIFO_WIDTH),
	.DATA_COUNT_WIDTH(TX_META_FIFO_DATA_COUNT_WIDTH)
) tx_meta_fifo_r[NTXCORES]();

fifo_read_interface #(
	.DATA_WIDTH(TX_DATA_FIFO_WIDTH),
	.DATA_COUNT_WIDTH(TX_DATA_FIFO_DATA_COUNT_WIDTH)
) tx_data_fifo_r[NTXCORES]();

fifo_read_interface #(
	.DATA_WIDTH(TX_CSUM_FIFO_WIDTH),
	.DATA_COUNT_WIDTH(TX_CSUM_FIFO_DATA_COUNT_WIDTH)
) tx_csum_fifo_r[NTXCORES]();

if (NTXCORES == 1) begin
	prism_sp_gem_tx_single #(
		.NTXCORES(NTXCORES)
	) prism_sp_gem_tx_single_0(
		.tx_meta_fifo_r,
		.tx_csum_fifo_r,
		.tx_data_fifo_r,
		.gem_tx
	);
end
else begin
	prism_sp_gem_tx #(
		.NTXCORES(NTXCORES)
	) prism_sp_gem_tx_0(
		.tx_meta_fifo_r,
		.tx_data_fifo_r,

		.gem_tx
	);
end

generate
for (genvar i = 0; i < NTXCORES; i++) begin
	prism_sp_tx_core #(
		.IBRAM_SIZE(IBRAM_SIZE),
		.DBRAM_SIZE(DBRAM_SIZE),
		.ACPBRAM_SIZE(ACPBRAM_SIZE),
		.TX_DATA_FIFO_SIZE(TX_DATA_FIFO_SIZE),
		.TX_DATA_FIFO_WIDTH(TX_DATA_FIFO_WIDTH),
		.INSTANCE(i)
	) prism_sp_tx_core_0(
		.clock(clock),
		.resetn(resetn),

		.s_axil_aw(s_axil_aw[i]),
		.s_axil_w(s_axil_w[i]),
		.s_axil_b(s_axil_b[i]),
		.s_axil_ar(s_axil_ar[i]),
		.s_axil_r(s_axil_r[i]),

		.m_axi_ma_aw(m_axi_ma_aw[i]),
		.m_axi_ma_w(m_axi_ma_w[i]),
		.m_axi_ma_b(m_axi_ma_b[i]),
		.m_axi_ma_ar(m_axi_ma_ar[i]),
		.m_axi_ma_r(m_axi_ma_r[i]),

		.m_axi_mb_aw(m_axi_mb_aw[i]),
		.m_axi_mb_w(m_axi_mb_w[i]),
		.m_axi_mb_b(m_axi_mb_b[i]),
		.m_axi_mb_ar(m_axi_mb_ar[i]),
		.m_axi_mb_r(m_axi_mb_r[i]),

		.m_axi_mx(m_axi_mx[i]),

		.s_axi_sa_aw(s_axi_sa_aw[i]),
		.s_axi_sa_w(s_axi_sa_w[i]),
		.s_axi_sa_b(s_axi_sa_b[i]),
		.s_axi_sa_ar(s_axi_sa_ar[i]),
		.s_axi_sa_r(s_axi_sa_r[i]),

		.s_axi_sb_aw(s_axi_sb_aw[i]),
		.s_axi_sb_w(s_axi_sb_w[i]),
		.s_axi_sb_b(s_axi_sb_b[i]),
		.s_axi_sb_ar(s_axi_sb_ar[i]),
		.s_axi_sb_r(s_axi_sb_r[i]),

		.m_axi_acp_aw(m_axi_acp_aw[i]),
		.m_axi_acp_w(m_axi_acp_w[i]),
		.m_axi_acp_b(m_axi_acp_b[i]),
		.m_axi_acp_ar(m_axi_acp_ar[i]),
		.m_axi_acp_r(m_axi_acp_r[i]),

		.m_axi_dma_ar(m_axi_dma_ar[i]),
		.m_axi_dma_r(m_axi_dma_r[i]),

		.tx_meta_fifo_r(tx_meta_fifo_r[i]),
		.tx_data_fifo_r(tx_data_fifo_r[i]),
		.tx_csum_fifo_r(tx_csum_fifo_r[i]),

		.trace_proc(trace_proc[i]),
		.trace_sp_unit(trace_sp_unit[i]),
		.trace_sp_unit_tx(trace_sp_unit_tx[i]),
		.trace_tx_puzzle(trace_tx_puzzle[i]),

		.trace_atf(trace_atf[i]),
		.trace_atf_bds(trace_atf_bds[i]),
		.trace_csum(trace_csum[i]),

		.channel_irq(channel_irqs[i])
	);
end
endgenerate

endmodule
