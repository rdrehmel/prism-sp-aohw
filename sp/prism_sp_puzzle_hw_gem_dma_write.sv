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
module prism_sp_puzzle_hw_gem_dma_write (
	input wire logic clock,
	input wire logic resetn,

	fifo_read_interface.master i_cookie_fifo_r,
	fifo_read_interface.master meta_desc_fifo_r,
	fifo_write_interface.master o_cookie_fifo_w,

	memory_write_interface.master rx_data_mem_w
);

typedef enum logic [2:0] {
	STATE_IDLE,
	STATE_HAVE_DMA_DESC,
	STATE_HAVE_META_DESC,
	STATE_PREBUSY,
	STATE_BUSY,
	STATE_WAIT_FOR_O_COOKIE_FIFO_W_NOT_FULL
} state_t;
var state_t state;

/*
 * Cookie stored in
 * i_cookie_fifo_r.rd_data
 */
wire dma_rx_cookie_t i_rx_cookie = i_cookie_fifo_r.rd_data;
wire rx_meta_desc_t i_meta_desc = meta_desc_fifo_r.rd_data;

/*
 * Cookie stored in
 * o_cookie_fifo_w.wr_data
 */
var rx_cookie_t o_rx_cookie;
assign o_cookie_fifo_w.wr_data = o_rx_cookie;

always_ff @(posedge clock) begin
	i_cookie_fifo_r.rd_en <= 1'b0;
	o_cookie_fifo_w.wr_en <= 1'b0;
	meta_desc_fifo_r.rd_en <= 1'b0;
	rx_data_mem_w.start <= 1'b0;

	if (!resetn) begin
		state <= STATE_IDLE;
	end
	else begin
		if ((state == STATE_IDLE || state == STATE_HAVE_META_DESC) &&
			!i_cookie_fifo_r.empty)
		begin
			/*
			 * Start of conversion:
			 * i_rx_cookie -> o_rx_cookie
			 */
			o_rx_cookie.addr <= i_rx_cookie.addr;
			o_rx_cookie.data_addr <= i_rx_cookie.data_addr;
			/*
			 * End of conversion
			 */
			// The ctrl fields will be set below.
			i_cookie_fifo_r.rd_en <= 1'b1;
			rx_data_mem_w.addr <= i_rx_cookie.data_addr;
		end

		if ((state == STATE_IDLE || state == STATE_HAVE_DMA_DESC) &&
			!meta_desc_fifo_r.empty)
		begin
			/*
			 * Start of conversion:
			 * i_meta_desc -> o_rx_cookie
			 */
			o_rx_cookie.w_broadcast_frame <= i_meta_desc.w_broadcast_frame;
			o_rx_cookie.w_mult_hash_match <= i_meta_desc.w_mult_hash_match;
			o_rx_cookie.w_uni_hash_match <= i_meta_desc.w_uni_hash_match;
			o_rx_cookie.w_ext_match <= i_meta_desc.w_ext_match;
			o_rx_cookie.w_add_match <= i_meta_desc.w_add_match;
			o_rx_cookie.add_match <= i_meta_desc.add_match;
			o_rx_cookie.chksum_enc <= i_meta_desc.chksum_enc;
			o_rx_cookie.rx_w_vlan_tagged <= i_meta_desc.rx_w_vlan_tagged;
			o_rx_cookie.rx_w_prty_tagged <= i_meta_desc.rx_w_prty_tagged;
			o_rx_cookie.cfi <= i_meta_desc.cfi;
			o_rx_cookie.eof <= i_meta_desc.eof;
			o_rx_cookie.sof <= i_meta_desc.sof;
			o_rx_cookie.fcs <= i_meta_desc.fcs;
			o_rx_cookie.size <= i_meta_desc.size;
			/*
			 * End of conversion
			 */
			meta_desc_fifo_r.rd_en <= 1'b1;
			rx_data_mem_w.len <= i_meta_desc.size;
		end

		case (state)
		STATE_IDLE: begin
			if (!i_cookie_fifo_r.empty && !meta_desc_fifo_r.empty) begin
				rx_data_mem_w.start <= 1'b1;
				state <= STATE_PREBUSY;
			end
			else if (!i_cookie_fifo_r.empty) begin
				state <= STATE_HAVE_DMA_DESC;
			end
			else if (!meta_desc_fifo_r.empty) begin
				state <= STATE_HAVE_META_DESC;
			end
		end
		STATE_HAVE_DMA_DESC: begin
			if (!meta_desc_fifo_r.empty) begin
				rx_data_mem_w.start <= 1'b1;
				state <= STATE_PREBUSY;
			end
		end
		STATE_HAVE_META_DESC: begin
			if (!i_cookie_fifo_r.empty) begin
				rx_data_mem_w.start <= 1'b1;
				state <= STATE_PREBUSY;
			end
		end
		STATE_PREBUSY: begin
			// We need a one clock cycle delay for
			// rx_data_mem_w.start to be processed
			// by the DMA module.
			state <= STATE_BUSY;
		end
		STATE_BUSY: begin
			if (!rx_data_mem_w.busy) begin
				if (!o_cookie_fifo_w.full) begin
					o_cookie_fifo_w.wr_en <= 1'b1;
					state <= STATE_IDLE;
				end
				else begin
					state <= STATE_WAIT_FOR_O_COOKIE_FIFO_W_NOT_FULL;
				end
			end
		end
		STATE_WAIT_FOR_O_COOKIE_FIFO_W_NOT_FULL: begin
			if (!o_cookie_fifo_w.full) begin
				o_cookie_fifo_w.wr_en <= 1'b1;
				state <= STATE_IDLE;
			end
		end
		endcase
	end
end

endmodule
