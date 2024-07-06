/*
 * Copyright (c) 2023 Robert Drehmel
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
module prism_sp_puzzle_hw_gem_ring_release #(
	type DESC_TYPE,
	type COOKIE_TYPE
)
(
	input wire logic clock,
	input wire logic resetn,

	fifo_read_interface.master			i_cookie_fifo_r,
	fifo_write_interface.master			fifo_w,

	axi_write_address_channel.master	axi_aw,
	axi_write_channel.master			axi_w,
	axi_write_response_channel.master	axi_b
);

localparam int NAXI_IDS = 8;
localparam int AXI_ID_WIDTH = $clog2(NAXI_IDS);

/*
 * Cookie stored in
 * i_cookie_fifo_r.rd_data
 */
wire COOKIE_TYPE i_cookie = i_cookie_fifo_r.rd_data;

/*
 * DMA descriptor stored in
 * axi_w.wdata
 */
var DESC_TYPE o_desc;
assign axi_w.wdata = o_desc;

typedef enum logic [1:0] {
	W_STATE_INIT,
	W_STATE_FETCH_AXI_ID,
	W_STATE_FETCH_COOKIE,
	W_STATE_START_AXI_TRANSACTION
} w_state_t;
var w_state_t w_state;

typedef enum logic [1:0] {
	B_STATE_INIT,
	B_STATE_IDLE,
	B_STATE_BUSY,
	B_STATE_WAIT_FIFO_W_NOT_FULL
} b_state_t;
var b_state_t b_state;

assign axi_aw.awlen = 8'd0;
assign axi_aw.awsize = $clog2(($bits(axi_w.wdata)/8)-1);
assign axi_aw.awburst = 2'b01;
assign axi_aw.awcache = 4'b0011;
assign axi_aw.awprot = 3'h0;
assign axi_aw.awqos = 4'h0;
assign axi_aw.awlock = 0;
assign axi_aw.awuser = 1;

