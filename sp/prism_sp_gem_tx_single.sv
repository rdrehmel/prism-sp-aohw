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

module prism_sp_gem_tx_single#(
	parameter int NTXCORES
)
(
	fifo_read_interface.master tx_meta_fifo_r [NTXCORES],
	fifo_read_interface.master tx_csum_fifo_r [NTXCORES],
	fifo_read_interface.master tx_data_fifo_r [NTXCORES],

	gem_tx_interface.master gem_tx
);

/*
 * --------  --------  --------  --------
 * GEM TX Interface Clock Domain
 * --------  --------  --------  --------
 */
assign gem_tx.tx_r_flushed = '0;
assign gem_tx.tx_r_err = 1'b0;
assign gem_tx.tx_r_underflow = 1'b0;

localparam int TX_PACKET_BYTE_COUNT_WIDTH = 13;
var logic [TX_PACKET_BYTE_COUNT_WIDTH-1:0] tx_packet_byte_count_decr;
var logic [TX_PACKET_BYTE_COUNT_WIDTH-1:0] tx_packet_byte_count_incr;
wire tx_meta_desc_t i_meta_desc;
assign i_meta_desc = tx_meta_fifo_r[0].rd_data;

wire logic tx_last_byte_comb =
	~|tx_packet_byte_count_decr[$bits(tx_packet_byte_count_decr)-1:1] & tx_packet_byte_count_decr[0];

assign tx_meta_fifo_r[0].clock = gem_tx.tx_clock;
assign tx_meta_fifo_r[0].reset = ~gem_tx.tx_resetn;
assign tx_csum_fifo_r[0].clock = gem_tx.tx_clock;
assign tx_csum_fifo_r[0].reset = ~gem_tx.tx_resetn;
assign tx_data_fifo_r[0].clock = gem_tx.tx_clock;
assign tx_data_fifo_r[0].reset = ~gem_tx.tx_resetn;

// Only two states: idle (0) and not idle (1).
var logic tx_state = 1'b0;
var logic [tx_data_fifo_r[0].DATA_WIDTH-1:0] tx_cur_buf;
var logic [(tx_data_fifo_r[0].DATA_WIDTH/8)-1:0] tx_cur_buf_valid;

var logic [1:0] checksum_ip_type;
var logic [15:0] checksum_ip;
var logic [1:0] checksum_l4_type;
var logic [15:0] checksum_l4;

