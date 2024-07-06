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
module prism_axi_calc (
	input wire logic clock,
	input wire logic resetn,

	prism_axi_calc_interface.slave axi_calc
);

localparam int AXI_ADDR_WIDTH = axi_calc.AXI_ADDR_WIDTH;
localparam int AXI_DATA_WIDTH = axi_calc.AXI_DATA_WIDTH;

localparam int MAXBYTESPERBURST = 256 * (AXI_DATA_WIDTH / 8);
localparam int OFFSET_WIDTH = $clog2(AXI_DATA_WIDTH/8);

localparam int LENGTH_WIDTH = $bits(axi_calc.i_length);
localparam int TOTAL_BEATS_WIDTH = LENGTH_WIDTH - OFFSET_WIDTH;
localparam int BEATS_WIDTH = 8;

wire logic [LENGTH_WIDTH-1:0] _total_beats_comb = len_plus_off + ((1 << OFFSET_WIDTH) - 1);
wire logic [TOTAL_BEATS_WIDTH-1:0] total_beats_comb = _total_beats_comb[LENGTH_WIDTH-1:OFFSET_WIDTH];
var logic [TOTAL_BEATS_WIDTH-1:0] total_beats;

typedef enum logic [2:0] {
	STATE_IDLE,
	STATE_CALC0,
	STATE_ALIGN,
	STATE_RECALC,
	STATE_RUNNING,
	STATE_RUNNING2
} state_t;

var state_t state;

var logic [LENGTH_WIDTH-1:0] len_plus_off;
var logic [AXI_ADDR_WIDTH-1:0] addr_plus_len;
var logic [8:0] align_beats;

assign axi_calc.o_axaddr[OFFSET_WIDTH-1:0] = '0;

always_ff @(posedge clock) begin
	if (!resetn) begin
		state <= STATE_IDLE;
		axi_calc.o_valid <= 1'b0;
	end
	else begin
		case (state)
		STATE_IDLE: begin
			if (axi_calc.i_valid) begin
				axi_calc.o_axaddr[AXI_ADDR_WIDTH-1:OFFSET_WIDTH] <= axi_calc.i_address[AXI_ADDR_WIDTH-1:OFFSET_WIDTH];
				len_plus_off <= axi_calc.i_length + $bits(axi_calc.i_length)'(axi_calc.i_address[OFFSET_WIDTH-1:0]);
				addr_plus_len <= axi_calc.i_address + axi_calc.i_length;
				/*
				 * Stores how many beats we need for alignment.
				 */
				align_beats <= 9'h100 - axi_calc.i_address[OFFSET_WIDTH +: 8];
				state <= STATE_CALC0;
			end
		end
		STATE_CALC0: begin
			total_beats <= total_beats_comb;
			axi_calc.o_last_beat_size <= len_plus_off[OFFSET_WIDTH-1:0] - 1;

			if (addr_plus_len[AXI_ADDR_WIDTH-1:8+OFFSET_WIDTH] != axi_calc.o_axaddr[AXI_ADDR_WIDTH-1:8+OFFSET_WIDTH]) begin
				state <= STATE_ALIGN;
			end
			else begin
				state <= STATE_RECALC;
			end
		end
		STATE_ALIGN: begin
			/*
			 * We need to align first.
			 */
			axi_calc.o_valid <= 1'b1;
			axi_calc.o_axlen <= align_beats - 1;
			axi_calc.o_is_last_burst <= align_beats == total_beats;
			state <= STATE_RUNNING;
		end
		STATE_RECALC: begin
			axi_calc.o_valid <= 1'b1;
			if (total_beats > 256) begin
				axi_calc.o_axlen <= 255;
				axi_calc.o_is_last_burst <= 1'b0;
			end
			else begin
				axi_calc.o_axlen <= total_beats - 1;
				axi_calc.o_is_last_burst <= 1'b1;
			end
			state <= STATE_RUNNING;
		end
		STATE_RUNNING: begin
			if (axi_calc.i_axhshake) begin
				axi_calc.o_valid <= 1'b0;
				total_beats <= total_beats - 1;
				axi_calc.o_axaddr[AXI_ADDR_WIDTH-1:OFFSET_WIDTH] <=
					axi_calc.o_axaddr[AXI_ADDR_WIDTH-1:OFFSET_WIDTH] + 1;
				state <= STATE_RUNNING2;
			end
		end
		STATE_RUNNING2: begin
			total_beats <= total_beats - axi_calc.o_axlen;
			axi_calc.o_axaddr[AXI_ADDR_WIDTH-1:OFFSET_WIDTH] <=
				axi_calc.o_axaddr[AXI_ADDR_WIDTH-1:OFFSET_WIDTH] + axi_calc.o_axlen;
			if (axi_calc.o_is_last_burst) begin
				state <= STATE_IDLE;
			end
			else begin
				state <= STATE_RECALC;
			end
		end
		endcase
	end
end

endmodule