assign axi_w.wstrb = {($bits(axi_w.wdata)/8){1'b1}};
assign axi_w.wuser = 0;

always_ff @(posedge clock) begin
	// Unpulse
	i_cookie_fifo_r.rd_en <= 1'b0;
	fifo_w.wr_en <= 1'b0;

	if (!resetn) begin
		b_state <= B_STATE_INIT;
		w_state <= W_STATE_INIT;
		axi_aw.awvalid <= 1'b0;
		axi_w.wvalid <= 1'b0;
		axi_b.bready <= 1'b0;
		axi_id_alloc_ready <= 1'b0;
		axi_id_dealloc_valid <= 1'b0;
	end
	else begin
		case (w_state)
		W_STATE_INIT: begin
			axi_id_alloc_ready <= 1'b1;
			w_state <= W_STATE_FETCH_AXI_ID;
		end
		W_STATE_FETCH_AXI_ID: begin
			if (axi_id_alloc_valid & axi_id_alloc_ready) begin
				axi_id_alloc_ready <= 1'b0;
				axi_aw.awid <= axi_id_alloc_id;
				w_state <= W_STATE_FETCH_COOKIE;
			end
		end
		W_STATE_FETCH_COOKIE: begin
			if (!i_cookie_fifo_r.empty) begin
				i_cookie_fifo_r.rd_en <= 1'b1;

				axi_aw.awvalid <= 1'b1;
				axi_aw.awaddr <= i_cookie.addr;

				axi_w.wvalid <= 1'b1;
				if (type(i_cookie) == type(rx_cookie_t)) begin
					o_desc.valid <= 1'b1;
					o_desc.wrap <= i_cookie.wrap;
					// The 2 LSB of the ADDRL field are used for the
					// WRAP and VALID bits. See the comment in
					// prism_sp_puzzle_hw_gem_ring_acquire.sv
					o_desc.addrl <= i_cookie.data_addr[31:2];
					o_desc.size <= i_cookie.size;
					o_desc.fcs <= i_cookie.fcs;
					o_desc.sof <= i_cookie.sof;
					o_desc.eof <= i_cookie.eof;
					o_desc.cfi <= i_cookie.cfi;
					o_desc.rx_w_prty_tagged <= i_cookie.rx_w_prty_tagged;
					o_desc.rx_w_vlan_tagged <= i_cookie.rx_w_vlan_tagged;
					o_desc.chksum_enc <= i_cookie.chksum_enc;
					o_desc.add_match <= i_cookie.add_match;
					o_desc.w_add_match <= i_cookie.w_add_match;
					o_desc.w_ext_match <= i_cookie.w_ext_match;
					o_desc.w_uni_hash_match <= i_cookie.w_uni_hash_match;
					o_desc.w_broadcast_frame <= i_cookie.w_broadcast_frame;
					o_desc.w_mult_hash_match <= i_cookie.w_mult_hash_match;
					if (DMA_DESC_64BITADDR) begin
						o_desc.addrh <= i_cookie.data_addr[39:32];
					end
				end
				else if (type(i_cookie) == type(tx_cookie_t)) begin
					o_desc.addrl <= i_cookie.data_addr[31:0];
					o_desc.size <= i_cookie.size;
					o_desc.eof <= i_cookie.eof;
					o_desc.nocrc <= i_cookie.nocrc;
					o_desc.chksum_err <= '0;
					o_desc.late_coll <= 1'b0;
					o_desc.frame_corr <= 1'b0;
					o_desc.zero <= 1'b0;
					o_desc.retry_limit <= 1'b0;
					o_desc.wrap <= i_cookie.wrap;
					o_desc.valid <= 1'b1;
					if (DMA_DESC_64BITADDR) begin
						o_desc.addrh <= i_cookie.data_addr[39:32];
					end
				end
					
				axi_w.wlast <= 1'b1;

				w_state <= W_STATE_START_AXI_TRANSACTION;
			end
		end
		W_STATE_START_AXI_TRANSACTION: begin
			if (axi_aw.awvalid & axi_aw.awready) begin
				axi_aw.awvalid <= 1'b0;
			end
			if (axi_w.wvalid & axi_w.wready) begin
				axi_w.wvalid <= 1'b0;
				axi_w.wlast <= 1'b0;
			end
			if (((axi_aw.awvalid & axi_aw.awready) || !axi_aw.awvalid) &&
				((axi_w.wvalid & axi_w.wready) || !axi_w.wvalid))
			begin
				axi_id_alloc_ready <= 1'b1;
				w_state <= W_STATE_FETCH_AXI_ID;
			end
		end
		endcase

		case (b_state)
		B_STATE_INIT: begin
			axi_b.bready <= 1'b1;
			b_state <= B_STATE_IDLE;
		end
		B_STATE_IDLE: begin
			if (axi_b.bvalid & axi_b.bready) begin
				axi_b.bready <= 1'b0;

				axi_id_dealloc_valid <= 1'b1;
				axi_id_dealloc_id <= axi_b.bid;

				b_state <= B_STATE_BUSY;
			end
		end
		B_STATE_BUSY: begin
			if (axi_id_dealloc_valid & axi_id_dealloc_ready) begin
				axi_id_dealloc_valid <= 1'b0;

				if (!fifo_w.full) begin
					fifo_w.wr_en <= 1'b1;
					axi_b.bready <= 1'b1;
					b_state <= B_STATE_IDLE;
				end
				else begin
					b_state <= B_STATE_WAIT_FIFO_W_NOT_FULL;
				end
			end
		end
		B_STATE_WAIT_FIFO_W_NOT_FULL: begin
			if (!fifo_w.full) begin
				fifo_w.wr_en <= 1'b1;
				axi_b.bready <= 1'b1;
				b_state <= B_STATE_IDLE;
			end
		end
		endcase
	end
end

wire logic axi_id_alloc_valid;
var logic axi_id_alloc_ready;
wire logic [AXI_ID_WIDTH-1:0] axi_id_alloc_id;
var logic axi_id_dealloc_valid;
wire logic axi_id_dealloc_ready;
var logic [AXI_ID_WIDTH-1:0] axi_id_dealloc_id;

prism_axi_id_allocator #(
	.NIDS(8)
) prism_axi_id_allocator_0 (
	.clock,
	.resetn,

	.alloc_valid(axi_id_alloc_valid),
	.alloc_ready(axi_id_alloc_ready),
	.alloc_id(axi_id_alloc_id),
	.dealloc_valid(axi_id_dealloc_valid),
	.dealloc_ready(axi_id_dealloc_ready),
	.dealloc_id(axi_id_dealloc_id)
);

endmodule
