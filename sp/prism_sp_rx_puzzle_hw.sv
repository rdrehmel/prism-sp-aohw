/*
 * Copyright (c) 2023-2024 Robert Drehmel
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
module prism_sp_rx_puzzle_hw (
	input wire logic clock,
	input wire logic resetn,

	input wire logic rx_enable,

	mmr_intr_interface.master			mmr_i,
	mmr_trigger_interface.master		mmr_t,

	fifo_read_interface.master			fifo_r_0,
	fifo_write_interface.master			fifo_w_0,
	fifo_read_interface.master			fifo_r_1,
	fifo_write_interface.master			fifo_w_1,
	fifo_read_interface.master			fifo_r_2,
	fifo_write_interface.master			fifo_w_2,
	fifo_read_interface.master			fifo_r_3,
	fifo_write_interface.master			fifo_w_3,

	input wire logic [SYSTEM_ADDR_WIDTH-1:0]	dma_desc_base,

	memory_write_interface.master		rx_data_mem_w,
	fifo_read_interface.master			rx_meta_fifo_r,

	axi_write_address_channel.master	axi_ma_aw,
	axi_write_channel.master			axi_ma_w,
	axi_write_response_channel.master	axi_ma_b,
	axi_read_address_channel.master		axi_ma_ar,
	axi_read_channel.master				axi_ma_r,

	axi_write_address_channel.master	axi_mb_aw,
	axi_write_channel.master			axi_mb_w,
	axi_write_response_channel.master	axi_mb_b,
	axi_read_address_channel.master		axi_mb_ar,
	axi_read_channel.master				axi_mb_r,

	axi_write_address_channel.slave		axi_sa_aw,
	axi_write_channel.slave				axi_sa_w,
	axi_write_response_channel.slave	axi_sa_b,
	axi_read_address_channel.slave		axi_sa_ar,
	axi_read_channel.slave				axi_sa_r,

	axi_write_address_channel.slave		axi_sb_aw,
	axi_write_channel.slave				axi_sb_w,
	axi_write_response_channel.slave	axi_sb_b,
	axi_read_address_channel.slave		axi_sb_ar,
	axi_read_channel.slave				axi_sb_r
);

if (USE_RX_RING_ACQUIRE) begin
prism_sp_ring_acquire_cookie_convert_interface#(
	.DATA_IN_WIDTH(axi_ma_r.AXI_RDATA_WIDTH),
	.DATA_OUT_WIDTH(fifo_w_1.DATA_WIDTH)
) racc();

prism_sp_ring_acquire_cc_gem_dma_rx_desc_2_dma_rx_cookie
prism_sp_ring_acquire_cc_gem_dma_rx_desc_2_dma_rx_cookie_inst(.conv(racc));

prism_sp_puzzle_hw_gem_ring_acquire #(
	.COOKIE_TYPE(rx_cookie_t),
	.DESC_TYPE(gem_dma_rx_desc_t),
	.FIFO_DEPTH(RX_PUZZLE_FIFO_WRITE_DEPTH[0])
) prism_sp_puzzle_hw_gem_ring_acquire_0 (
	.clock,
	.resetn,

	.mmr_t,
	.enable(rx_enable),
	.dma_desc_base,

	.axi_ar(axi_ma_ar),
	.axi_r(axi_ma_r),
	.conv(racc),
	.o_cookie_fifo_w(fifo_w_1)
);
end

prism_sp_puzzle_hw_gem_dma_write
prism_sp_puzzle_hw_gem_dma_write_0 (
	.clock,
	.resetn,

	.i_cookie_fifo_r(fifo_r_1),
	.meta_desc_fifo_r(rx_meta_fifo_r),
	.o_cookie_fifo_w(fifo_w_2),

	.rx_data_mem_w

);

if (USE_RX_RING_RELEASE) begin
prism_sp_puzzle_hw_gem_ring_release #(
	.COOKIE_TYPE(rx_cookie_t),
	.DESC_TYPE(gem_dma_rx_desc_t)
) prism_sp_puzzle_hw_gem_ring_release_0 (
	.clock,
	.resetn,

	.i_cookie_fifo_r(fifo_r_2),

	.axi_aw(axi_ma_aw),
	.axi_w(axi_ma_w),
	.axi_b(axi_ma_b),

	.fifo_w(fifo_w_3)
);
end

if (USE_RX_IRQ) begin
prism_sp_puzzle_hw_gem_irq
prism_sp_puzzle_hw_gem_irq_0 (
	.clock,
	.resetn,

	.fifo_r(fifo_r_3),

	.mmr_i
);
end

endmodule