`define USE_CHECKSUM
`ifdef USE_CHECKSUM
var logic [$bits(gem_tx.tx_r_data)-1:0] gem_tx_tx_r_data;
always_comb begin
	gem_tx_tx_r_data = tx_cur_buf[7:0];
	if (checksum_ip_type == 2'b01) begin
		case (tx_packet_byte_count_incr)
		24: gem_tx_tx_r_data = checksum_ip[15:8];
		25: gem_tx_tx_r_data = checksum_ip[7:0];
		endcase
	end
	if (checksum_l4_type == 2'b10) begin
		case (tx_packet_byte_count_incr)
		40: gem_tx_tx_r_data = checksum_l4[15:8];
		41: gem_tx_tx_r_data = checksum_l4[7:0];
		endcase
	end
	if (checksum_l4_type == 2'b01) begin
		case (tx_packet_byte_count_incr)
		50: gem_tx_tx_r_data = checksum_l4[15:8];
		51: gem_tx_tx_r_data = checksum_l4[7:0];
		endcase
	end
end
`endif

always_ff @(posedge gem_tx.tx_clock) begin
	// Unpulse
	gem_tx.tx_r_valid <= 1'b0;
	tx_meta_fifo_r[0].rd_en <= 1'b0;
	tx_csum_fifo_r[0].rd_en <= 1'b0;
	tx_data_fifo_r[0].rd_en <= 1'b0;

	if (!gem_tx.tx_resetn) begin
		gem_tx.tx_r_data_rdy <= 1'b0;
	end
	else begin
		if (tx_state && gem_tx.tx_r_rd) begin
			// The FIFO interface requests a word of information.
			gem_tx.tx_r_data_rdy <= 1'b0;
			gem_tx.tx_r_valid <= 1'b1;
			// Put the lower 8 bits from the TX buffer on the bus.
`ifdef USE_CHECKSUM
			// Hardcode checksum replacement here.
			gem_tx.tx_r_data <= gem_tx_tx_r_data;
`else
			gem_tx.tx_r_data <= tx_cur_buf[7:0];
`endif

			// This is more like a resource utilization hack.
			// We used tx_r_data_rdy to tx_r_sop because we know
			// it will be 1'b1 only the first time we come around
			// here.
			gem_tx.tx_r_sop <= gem_tx.tx_r_data_rdy;
			gem_tx.tx_r_eop <= tx_last_byte_comb;

			// If the TX buffer will be completely invalid after this
			// cycle, reload the buffer from the FWFT FIFO, pop the
			// element from the FIFO and update the "valid" register.
			if (tx_cur_buf_valid[0] && !tx_last_byte_comb) begin
				tx_data_fifo_r[0].rd_en <= 1'b1;
				tx_cur_buf <= tx_data_fifo_r[0].rd_data;
			end
			else begin
				// Shift the TX buffer right by 8 bits.
				tx_cur_buf <= { 8'h00, tx_cur_buf[tx_data_fifo_r[0].DATA_WIDTH-1:8] };
			end
			// Rotate the TX buffer valid bits right by 1 bit.
			tx_cur_buf_valid <= { tx_cur_buf_valid[0], tx_cur_buf_valid[(tx_data_fifo_r[0].DATA_WIDTH/8)-1:1] };
			tx_state <= ~tx_last_byte_comb;
			tx_packet_byte_count_decr <= tx_packet_byte_count_decr - 1;
			tx_packet_byte_count_incr <= tx_packet_byte_count_incr + 1;
		end
		/*
		 * If there is a packet available.
		 */
		if ((~tx_state || (gem_tx.tx_r_rd && tx_last_byte_comb)) && !tx_meta_fifo_r[0].empty && !tx_csum_fifo_r[0].empty) begin
			gem_tx.tx_r_data_rdy <= 1'b1;
			tx_state <= 1'b1;

			tx_csum_fifo_r[0].rd_en <= 1'b1;
			checksum_ip_type <= tx_csum_fifo_r[0].rd_data[0+:2];
			checksum_ip <= tx_csum_fifo_r[0].rd_data[2+:16];
			checksum_l4_type <= tx_csum_fifo_r[0].rd_data[2+16+:2];
			checksum_l4 <= tx_csum_fifo_r[0].rd_data[2+16+2+:16];

			tx_meta_fifo_r[0].rd_en <= 1'b1;
			tx_packet_byte_count_decr <= i_meta_desc.size[TX_PACKET_BYTE_COUNT_WIDTH-1:0];
			tx_packet_byte_count_incr <= '0;
			gem_tx.tx_r_control <= i_meta_desc.nocrc;

			tx_data_fifo_r[0].rd_en <= 1'b1;
			tx_cur_buf <= tx_data_fifo_r[0].rd_data;
			tx_cur_buf_valid <= { 1'b1, {((tx_data_fifo_r[0].DATA_WIDTH/8)-1){1'b0}} };
		end
	end
end

var logic gem_dma_tx_end_tog_prev;

always_ff @(posedge gem_tx.tx_clock) begin
	gem_dma_tx_end_tog_prev <= gem_tx.dma_tx_end_tog;

	if (!gem_tx.tx_resetn) begin
	end
	else begin
		if (gem_dma_tx_end_tog_prev != gem_tx.dma_tx_end_tog) begin
			// Could add tx_r_status to the TX result FIFO here.
			gem_tx.dma_tx_status_tog <= gem_tx.dma_tx_end_tog;
		end
	end
end
endmodule
