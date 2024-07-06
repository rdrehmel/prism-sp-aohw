/*
 * Copyright (c) 2016-2023 Robert Drehmel
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

// AXI[r] -> FIFO
module axi_to_fifo_v5#(
	parameter int FIFO_SIZE
)
(
	input wire logic clock,
	input wire logic resetn,

	// Interface to start the memory reading process
	memory_read_interface.slave mem_r,
	// Interface to write to a FIFO
	fifo_write_interface.master fifo_w,

	output wire logic ext_valid,
	output wire logic [fifo_w.DATA_WIDTH-1:0] ext_data,
	output wire logic ext_sof,
	output wire logic ext_eof,

	// Actual AXI memory interface for reading
	input wire logic [3:0] axi_arcache,
	axi_read_address_channel.master axi_ar,
	axi_read_channel.master axi_r,

	output trace_atf_t trace_atf,
	output trace_atf_bds_t trace_atf_bds
);

localparam int AXI_ADDR_WIDTH = axi_ar.AXI_ARADDR_WIDTH;
localparam int AXI_DATA_WIDTH = axi_r.AXI_RDATA_WIDTH;
localparam int OFFSET_WIDTH = $clog2(AXI_DATA_WIDTH / 8);

//
// Set up the AXI Read Channel interface
//
// Read Address
assign axi_ar.arid = '0;
// ARSIZE(exponent to 2^n bytes) is derived from AXI_DATA_WIDTH
// axi_ar.arsize is in bytes.
localparam int ARSIZE = $clog2((AXI_DATA_WIDTH/8)-1);
assign axi_ar.arsize = ARSIZE[2:0];
// INCR burst type
assign axi_ar.arburst = 2'b01;
assign axi_ar.arlock = 1'b0;
assign axi_ar.arcache = axi_arcache;
// XXX make this configurable for standalone use.
assign axi_ar.arprot = 3'b010;
assign axi_ar.arqos = 4'h0;
assign axi_ar.aruser = '1;

prism_axi_calc_interface #(
	.AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
	.AXI_DATA_WIDTH(AXI_DATA_WIDTH)
) axi_calc();
assign axi_calc.i_valid = mem_r.start;
assign axi_calc.i_address = mem_r.addr;
assign axi_calc.i_length = mem_r.len;
assign axi_calc.i_axhshake = axi_ar.arvalid & axi_ar.arready;
var logic is_last_burst;
var logic [OFFSET_WIDTH-1:0] last_beat_size;
var logic [OFFSET_WIDTH-1:0] first_beat_offset;

// ------- ------- ------- ------- ------- ------- ------- -------
//
// AXI SECTION A2.5: Read Address Channel
//
// ------- ------- ------- ------- ------- ------- ------- -------
// slave asserts RVALID and keeps it asserted.
// When master is ready to accept data, master asserts RREADY
// On the next clock posedge where both RVALID(S) and RREADY(M)
// are asserted, the data in RDATA is transferred.
//

// Little helpers
wire logic ar_hshake = axi_ar.arvalid && axi_ar.arready;
wire logic r_hshake = axi_r.rvalid && axi_r.rready;
wire logic r_hshake_last = r_hshake && axi_r.rlast;

always_ff @(posedge clock) begin
	if (!resetn) begin
		axi_ar.arvalid <= 1'b0;
	end
	else begin
		if (read_burst_start) begin
			axi_ar.arvalid <= 1'b1;
			axi_ar.araddr <= axi_calc.o_axaddr;
			axi_ar.arlen <= axi_calc.o_axlen;
			is_last_burst <= axi_calc.o_is_last_burst;
			last_beat_size <= axi_calc.o_last_beat_size;
		end
		if (ar_hshake) begin
			axi_ar.arvalid <= 1'b0;
		end
	end
end

// ------- ------- ------- ------- ------- ------- ------- -------
//
// AXI SECTION A2.6: Read Data (and Response) Channel
//
// ------- ------- ------- ------- ------- ------- ------- -------

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

// ------- ------- ------- ------- ------- ------- ------- -------
//
// Read operation FSM helpers
//
// ------- ------- ------- ------- ------- ------- ------- -------

var logic read_burst_done;
always_ff @(posedge clock) begin
	if (!resetn) begin
		read_burst_done <= 1'b0;
	end
	else begin
		// Unpulse
		read_burst_done <= 1'b0;

		if (r_hshake_last) begin
			read_burst_done <= 1'b1;
		end
	end
end

var logic start_of_frame;
var logic stuffer_first;
var logic stuffer_i_valid;
var logic stuffer_i_sof;
var logic stuffer_i_eof;
var logic [OFFSET_WIDTH-1:0] stuffer_i_lsbyte;
var logic [OFFSET_WIDTH-1:0] stuffer_i_msbyte;
var logic [AXI_DATA_WIDTH-1:0] stuffer_i_data;

wire logic stuffer_o_valid;
wire logic stuffer_o_sof;
wire logic stuffer_o_eof;
wire logic [AXI_DATA_WIDTH-1:0] stuffer_o_data;

assign fifo_w.wr_en = stuffer_o_valid;
assign fifo_w.wr_data = stuffer_o_data;

assign ext_valid = stuffer_o_valid;
assign ext_data = stuffer_o_data;
assign ext_sof = stuffer_o_sof;
assign ext_eof = stuffer_o_eof;

prism_axi_calc prism_axi_calc_0(
	.clock,
	.resetn,
	.axi_calc
);

always_ff @(posedge clock) begin
	// Unpulse
	stuffer_i_valid <= 1'b0;

	if (!resetn) begin
		start_of_frame <= 1'b1;
	end
	else begin
		if (ar_hshake) begin
			stuffer_first <= 1'b1;
		end
		if (r_hshake) begin
			stuffer_i_valid <= 1'b1;
			stuffer_i_data <= axi_r.rdata;
			stuffer_i_sof <= start_of_frame;

			if (stuffer_first) begin
				stuffer_i_lsbyte <= first_beat_offset;
				stuffer_first <= 1'b0;
			end
			else begin
				stuffer_i_lsbyte <= '0;
			end

			// Last burst and last beat...
			if (is_last_burst && axi_r.rlast) begin
				stuffer_i_msbyte <= last_beat_size;
				stuffer_i_eof <= ~cont;
				// A new dawn.
				start_of_frame <= ~cont;
			end
			else begin
				stuffer_i_msbyte <= (1 << OFFSET_WIDTH) - 1;
				start_of_frame <= 1'b0;
				stuffer_i_eof <= 1'b0;
			end
		end
	end
end

// ------- ------- ------- ------- ------- ------- ------- -------
//
// Read operation main
//
// ------- ------- ------- ------- ------- ------- ------- -------
// Reading initiation pulse
var logic read_burst_start;
var logic cont;

typedef enum logic [1:0] {
	STATE_IDLE,
	STATE_WAIT_FOR_AXI_CALC,
	STATE_WAIT_FOR_FIFO_SPACE,
	STATE_TRANSFER
} state_t;

var state_t state;

always_ff @(posedge clock) begin
	if (!resetn) begin
		read_burst_start <= 1'b0;
		mem_r.done <= 1'b0;
		mem_r.busy <= 1'b0;
		state <= STATE_IDLE;
	end
	else begin
		// Unpulse
		read_burst_start <= 1'b0;
		mem_r.done <= 1'b0;

		case (state)
		STATE_IDLE: begin
			if (mem_r.start) begin
				if (mem_r.len == 0) begin
					mem_r.done <= 1'b1;
					mem_r.error <= 1'b1;
				end
				else begin
					first_beat_offset <= mem_r.addr[OFFSET_WIDTH-1:0];
					cont <= mem_r.cont;
					mem_r.busy <= 1'b1;
					state <= STATE_WAIT_FOR_AXI_CALC;
				end
			end
		end
		STATE_WAIT_FOR_AXI_CALC: begin
			if (axi_calc.o_valid) begin
				state <= STATE_WAIT_FOR_FIFO_SPACE;
			end
		end
		STATE_TRANSFER: begin
			if (read_burst_done) begin
				// An offset can only appear on the first burst.
				first_beat_offset <= '0;
				if (is_last_burst) begin
					mem_r.error <= 1'b0;
					mem_r.done <= 1'b1;
					mem_r.busy <= 1'b0;
					state <= STATE_IDLE;
				end
				else begin
					if (axi_calc.o_valid) begin
						read_burst_start <= 1'b1;
					end
				end
			end
		end
		STATE_WAIT_FOR_FIFO_SPACE: begin
			if (FIFO_SIZE - fifo_w.wr_data_count >= mem_r.len) begin
				read_burst_start <= 1'b1;
				state <= STATE_TRANSFER;
			end
		end
		endcase
	end
end

prism_byte_data_stuffer #(
	.DATA_WIDTH(AXI_DATA_WIDTH)
) prism_byte_data_stuffer_0 (
	.clock,
	.resetn,

	.i_valid(stuffer_i_valid),
	.i_lsbyte(stuffer_i_lsbyte),
	.i_msbyte(stuffer_i_msbyte),
	.i_sof(stuffer_i_sof),
	.i_eof(stuffer_i_eof),
	.i_data(stuffer_i_data),

	.o_valid(stuffer_o_valid),
	.o_data(stuffer_o_data),
	.o_sof(stuffer_o_sof),
	.o_eof(stuffer_o_eof),

	.trace_atf_bds
);

assign trace_atf.stuffer_first = stuffer_first;
assign trace_atf.stuffer_i_valid = stuffer_i_valid;
assign trace_atf.stuffer_i_sof = stuffer_i_sof;
assign trace_atf.stuffer_i_eof = stuffer_i_eof;
assign trace_atf.stuffer_i_lsbyte = stuffer_i_lsbyte;
assign trace_atf.stuffer_i_msbyte = stuffer_i_msbyte;
assign trace_atf.stuffer_i_data = stuffer_i_data;
assign trace_atf.stuffer_o_valid = stuffer_o_valid;
assign trace_atf.stuffer_o_data = stuffer_o_data;

assign trace_atf.axi_calc_i_valid = axi_calc.i_valid;
assign trace_atf.axi_calc_i_address = axi_calc.i_address;
assign trace_atf.axi_calc_i_length = axi_calc.i_length;
assign trace_atf.axi_calc_i_axhshake = axi_calc.i_axhshake;
assign trace_atf.axi_calc_o_valid = axi_calc.o_valid;
assign trace_atf.axi_calc_o_axaddr = axi_calc.o_axaddr;
assign trace_atf.axi_calc_o_axlen = axi_calc.o_axlen;

endmodule
