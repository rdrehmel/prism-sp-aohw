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
module prism_sp_puzzle_hw_gem_ring_acquire#(
	type DESC_TYPE,
	type COOKIE_TYPE,
	parameter int FIFO_DEPTH
) (
	input wire logic clock,
	input wire logic resetn,

	input wire logic enable,
	mmr_trigger_interface.master mmr_t,

	input wire logic [SYSTEM_ADDR_WIDTH-1:0] dma_desc_base,

	fifo_write_interface.master o_cookie_fifo_w,
	prism_sp_ring_acquire_cookie_convert_interface.master conv,

	axi_read_address_channel.master axi_ar,
	axi_read_channel.master axi_r
);

localparam int DESC_WIDTH = $bits(DESC_TYPE);
if ($bits(axi_r.rdata) != DESC_WIDTH) begin
	$error("The data width of AXI port MA (%d) has to be equal to DESC_WIDTH (%d)\n",
		$bits(axi_r.rdata), DESC_WIDTH);
end

assign axi_ar.arsize = $clog2(DESC_WIDTH/8);

/*
 * As currently implemented, this has to satisfy
 * FIFO_THRESH = FIFO_DEPTH / 2 .
 */
localparam int FIFO_THRESH = FIFO_DEPTH / 2;

/*
 * Set up the converter
 */
assign conv.data_in = axi_r.rdata;
assign conv.dma_desc_cur = dma_desc_cur;

wire DESC_TYPE i_desc = axi_r.rdata;

typedef enum logic [2:0] {
	STATE_INIT,
	STATE_IDLE,
	STATE_REFILL,
	STATE_FIFO_SETTLE1,
	STATE_FIFO_SETTLE2,
	STATE_WAIT_FOR_TRIGGER
} state_t;

var logic [SYSTEM_ADDR_WIDTH-1:0] dma_desc_cur;
var state_t state;

always_ff @(posedge clock) begin
	mmr_t.tsr_invpulses[0][0] <= 1'b0;

	if (!resetn) begin
		axi_ar.arvalid <= 1'b0;
		state <= STATE_INIT;
	end
	else begin
		case (state)
		STATE_INIT: begin
			if (enable) begin
				state <= STATE_IDLE;
			end
		end
		STATE_IDLE: begin
			if (o_cookie_fifo_w.wr_data_count <= FIFO_THRESH) begin
				axi_ar.arvalid <= 1'b1;
				axi_ar.araddr <= dma_desc_cur;
				// We have to be careful not to cross a 4 kiB boundary.
				state <= STATE_REFILL;
			end
		end
		STATE_REFILL: begin
			if (r_hshake_last) begin
				state <= STATE_FIFO_SETTLE1;
			end
		end
		STATE_FIFO_SETTLE1: begin
			// In this clock cycle, the FIFO registers the last write
			state <= STATE_FIFO_SETTLE2;
		end
		STATE_FIFO_SETTLE2: begin
			// In this clock cycle, wr_data_count is not touched yet.
			if (saw_invalid) begin
				state <= STATE_WAIT_FOR_TRIGGER;
			end
			else begin
				state <= STATE_IDLE;
			end
		end
		STATE_WAIT_FOR_TRIGGER: begin
			if (mmr_t.tsr[0][0]) begin
				mmr_t.tsr_invpulses[0][0] <= 1'b1;
				state <= STATE_IDLE;
			end
		end
		endcase
	end

	if (ar_hshake) begin
		axi_ar.arvalid <= 1'b0;
	end
end

wire logic ar_hshake = axi_ar.arvalid && axi_ar.arready;
wire logic r_hshake = axi_r.rvalid && axi_r.rready;
wire logic r_hshake_last = r_hshake && axi_r.rlast;
//
// Set up the AXI Read Channel interface
//
// Read Address
assign axi_ar.arid = '0;
assign axi_ar.arsize = $clog2(DESC_WIDTH/8);
// INCR burst type
assign axi_ar.arburst = 2'b01;
assign axi_ar.arlock = 1'b0;
assign axi_ar.arcache = 4'b0011;
assign axi_ar.arprot = 3'h0;
assign axi_ar.arqos = 4'h0;
assign axi_ar.aruser = '0;
var logic [$clog2(FIFO_THRESH)-1:0] axi_ar_arlen;
assign axi_ar.arlen = { {($bits(axi_ar.arlen) - $bits(axi_ar_arlen)){1'b0}}, axi_ar_arlen };

var logic saw_invalid;

always_ff @(posedge clock) begin
	o_cookie_fifo_w.wr_en <= 1'b0;

	if (!resetn) begin
		saw_invalid <= 1'b0;
	end
	else begin

		if (state == STATE_INIT) begin
			if (enable) begin
				dma_desc_cur <= dma_desc_base;
				// Start with FIFO_THRESH number of beats.
				axi_ar_arlen <= '1;
			end
		end

		if (ar_hshake) begin
			saw_invalid <= 1'b0;
		end

		if (!saw_invalid) begin
			if (r_hshake) begin
				o_cookie_fifo_w.wr_en <= ~i_desc.valid;
				o_cookie_fifo_w.wr_data <= conv.data_out;
				saw_invalid <= i_desc.valid;

				if (!i_desc.valid) begin
					// Check the WRAP bit
					if (i_desc.wrap) begin
						dma_desc_cur <= dma_desc_base;
						// Start with FIFO_THRESH beats again.
						axi_ar_arlen <= '1;
						// Every word following this word will be invalid.
						saw_invalid <= 1'b1;
					end
					else begin
						dma_desc_cur <= dma_desc_cur + (DESC_WIDTH / 8);
						// This wraps around automagically.
						axi_ar_arlen <= axi_ar_arlen - 1;
					end
				end
			end
		end
	end
end

always_ff @(posedge clock) begin
	if (!resetn) begin
		axi_r.rready <= 1'b0;
	end
	else begin
		if (ar_hshake) begin
			axi_r.rready <= 1'b1;
		end
		else if (r_hshake_last) begin
			axi_r.rready <= 1'b0;
		end
	end
end

endmodule
