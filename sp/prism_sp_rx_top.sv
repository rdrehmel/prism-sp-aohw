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
import prism_sp_config::*;

module prism_sp_rx_top #(
	parameter int IBRAM_SIZE = 2**15,
	parameter int DBRAM_SIZE = 2**15,
	parameter int ACPBRAM_SIZE = 2*64*8,
	parameter int NRXCORES = 1,

	parameter int RX_DATA_FIFO_SIZE,
	parameter int RX_DATA_FIFO_WIDTH
)
(
	input wire logic clock,
	input wire logic resetn,

	output wire logic control_irq,
	output wire logic [NRXCORES-1:0] channel_irqs,

	axi_lite_write_address_channel.slave	s_axil_aw [NRXCORES],
	axi_lite_write_channel.slave			s_axil_w [NRXCORES],
	axi_lite_write_response_channel.slave	s_axil_b [NRXCORES],
	axi_lite_read_address_channel.slave		s_axil_ar [NRXCORES],
	axi_lite_read_channel.slave				s_axil_r [NRXCORES],

	axi_write_address_channel.master		m_axi_ma_aw [NRXCORES],
	axi_write_channel.master				m_axi_ma_w [NRXCORES],
	axi_write_response_channel.master		m_axi_ma_b [NRXCORES],
	axi_read_address_channel.master			m_axi_ma_ar [NRXCORES],
	axi_read_channel.master					m_axi_ma_r [NRXCORES],

	axi_write_address_channel.master		m_axi_mb_aw [NRXCORES],
	axi_write_channel.master				m_axi_mb_w [NRXCORES],
	axi_write_response_channel.master		m_axi_mb_b [NRXCORES],
	axi_read_address_channel.master			m_axi_mb_ar [NRXCORES],
	axi_read_channel.master					m_axi_mb_r [NRXCORES],

	axi_interface.master					m_axi_mx [NRXCORES],

	axi_write_address_channel.slave			s_axi_sa_aw [NRXCORES],
	axi_write_channel.slave					s_axi_sa_w [NRXCORES],
	axi_write_response_channel.slave		s_axi_sa_b [NRXCORES],
	axi_read_address_channel.slave			s_axi_sa_ar [NRXCORES],
	axi_read_channel.slave					s_axi_sa_r [NRXCORES],

	axi_write_address_channel.slave			s_axi_sb_aw [NRXCORES],
	axi_write_channel.slave					s_axi_sb_w [NRXCORES],
	axi_write_response_channel.slave		s_axi_sb_b [NRXCORES],
	axi_read_address_channel.slave			s_axi_sb_ar [NRXCORES],
	axi_read_channel.slave					s_axi_sb_r [NRXCORES],

	axi_write_address_channel.master		m_axi_acp_aw [NRXCORES],
	axi_write_channel.master				m_axi_acp_w [NRXCORES],
	axi_write_response_channel.master		m_axi_acp_b [NRXCORES],
	axi_read_address_channel.master			m_axi_acp_ar [NRXCORES],
	axi_read_channel.master					m_axi_acp_r [NRXCORES],

	axi_write_address_channel.master		m_axi_dma_aw [NRXCORES],
	axi_write_channel.master				m_axi_dma_w [NRXCORES],
	axi_write_response_channel.master		m_axi_dma_b [NRXCORES],

	gem_rx_interface.slave gem_rx,

	output trace_outputs_t					trace_proc [NRXCORES],
	output trace_sp_unit_t					trace_sp_unit [NRXCORES],
	output trace_sp_unit_rx_t				trace_sp_unit_rx [NRXCORES],
	output trace_rx_puzzle_t				trace_rx_puzzle [NRXCORES],
	output trace_rx_fifo_t					trace_rx_fifo [NRXCORES]
);

// This is tied to zero for now.
// Currently, we rely on the GEM device itself to set the default ISR for
// non-RX and non-TX complete IRQs.
assign control_irq = 1'b0;

fifo_write_interface #(
	.DATA_WIDTH(RX_META_FIFO_WIDTH),
	.DATA_COUNT_WIDTH(RX_META_FIFO_DATA_COUNT_WIDTH)
) rx_meta_fifo_w[NRXCORES]();

fifo_write_interface #(
	.DATA_WIDTH(RX_DATA_FIFO_WIDTH),
	.DATA_COUNT_WIDTH(RX_DATA_FIFO_DATA_COUNT_WIDTH)
) rx_data_fifo_w[NRXCORES]();

if (NRXCORES == 1) begin
	prism_sp_gem_rx_single #(
		.NRXCORES(NRXCORES),
		.RX_DATA_FIFO_SIZE(RX_DATA_FIFO_SIZE)
	) prism_sp_gem_rx_0(
		.rx_meta_fifo_w,
		.rx_data_fifo_w,
		.gem_rx
	);
end
else begin
	prism_sp_gem_rx #(
		.NRXCORES(NRXCORES),
		.RX_DATA_FIFO_SIZE(RX_DATA_FIFO_SIZE)
	) prism_sp_gem_rx_0(
		.rx_meta_fifo_w,
		.rx_data_fifo_w,
		.gem_rx
	);
end

generate
for (genvar i = 0; i < NRXCORES; i++) begin
	prism_sp_rx_core #(
		.IBRAM_SIZE(IBRAM_SIZE),
		.DBRAM_SIZE(DBRAM_SIZE),
		.ACPBRAM_SIZE(ACPBRAM_SIZE),
		.RX_DATA_FIFO_SIZE(RX_DATA_FIFO_SIZE),
		.RX_DATA_FIFO_WIDTH(RX_DATA_FIFO_WIDTH),
		.INSTANCE(i)
	) prism_sp_rx_core_0 (
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

		.m_axi_dma_aw(m_axi_dma_aw[i]),
		.m_axi_dma_w(m_axi_dma_w[i]),
		.m_axi_dma_b(m_axi_dma_b[i]),

		.rx_meta_fifo_w(rx_meta_fifo_w[i]),
		.rx_data_fifo_w(rx_data_fifo_w[i]),

		.channel_irq(channel_irqs[i]),

		.trace_proc(trace_proc[i]),
		.trace_sp_unit_rx(trace_sp_unit_rx[i]),
		.trace_rx_puzzle(trace_rx_puzzle[i]),
		.trace_rx_fifo(trace_rx_fifo[i])
	);
end
endgenerate

endmodule
