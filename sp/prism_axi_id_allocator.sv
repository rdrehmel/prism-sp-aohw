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
module prism_axi_id_allocator
#(
	parameter int NIDS,
	parameter int ID_WIDTH = $clog2(NIDS)
)
(
	input wire logic clock,
	input wire logic resetn,

	output var logic alloc_valid,
	input wire logic alloc_ready,
	output var logic [ID_WIDTH-1:0] alloc_id,

	input wire logic dealloc_valid,
	output var logic dealloc_ready,
	input wire logic [ID_WIDTH-1:0] dealloc_id
);

var logic [NIDS-1:0] ids;
wire logic [(NIDS*2)-1:0] dids0 = { ids, ids };
wire logic [(NIDS*2)-1:0] dids1 = dids0 & ~(dids0 - (2*NIDS)'(1'b1));
wire logic next_id = dids1[(2*NIDS)-1:0] | dids1[NIDS-1:0];

if (NIDS != 8) begin
	$error("Parameter NIDS is currently limited to 8.");
end

var logic [NIDS-1:0] alloc_id_onehot;
var logic [ID_WIDTH-1:0] alloc_id_comb;

always_comb begin
	unique case (1'b1)
	alloc_id_onehot[0]: alloc_id_comb = 3'd0;
	alloc_id_onehot[1]: alloc_id_comb = 3'd1;
	alloc_id_onehot[2]: alloc_id_comb = 3'd2;
	alloc_id_onehot[3]: alloc_id_comb = 3'd3;
	alloc_id_onehot[4]: alloc_id_comb = 3'd4;
	alloc_id_onehot[5]: alloc_id_comb = 3'd5;
	alloc_id_onehot[6]: alloc_id_comb = 3'd6;
	alloc_id_onehot[7]: alloc_id_comb = 3'd7;
	endcase
end

typedef enum logic [1:0] {
	STATE_IDLE,
	STATE_PREP_NEXT_ID1,
	STATE_PREP_NEXT_ID2
} state_t;
var state_t state;

always_ff @(posedge clock) begin
	if (!resetn) begin
		ids <= '0;
		alloc_valid <= 1'b0;
		dealloc_ready <= 1'b0;
		state <= STATE_PREP_NEXT_ID1;
	end
	else begin
		case (state)
		STATE_IDLE: begin
			if (alloc_valid & alloc_ready) begin
				ids[alloc_id] <= 1'b1;

				alloc_valid <= 1'b0;
				dealloc_ready <= 1'b0;

				state <= STATE_PREP_NEXT_ID1;
			end
			if (dealloc_valid & dealloc_ready) begin
				ids[dealloc_id] <= 1'b0;

				if (!alloc_valid) begin
					dealloc_ready <= 1'b0;
					state <= STATE_PREP_NEXT_ID1;
				end
			end
		end
		STATE_PREP_NEXT_ID1: begin
			alloc_id_onehot <= next_id;
			state <= STATE_PREP_NEXT_ID2;
		end
		STATE_PREP_NEXT_ID2: begin
			// alloc_valid is zero if all the IDs are allocated.
			alloc_valid <= ~&ids;
			alloc_id <= alloc_id_comb;

			state <= STATE_IDLE;
			dealloc_ready <= 1'b1;
		end
		endcase
	end
end

endmodule
