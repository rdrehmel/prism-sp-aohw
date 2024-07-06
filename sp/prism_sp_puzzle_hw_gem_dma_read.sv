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
module prism_sp_puzzle_hw_gem_dma_read (
	input wire logic clock,
	input wire logic resetn,

	fifo_read_interface.master i_cookie_fifo_r,
	fifo_write_interface.master meta_desc_fifo_w,
	fifo_write_interface.master o_cookie_fifo_w,

	memory_read_interface.master tx_data_mem_r
);

typedef enum logic [1:0] {
	STATE_IDLE,
	STATE_PREBUSY,
	STATE_BUSY,
	STATE_WAIT_FOR_O_COOKIE_FIFO_W_NOT_FULL
} state_t;

var state_t state;

/*
 * Cookie stored in
 * i_cookie_fifo_r.rd_data
 */
wire dma_tx_cookie_t i_tx_cookie = i_cookie_fifo_r.rd_data;

/*
 * Cookie stored in
 * o_cookie_fifo_w.wr_data
 */
var tx_cookie_t o_tx_cookie;
assign o_cookie_fifo_w.wr_data = o_tx_cookie;

var tx_meta_desc_t o_meta_desc;
assign meta_desc_fifo_w.wr_data = o_meta_desc;

var logic [GEM_RX_W_STATUS_FRAME_LENGTH_WIDTH-1:0] packet_length;
var logic start_of_frame;
var logic end_of_frame;
var logic no_crc;

always_ff @(posedge clock) begin
	i_cookie_fifo_r.rd_en <= 1'b0;
	o_cookie_fifo_w.wr_en <= 1'b0;
	meta_desc_fifo_w.wr_en <= 1'b0;
	tx_data_mem_r.start <= 1'b0;

	if (!resetn) begin
		state <= STATE_IDLE;
		packet_length <= '0;
		start_of_frame <= 1'b1;
		end_of_frame <= 1'b0;
	end
	else begin
		case (state)
		STATE_IDLE: begin
			if (!i_cookie_fifo_r.empty) begin
				i_cookie_fifo_r.rd_en <= 1'b1;
				// Copy the cookie from the previous stage.
				o_tx_cookie <= i_tx_cookie;

				if (start_of_frame) begin
					no_crc <= i_tx_cookie.nocrc;
					start_of_frame <= 1'b0;
				end
				end_of_frame <= i_tx_cookie.eof;

				packet_length <= packet_length + i_tx_cookie.size;

				tx_data_mem_r.addr <= i_tx_cookie.data_addr;
				tx_data_mem_r.len <= i_tx_cookie.size;
				tx_data_mem_r.cont <= ~i_tx_cookie.eof;
				tx_data_mem_r.start <= 1'b1;
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
			if (!tx_data_mem_r.busy) begin
				if (end_of_frame) begin
					meta_desc_fifo_w.wr_en <= 1'b1;
					/*
					 * Start of conversion:
					 * i_tx_cookie(s) -> o_meta_desc
					 */
					o_meta_desc.size <= packet_length;
					o_meta_desc.nocrc <= no_crc;
					/*
					 * End of conversion
					 */

					start_of_frame <= 1'b1;
					packet_length <= '0;
				end

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
