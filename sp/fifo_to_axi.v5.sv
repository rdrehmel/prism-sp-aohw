/*
 * Copyright (c) 2016-2021 Robert Drehmel
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
//
// FIFO -> AXI[w]
//
module fifo_to_axi_v5 (
	input wire logic clock,
	input wire logic resetn,

	// Interface to start memory writing process
	memory_write_interface.slave mem_w,
	// Interface to read from a FIFO
	fifo_read_interface.master fifo_r,

	// Interface of the actual AXI writing channel(s)
	input wire logic [3:0] axi_awcache,
	axi_write_address_channel.master axi_aw,
	axi_write_channel.master axi_w,
	axi_write_response_channel.master axi_b
);

localparam int AXI_ADDR_WIDTH = axi_aw.AXI_AWADDR_WIDTH;
localparam int AXI_DATA_WIDTH = axi_w.AXI_WDATA_WIDTH;
localparam int OFFSET_WIDTH = $clog2(AXI_DATA_WIDTH / 8);

//
// Set up the AXI Write Channel interface
//
assign axi_aw.awid = '0;
// Size should be AXI_DATA_WIDTH, in 2^AWSIZE bytes, otherwise narrow bursts are
// used
localparam int AWSIZE = $clog2((AXI_DATA_WIDTH/8)-1);
assign axi_aw.awsize = AWSIZE[2:0];
// INCR burst type
assign axi_aw.awburst = 2'b01;
assign axi_aw.awlock = 0;
assign axi_aw.awcache = axi_awcache;
assign axi_aw.awprot = 3'h0;
assign axi_aw.awqos = 4'h0;
assign axi_aw.awuser = 1;
assign axi_w.wuser = 0;

prism_axi_calc_interface #(
	.AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
	.AXI_DATA_WIDTH(AXI_DATA_WIDTH)
) axi_calc();
assign axi_calc.i_valid = mem_w.start;
assign axi_calc.i_address = mem_w.addr;
assign axi_calc.i_length = mem_w.len;
assign axi_calc.i_axhshake = axi_aw.awvalid & axi_aw.awready;
var logic is_last_burst;
var logic [OFFSET_WIDTH-1:0] first_beat_offset;
var logic [OFFSET_WIDTH-1:0] last_beat_size;

// ------- ------- ------- ------- ------- ------- ------- -------
//
// AXI SECTION A2.2: Write Address Channel
//
// ------- ------- ------- ------- ------- ------- ------- -------

// Little helpers
wire logic aw_hshake = axi_aw.awvalid && axi_aw.awready;
wire logic w_hshake = axi_w.wvalid && axi_w.wready;
wire logic w_hshake_last = w_hshake && axi_w.wlast;
wire logic w_hshake_not_last = w_hshake && !axi_w.wlast;
wire logic b_hshake = axi_b.bvalid && axi_b.bready;

assign fifo_r.rd_en = write_burst_start || w_hshake_not_last;

prism_axi_calc prism_axi_calc_0(
	.clock,
	.resetn,
	.axi_calc
);

var logic [7:0] nbeats;

always_ff @(posedge clock) begin
	if (!resetn) begin
		axi_aw.awvalid <= 1'b0;
	end
	else begin
		if (write_burst_start) begin
			axi_aw.awvalid <= 1'b1;
			axi_aw.awaddr <= axi_calc.o_axaddr;
			axi_aw.awlen <= axi_calc.o_axlen;
			nbeats <= axi_calc.o_axlen;
			is_last_burst <= axi_calc.o_is_last_burst;
			last_beat_size <= axi_calc.o_last_beat_size;
		end
		if (aw_hshake) begin
			// The address was successfully submitted.
			// Now deassert AWVALID until the next burst starts.
			axi_aw.awvalid <= 1'b0;
		end
		if (w_hshake) begin
			nbeats <= nbeats - 1;
		end
	end
end

// ------- ------- ------- ------- ------- ------- ------- -------
//
// AXI SECTION A2.3: Write Data Channel
//
// ------- ------- ------- ------- ------- ------- ------- -------
var logic [(AXI_DATA_WIDTH/8)-1:0] axi_w_wstrb_comb;
/* Switch off verilator's linting because it does not
 * honor the fact that the widths of the RHSs are
 * correct iff the preceding if-clause is true.
 */
