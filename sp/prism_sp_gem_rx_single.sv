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
import prism_sp_config::*;

module prism_sp_gem_rx_single#(
	parameter int NRXCORES,
	parameter int RX_DATA_FIFO_SIZE,
	parameter int ENABLE_STATISTICS = 0
)
(
	fifo_write_interface.master rx_meta_fifo_w [NRXCORES],
	fifo_write_interface.master rx_data_fifo_w [NRXCORES],

	gem_rx_interface.slave gem_rx
);

/*
 * --------  --------  --------  --------
 * GEM RX Interface Clock Domain
 * --------  --------  --------  --------
 */
localparam int RX_PACKET_BYTE_COUNT_WIDTH = 13;
var logic [RX_PACKET_BYTE_COUNT_WIDTH-1:0] rx_packet_byte_count_ff;
var logic [RX_PACKET_BYTE_COUNT_WIDTH-1:0] rx_packet_byte_count_comb;

var rx_meta_desc_t o_meta_desc;
assign rx_meta_fifo_w[0].clock = gem_rx.rx_clock;
assign rx_meta_fifo_w[0].reset = ~gem_rx.rx_resetn;
assign rx_meta_fifo_w[0].wr_data = o_meta_desc;
assign rx_data_fifo_w[0].clock = gem_rx.rx_clock;
assign rx_data_fifo_w[0].reset = ~gem_rx.rx_resetn;
assign rx_data_fifo_w[0].wr_data = rx_cur_buf_ff;

if (ENABLE_STATISTICS) begin
var logic [31:0] stats_nmissed_rx_packets;
var logic [31:0] stats_ncompl_rx_packets;

var logic reset_stats = 0'b1;

always_ff @(posedge gem_rx.rx_clock) begin
	if (!gem_rx.rx_resetn || reset_stats) begin
		stats_nmissed_rx_packets <= '0;
	end
	else begin
		if (gem_rx.rx_w_overflow) begin
			stats_nmissed_rx_packets <= stats_nmissed_rx_packets + 1;
		end
	end
end
end

always_comb begin
	rx_packet_byte_count_comb = rx_packet_byte_count_ff;

	if (!gem_rx.rx_resetn) begin
		rx_packet_byte_count_comb = '0;
	end
	else begin
		if (gem_rx.rx_w_sop) begin
			rx_packet_byte_count_comb = '0;
		end
		if (gem_rx.rx_w_wr) begin
			rx_packet_byte_count_comb = rx_packet_byte_count_comb + 1;
		end
	end
end

var logic [31:0] gem_rx_w_status_encoded;

gem_rx_w_status_encoder gem_rx_w_status_encoder_inst(
	.rx_w_status(gem_rx.rx_w_status),
	.frame_length(rx_packet_byte_count_comb),
	.out(gem_rx_w_status_encoded)
);

var logic rx_data_fifo_has_space_ff;
var logic rx_data_fifo_state;
// In number of bytes
var logic [$clog2(RX_DATA_FIFO_SIZE):0] rx_data_fifo_nfree;
var logic [13:0] gem_rx_w_status_13_0;

// This state machine checks whether there is enough space in the FIFO at
//  the start of frame (SOP).
always_ff @(posedge gem_rx.rx_clock) begin
	if (!gem_rx.rx_resetn) begin
		rx_data_fifo_state <= '0;
	end
	else begin
		case (rx_data_fifo_state)
		1'b0: begin
			if (gem_rx.rx_w_sop) begin
				gem_rx_w_status_13_0 <= gem_rx.rx_w_status[13:0];
				rx_data_fifo_nfree <= RX_DATA_FIFO_SIZE - { rx_data_fifo_w[0].wr_data_count, {($clog2(rx_data_fifo_w[0].DATA_WIDTH/8)){1'b0}} };
				rx_data_fifo_state <= 1'b1;
			end
		end
		1'b1: begin
			rx_data_fifo_has_space_ff <= rx_data_fifo_nfree >= gem_rx_w_status_13_0;
			rx_data_fifo_state <= 1'b0;
		end
		endcase
	end
end

var logic [rx_data_fifo_w[0].DATA_WIDTH-1:0] rx_cur_buf_comb;
var logic [rx_data_fifo_w[0].DATA_WIDTH-1:0] rx_cur_buf_ff;
// A bit that is set represents a byte that is not valid.
var logic [(rx_data_fifo_w[0].DATA_WIDTH/8)-1:0] rx_cur_buf_idx;

always_comb begin
	rx_cur_buf_comb = rx_cur_buf_ff;

	if (!gem_rx.rx_resetn) begin
	end
	else begin
		if (gem_rx.rx_w_sop) begin
			rx_cur_buf_comb = '0;
		end
		if (gem_rx.rx_w_wr) begin
			// Reset the buffer for data security/privacy reasons
			if (rx_cur_buf_idx[0]) begin
				rx_cur_buf_comb[rx_data_fifo_w[0].DATA_WIDTH-1:8] = '0;
			end
			// Put the current data into the correct slot.
			for (int i = 0; i < rx_data_fifo_w[0].DATA_WIDTH/8; i++) begin
				if (rx_cur_buf_idx[i]) begin
					rx_cur_buf_comb[i*8 +:8] = gem_rx.rx_w_data[7:0];
				end
			end
		end
	end
end

always_ff @(posedge gem_rx.rx_clock) begin
	rx_cur_buf_ff <= rx_cur_buf_comb;
	rx_packet_byte_count_ff <= rx_packet_byte_count_comb;

	// Unpulse
	rx_meta_fifo_w[0].wr_en <= 1'b0;
	rx_data_fifo_w[0].wr_en <= 1'b0;
	gem_rx.rx_w_overflow <= 1'b0;

	if (!gem_rx.rx_resetn) begin
		rx_cur_buf_idx[0] <= 1'b1;
		rx_cur_buf_idx[(rx_data_fifo_w[0].DATA_WIDTH/8)-1:1] <= '0;
	end
	else begin
		if (gem_rx.rx_w_wr) begin
			rx_cur_buf_idx <= {
				rx_cur_buf_idx[(rx_data_fifo_w[0].DATA_WIDTH/8)-2:0],
				rx_cur_buf_idx[(rx_data_fifo_w[0].DATA_WIDTH/8)-1]
			};
		end
		if (gem_rx.rx_w_eop) begin
			rx_meta_fifo_w[0].wr_en <= rx_data_fifo_has_space_ff;
			o_meta_desc <= gem_rx_w_status_encoded;

			rx_cur_buf_idx[0] <= 1'b1;
			rx_cur_buf_idx[(rx_data_fifo_w[0].DATA_WIDTH/8)-1:1] <= '0;
		end
		// If we have a full rx_buf_cur or this is the last write, store what we have
		// in the RX data FIFO.
		if (gem_rx.rx_w_eop || (gem_rx.rx_w_wr & rx_cur_buf_idx[(rx_data_fifo_w[0].DATA_WIDTH/8)-1])) begin
			rx_data_fifo_w[0].wr_en <= rx_data_fifo_has_space_ff;
			gem_rx.rx_w_overflow <= ~rx_data_fifo_has_space_ff & gem_rx.rx_w_eop;
		end
	end
end
endmodule