/* verilator lint_off WIDTH */
always_comb begin
if (AXI_DATA_WIDTH == 32) begin
	case (last_beat_size)
	2'h0: axi_w_wstrb_comb = 4'b0001;
	2'h1: axi_w_wstrb_comb = 4'b0011;
	2'h2: axi_w_wstrb_comb = 4'b0111;
	2'h3: axi_w_wstrb_comb = 4'b1111;
	endcase
end
else if (AXI_DATA_WIDTH == 64) begin
	case (last_beat_size)
	3'h0: axi_w_wstrb_comb = 8'b00000001;
	3'h1: axi_w_wstrb_comb = 8'b00000011;
	3'h2: axi_w_wstrb_comb = 8'b00000111;
	3'h3: axi_w_wstrb_comb = 8'b00001111;
	3'h4: axi_w_wstrb_comb = 8'b00011111;
	3'h5: axi_w_wstrb_comb = 8'b00111111;
	3'h6: axi_w_wstrb_comb = 8'b01111111;
	3'h7: axi_w_wstrb_comb = 8'b11111111;
	endcase
end
else if (AXI_DATA_WIDTH == 128) begin
	case (last_beat_size)
	4'h0: axi_w_wstrb_comb = 16'b0000000000000001;
	4'h1: axi_w_wstrb_comb = 16'b0000000000000011;
	4'h2: axi_w_wstrb_comb = 16'b0000000000000111;
	4'h3: axi_w_wstrb_comb = 16'b0000000000001111;
	4'h4: axi_w_wstrb_comb = 16'b0000000000011111;
	4'h5: axi_w_wstrb_comb = 16'b0000000000111111;
	4'h6: axi_w_wstrb_comb = 16'b0000000001111111;
	4'h7: axi_w_wstrb_comb = 16'b0000000011111111;
	4'h8: axi_w_wstrb_comb = 16'b0000000111111111;
	4'h9: axi_w_wstrb_comb = 16'b0000001111111111;
	4'ha: axi_w_wstrb_comb = 16'b0000011111111111;
	4'hb: axi_w_wstrb_comb = 16'b0000111111111111;
	4'hc: axi_w_wstrb_comb = 16'b0001111111111111;
	4'hd: axi_w_wstrb_comb = 16'b0011111111111111;
	4'he: axi_w_wstrb_comb = 16'b0111111111111111;
	4'hf: axi_w_wstrb_comb = 16'b1111111111111111;
	endcase
end
end
/*
 * This can be used if we one day support unaligned AXI write transactions.
 */
`ifdef NOTYET
always_comb begin
if (AXI_DATA_WIDTH == 32) begin
	case (last_beat_size)
	2'h0: axi_w_wstrb_comb = 4'b1111;
	2'h1: axi_w_wstrb_comb = 4'b1110;
	2'h2: axi_w_wstrb_comb = 4'b1100;
	2'h3: axi_w_wstrb_comb = 4'b1000;
	endcase
end
else if (AXI_DATA_WIDTH == 64) begin
	case (last_beat_size)
	3'h0: axi_w_wstrb_comb = 8'b11111111;
	3'h1: axi_w_wstrb_comb = 8'b11111110;
	3'h2: axi_w_wstrb_comb = 8'b11111100;
	3'h3: axi_w_wstrb_comb = 8'b11111000;
	3'h4: axi_w_wstrb_comb = 8'b11110000;
	3'h5: axi_w_wstrb_comb = 8'b11100000;
	3'h6: axi_w_wstrb_comb = 8'b11000000;
	3'h7: axi_w_wstrb_comb = 8'b10000000;
	endcase
end
else if (AXI_DATA_WIDTH == 128) begin
	case (last_beat_size)
	4'h0: axi_w_wstrb_comb = 16'b1111111111111111;
	4'h1: axi_w_wstrb_comb = 16'b1111111111111110;
	4'h2: axi_w_wstrb_comb = 16'b1111111111111100;
	4'h3: axi_w_wstrb_comb = 16'b1111111111111000;
	4'h4: axi_w_wstrb_comb = 16'b1111111111110000;
	4'h5: axi_w_wstrb_comb = 16'b1111111111100000;
	4'h6: axi_w_wstrb_comb = 16'b1111111111000000;
	4'h7: axi_w_wstrb_comb = 16'b1111111110000000;
	4'h8: axi_w_wstrb_comb = 16'b1111111100000000;
	4'h9: axi_w_wstrb_comb = 16'b1111111000000000;
	4'ha: axi_w_wstrb_comb = 16'b1111110000000000;
	4'hb: axi_w_wstrb_comb = 16'b1111100000000000;
	4'hc: axi_w_wstrb_comb = 16'b1111000000000000;
	4'hd: axi_w_wstrb_comb = 16'b1110000000000000;
	4'he: axi_w_wstrb_comb = 16'b1100000000000000;
	4'hf: axi_w_wstrb_comb = 16'b1000000000000000;
	endcase
end
end
`endif
/* verilator lint_on WIDTH */

always_ff @(posedge clock) begin
	if (!resetn) begin
		axi_w.wvalid <= 1'b0;
	end
	else begin
		if (write_burst_start || w_hshake_not_last) begin
			axi_w.wvalid <= 1'b1;
			axi_w.wdata <= fifo_r.rd_data;
			if ((write_burst_start && axi_calc.o_axlen == '0) ||
				(w_hshake && nbeats == 1))
			begin
				axi_w.wlast <= 1'b1;
				if (is_last_burst) begin
					axi_w.wstrb <= axi_w_wstrb_comb;
				end
				else begin
					axi_w.wstrb <= '1;
				end
			end
			else begin
				axi_w.wlast <= 1'b0;
				axi_w.wstrb <= '1;
			end
		end
		else if (w_hshake_last) begin
			axi_w.wvalid <= 1'b0;
		end
	end
end

// ------- ------- ------- ------- ------- ------- ------- -------
//
// AXI SECTION A2.4: Write Response (B) Channel
//
// ------- ------- ------- ------- ------- ------- ------- -------
always_ff @(posedge clock) begin
	if (!resetn) begin
		axi_b.bready <= 1'b0;
	end
	else begin
		if (w_hshake_last) begin
			axi_b.bready <= 1'b1;
		end
		else if (b_hshake) begin
			axi_b.bready <= 1'b0;
		end
	end
end

// ------- ------- ------- ------- ------- ------- ------- -------
//
// Write operation FSM helpers
//
// ------- ------- ------- ------- ------- ------- ------- -------

var logic write_burst_done;
always_ff @(posedge clock) begin
	if (!resetn) begin
		write_burst_done <= 1'b0;
	end
	else begin
		// unpulse
		write_burst_done <= 1'b0;

		if (b_hshake) begin
			write_burst_done <= 1'b1;
		end
	end
end

// ------- ------- ------- ------- ------- ------- ------- -------
//
// Write operation main
//
// ------- ------- ------- ------- ------- ------- ------- -------
// Writing initiation pulse
var logic write_burst_start;

typedef enum logic [1:0] {
	STATE_IDLE,
	STATE_WAIT_FOR_AXI_CALC,
	STATE_TRANSFER
} state_t;

var state_t state;

always_ff @(posedge clock) begin
	if (!resetn) begin
		write_burst_start <= 1'b0;
		mem_w.busy <= 1'b0;
		mem_w.done <= 1'b0;
		state <= STATE_IDLE;
	end
	else begin
		// Unpulse
		write_burst_start <= 1'b0;
		mem_w.done <= 1'b0;

		case (state)
		STATE_IDLE: begin
			if (mem_w.start) begin
				if (mem_w.len == 0) begin
					mem_w.error <= 1;
					mem_w.done <= 1'b1;
				end
				else begin
					mem_w.busy <= 1'b1;
					state <= STATE_WAIT_FOR_AXI_CALC;
				end
			end
		end
		STATE_WAIT_FOR_AXI_CALC: begin
			if (axi_calc.o_valid) begin
				write_burst_start <= 1'b1;
				state <= STATE_TRANSFER;
			end
		end
		STATE_TRANSFER: begin
			if (write_burst_done) begin
				if (is_last_burst) begin
					mem_w.error <= 1'b0;
					mem_w.done <= 1'b1;
					mem_w.busy <= 1'b0;
					state <= STATE_IDLE;
				end
				else begin
					if (axi_calc.o_valid) begin
						write_burst_start <= 1'b1;
					end
				end
			end
		end
		endcase
	end
end

endmodule
