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
module prism_byte_data_stuffer
#(
	parameter int DATA_WIDTH,
	parameter int SIZE_WIDTH = $clog2(DATA_WIDTH/8),
	parameter int OFF_WIDTH = $clog2(DATA_WIDTH/8)
)
(
	input wire logic clock,
	input wire logic resetn,

	input wire logic i_valid,
	input wire logic [OFF_WIDTH-1:0] i_lsbyte,
	input wire logic [OFF_WIDTH-1:0] i_msbyte,
	input wire logic i_sof,
	input wire logic i_eof,
	input wire logic [DATA_WIDTH-1:0] i_data,

	output wire logic o_valid,
	output wire logic o_sof,
	output wire logic o_eof,
	output wire logic [DATA_WIDTH-1:0] o_data,

	output trace_atf_bds_t trace_atf_bds
);

`ifdef USE_STAGE0
var logic stage0_valid_ff;
var logic [DATA_WIDTH-1:0] stage0_data_ff;
var logic [OFF_WIDTH-1:0] stage0_lsbyte_ff;
var logic [SIZE_WIDTH-1:0] stage0_msbyte_ff;
var logic stage0_sof_ff;
var logic stage0_eof_ff;

always @(posedge clock) begin
	stage0_valid_ff <= i_valid;
	stage0_lsbyte_ff <= i_lsbyte;
	stage0_size_ff <= i_msbyte - i_lsbyte;
	stage0_sof_ff <= i_sof;
	stage0_eof_ff <= i_eof;
	stage0_data_ff <= i_data;
end
`else
wire logic stage0_valid_ff = i_valid;
wire logic [DATA_WIDTH-1:0] stage0_data_ff = i_data;
wire logic [OFF_WIDTH-1:0] stage0_lsbyte_ff = i_lsbyte;
wire logic [SIZE_WIDTH-1:0] stage0_size_ff = i_msbyte - i_lsbyte;
wire logic stage0_sof_ff = i_sof;
wire logic stage0_eof_ff = i_eof;
`endif

/*
 * Stage0 to stage1: Shift right and size to mask.
 */
var logic [DATA_WIDTH-1:0] stage0_data_shr_comb;
if (DATA_WIDTH == 32) begin
	always_comb begin
		unique case (stage0_lsbyte_ff)
		3'h0: stage0_data_shr_comb = { stage0_data_ff };
		3'h1: stage0_data_shr_comb = {   8'h0, stage0_data_ff[1*8 +: 3*8] };
		3'h2: stage0_data_shr_comb = {  16'h0, stage0_data_ff[2*8 +: 2*8] };
		3'h3: stage0_data_shr_comb = {  24'h0, stage0_data_ff[3*8 +: 1*8] };
		endcase
	end
end
else if (DATA_WIDTH == 64) begin
	always_comb begin
		unique case (stage0_lsbyte_ff)
		3'h0: stage0_data_shr_comb = { stage0_data_ff };
		3'h1: stage0_data_shr_comb = {   8'h0, stage0_data_ff[1*8 +: 7*8] };
		3'h2: stage0_data_shr_comb = {  16'h0, stage0_data_ff[2*8 +: 6*8] };
		3'h3: stage0_data_shr_comb = {  24'h0, stage0_data_ff[3*8 +: 5*8] };
		3'h4: stage0_data_shr_comb = {  32'h0, stage0_data_ff[4*8 +: 4*8] };
		3'h5: stage0_data_shr_comb = {  40'h0, stage0_data_ff[5*8 +: 3*8] };
		3'h6: stage0_data_shr_comb = {  48'h0, stage0_data_ff[6*8 +: 2*8] };
		3'h7: stage0_data_shr_comb = {  56'h0, stage0_data_ff[7*8 +: 1*8] };
		endcase
	end
end
else if (DATA_WIDTH == 128) begin
	always_comb begin
		unique case (stage0_lsbyte_ff)
		4'h0: stage0_data_shr_comb = { stage0_data_ff };
		4'h1: stage0_data_shr_comb = {   8'h0, stage0_data_ff[1*8 +: 15*8] };
		4'h2: stage0_data_shr_comb = {  16'h0, stage0_data_ff[2*8 +: 14*8] };
		4'h3: stage0_data_shr_comb = {  24'h0, stage0_data_ff[3*8 +: 13*8] };
		4'h4: stage0_data_shr_comb = {  32'h0, stage0_data_ff[4*8 +: 12*8] };
		4'h5: stage0_data_shr_comb = {  40'h0, stage0_data_ff[5*8 +: 11*8] };
		4'h6: stage0_data_shr_comb = {  48'h0, stage0_data_ff[6*8 +: 10*8] };
		4'h7: stage0_data_shr_comb = {  56'h0, stage0_data_ff[7*8 +: 9*8] };
		4'h8: stage0_data_shr_comb = {  64'h0, stage0_data_ff[8*8 +: 8*8] };
		4'h9: stage0_data_shr_comb = {  72'h0, stage0_data_ff[9*8 +: 7*8] };
		4'ha: stage0_data_shr_comb = {  80'h0, stage0_data_ff[10*8 +: 6*8] };
		4'hb: stage0_data_shr_comb = {  88'h0, stage0_data_ff[11*8 +: 5*8] };
		4'hc: stage0_data_shr_comb = {  96'h0, stage0_data_ff[12*8 +: 4*8] };
		4'hd: stage0_data_shr_comb = { 104'h0, stage0_data_ff[13*8 +: 3*8] };
		4'he: stage0_data_shr_comb = { 112'h0, stage0_data_ff[14*8 +: 2*8] };
		4'hf: stage0_data_shr_comb = { 120'h0, stage0_data_ff[15*8 +: 1*8] };
		endcase
	end
end

var logic [DATA_WIDTH/8-1:0] stage0_bytemask_comb;
if (DATA_WIDTH == 32) begin
	always_comb begin
		unique case (stage0_size_ff)
		4'h0: stage0_bytemask_comb = { {3{1'b0}},  {1{1'b1}} };
		4'h1: stage0_bytemask_comb = { {2{1'b0}},  {2{1'b1}} };
		4'h2: stage0_bytemask_comb = { {1{1'b0}},  {3{1'b1}} };
		4'h3: stage0_bytemask_comb = '1;
		endcase
	end
end
else if (DATA_WIDTH == 64) begin
	always_comb begin
		unique case (stage0_size_ff)
		4'h0: stage0_bytemask_comb = { {7{1'b0}},  {1{1'b1}} };
		4'h1: stage0_bytemask_comb = { {6{1'b0}},  {2{1'b1}} };
		4'h2: stage0_bytemask_comb = { {5{1'b0}},  {3{1'b1}} };
		4'h3: stage0_bytemask_comb = { {4{1'b0}},  {4{1'b1}} };
		4'h4: stage0_bytemask_comb = { {3{1'b0}},  {5{1'b1}} };
		4'h5: stage0_bytemask_comb = { {2{1'b0}},  {6{1'b1}} };
		4'h6: stage0_bytemask_comb = { {1{1'b0}},  {7{1'b1}} };
		4'h7: stage0_bytemask_comb = '1;
		endcase
	end
end
else if (DATA_WIDTH == 128) begin
	always_comb begin
		unique case (stage0_size_ff)
		4'h0: stage0_bytemask_comb = { {15{1'b0}},  {1{1'b1}} };
		4'h1: stage0_bytemask_comb = { {14{1'b0}},  {2{1'b1}} };
		4'h2: stage0_bytemask_comb = { {13{1'b0}},  {3{1'b1}} };
		4'h3: stage0_bytemask_comb = { {12{1'b0}},  {4{1'b1}} };
		4'h4: stage0_bytemask_comb = { {11{1'b0}},  {5{1'b1}} };
		4'h5: stage0_bytemask_comb = { {10{1'b0}},  {6{1'b1}} };
		4'h6: stage0_bytemask_comb = {  {9{1'b0}},  {7{1'b1}} };
		4'h7: stage0_bytemask_comb = {  {8{1'b0}},  {8{1'b1}} };
		4'h8: stage0_bytemask_comb = {  {7{1'b0}},  {9{1'b1}} };
		4'h9: stage0_bytemask_comb = {  {6{1'b0}}, {10{1'b1}} };
		4'ha: stage0_bytemask_comb = {  {5{1'b0}}, {11{1'b1}} };
		4'hb: stage0_bytemask_comb = {  {4{1'b0}}, {12{1'b1}} };
		4'hc: stage0_bytemask_comb = {  {3{1'b0}}, {13{1'b1}} };
		4'hd: stage0_bytemask_comb = {  {2{1'b0}}, {14{1'b1}} };
		4'he: stage0_bytemask_comb = {  {1{1'b0}}, {15{1'b1}} };
		4'hf: stage0_bytemask_comb = '1;
		endcase
	end
end

var logic stage1_valid_ff;
var logic [DATA_WIDTH-1:0] stage1_data_ff;
var logic [SIZE_WIDTH-1:0] stage1_size_ff;
var logic [DATA_WIDTH/8-1:0] stage1_bytemask_ff;
var logic stage1_sof_ff;
var logic stage1_eof_ff;

always @(posedge clock) begin
	stage1_valid_ff <= stage0_valid_ff;
	stage1_size_ff <= stage0_size_ff;
	stage1_sof_ff <= stage0_sof_ff;
	stage1_eof_ff <= stage0_eof_ff;
	stage1_data_ff <= stage0_data_shr_comb;
	stage1_bytemask_ff <= stage0_bytemask_comb;
end

/*
 * Stage1: Apply mask.
 */
wire logic [DATA_WIDTH-1:0] stage1_bitmask_comb;
generate
	for (genvar i = 0; i < DATA_WIDTH/8; i++) begin
		assign stage1_bitmask_comb[i*8 +: 8] = {8{stage1_bytemask_ff[i]}};
	end
endgenerate

var logic stage2_valid_ff;
var logic [DATA_WIDTH-1:0] stage2_data_ff;
// The size register grows by one bit to accomodate the new
// size format used (no longer 0=1 byte, 1=2 byte, ...)
var logic [SIZE_WIDTH:0] stage2_size_ff;
var logic stage2_sof_ff;
var logic stage2_eof_ff;

always @(posedge clock) begin
	stage2_valid_ff <= stage1_valid_ff;
	stage2_size_ff <= stage1_size_ff + 1;
	stage2_sof_ff <= stage1_sof_ff;
	stage2_eof_ff <= stage1_eof_ff;
	stage2_data_ff <= stage1_data_ff & stage1_bitmask_comb;
end

/*
 * Stage2: Shift left.
 */
var logic [DATA_WIDTH*2-8-1:0] stage2_data_shl_comb;
if (DATA_WIDTH == 32) begin
	always_comb begin
		unique case (stage3_size_ff[SIZE_WIDTH-1:0])
		3'h0: stage2_data_shl_comb = { 24'h0, stage2_data_ff };
		3'h1: stage2_data_shl_comb = { 16'h0, stage2_data_ff, 8'h0 };
		3'h2: stage2_data_shl_comb = {  8'h0, stage2_data_ff, 16'h0 };
		3'h3: stage2_data_shl_comb = { stage2_data_ff, 24'h0 };
		endcase
	end
end
else if (DATA_WIDTH == 64) begin
	always_comb begin
		unique case (stage3_size_ff[SIZE_WIDTH-1:0])
		3'h0: stage2_data_shl_comb = { 56'h0, stage2_data_ff };
		3'h1: stage2_data_shl_comb = { 48'h0, stage2_data_ff, 8'h0 };
		3'h2: stage2_data_shl_comb = { 40'h0, stage2_data_ff, 16'h0 };
		3'h3: stage2_data_shl_comb = { 32'h0, stage2_data_ff, 24'h0 };
		3'h4: stage2_data_shl_comb = { 24'h0, stage2_data_ff, 32'h0 };
		3'h5: stage2_data_shl_comb = { 16'h0, stage2_data_ff, 40'h0 };
		3'h6: stage2_data_shl_comb = {  8'h0, stage2_data_ff, 48'h0 };
		3'h7: stage2_data_shl_comb = { stage2_data_ff, 56'h0 };
		endcase
	end
end
else if (DATA_WIDTH == 128) begin
	always_comb begin
		unique case (stage3_size_ff[SIZE_WIDTH-1:0])
		4'h0: stage2_data_shl_comb = { 120'h0, stage2_data_ff };
		4'h1: stage2_data_shl_comb = { 112'h0, stage2_data_ff,  8'h0 };
		4'h2: stage2_data_shl_comb = { 104'h0, stage2_data_ff,  16'h0 };
		4'h3: stage2_data_shl_comb = {  96'h0, stage2_data_ff,  24'h0 };
		4'h4: stage2_data_shl_comb = {  88'h0, stage2_data_ff,  32'h0 };
		4'h5: stage2_data_shl_comb = {  80'h0, stage2_data_ff,  40'h0 };
		4'h6: stage2_data_shl_comb = {  72'h0, stage2_data_ff,  48'h0 };
		4'h7: stage2_data_shl_comb = {  64'h0, stage2_data_ff,  56'h0 };
		4'h8: stage2_data_shl_comb = {  56'h0, stage2_data_ff,  64'h0 };
		4'h9: stage2_data_shl_comb = {  48'h0, stage2_data_ff,  72'h0 };
		4'ha: stage2_data_shl_comb = {  40'h0, stage2_data_ff,  80'h0 };
		4'hb: stage2_data_shl_comb = {  32'h0, stage2_data_ff,  88'h0 };
		4'hc: stage2_data_shl_comb = {  24'h0, stage2_data_ff,  96'h0 };
		4'hd: stage2_data_shl_comb = {  16'h0, stage2_data_ff, 104'h0 };
		4'he: stage2_data_shl_comb = {   8'h0, stage2_data_ff, 112'h0 };
		4'hf: stage2_data_shl_comb = { stage2_data_ff, 120'h0 };
		endcase
	end
end

var logic stage3_valid_ff;
var logic [DATA_WIDTH*2-8-1:0] stage3_data_ff;
var logic [DATA_WIDTH*2-8-1:0] stage3_data_comb;
var logic [SIZE_WIDTH:0] stage3_size_ff;
var logic [SIZE_WIDTH:0] stage3_size_comb;
var logic stage3_sof_ff;
var logic stage3_sof_comb;
var logic stage3_eof_ff;
var logic poisoned;

assign o_valid = stage3_valid_ff;
assign o_data = stage3_data_ff;
assign o_sof = stage3_sof_ff;
assign o_eof = stage3_eof_ff;

always_comb begin
	if (!resetn) begin
		stage3_data_comb = '0;
		stage3_size_comb = '0;
		stage3_sof_comb = 1'b0;
	end
	else begin
		stage3_data_comb = stage3_data_ff;
		stage3_size_comb = stage3_size_ff;
		stage3_sof_comb = stage3_sof_ff;

		if (stage3_valid_ff) begin
			stage3_data_comb = { {DATA_WIDTH{1'b0}}, stage3_data_ff[DATA_WIDTH +: DATA_WIDTH-8] };
			stage3_size_comb[SIZE_WIDTH] = 1'b0;
			stage3_sof_comb = 1'b0;
		end
		if (poisoned) begin
			stage3_size_comb = '0;
		end
		else if (stage2_valid_ff) begin
			stage3_sof_comb = stage3_sof_comb | stage2_sof_ff;
			stage3_data_comb = stage3_data_comb | stage2_data_shl_comb;
			stage3_size_comb = stage3_size_comb + stage2_size_ff;
		end
	end
end

always @(posedge clock) begin
	stage3_data_ff <= stage3_data_comb;
	stage3_size_ff <= stage3_size_comb;
	stage3_sof_ff <= stage3_sof_comb;
	poisoned <= 1'b0;
	stage3_valid_ff <= 1'b0;

	if (!resetn) begin
	end
	else begin
		if (poisoned) begin
			// If there is anything in the output buffer,
			// flush it out now.
			if (|stage3_size_ff[SIZE_WIDTH-1:0]) begin
				stage3_valid_ff <= 1'b1;
				stage3_eof_ff <= 1'b1;
			end
		end
		else if (stage2_valid_ff) begin
			poisoned <= stage2_eof_ff;
			// If there is at least a full output buffer,
			// mark the output as valid for the next cycle.
			stage3_valid_ff <= stage3_size_comb[SIZE_WIDTH];
			// This is the end of frame if the last input data was
			// marked as such and there is nothing left in the
			// buffer after the next cycle.
			stage3_eof_ff <= stage2_eof_ff & ~|stage3_size_comb[SIZE_WIDTH-1:0];
		end
	end
end

assign trace_atf_bds.stage0_data_shr_comb = stage0_data_shr_comb;
assign trace_atf_bds.stage0_bytemask_comb = stage0_bytemask_comb;

assign trace_atf_bds.stage1_valid_ff = stage1_valid_ff;
assign trace_atf_bds.stage1_data_ff = stage1_data_ff;
assign trace_atf_bds.stage1_size_ff = stage1_size_ff;
assign trace_atf_bds.stage1_bytemask_ff = stage1_bytemask_ff;
assign trace_atf_bds.stage1_sof_ff = stage1_sof_ff;
assign trace_atf_bds.stage1_eof_ff = stage1_eof_ff;
assign trace_atf_bds.stage1_bitmask_comb = stage1_bitmask_comb;

assign trace_atf_bds.stage2_valid_ff = stage2_valid_ff;
assign trace_atf_bds.stage2_data_ff = stage2_data_ff;
assign trace_atf_bds.stage2_size_ff = stage2_size_ff;
assign trace_atf_bds.stage2_sof_ff = stage2_sof_ff;
assign trace_atf_bds.stage2_eof_ff = stage2_eof_ff;
assign trace_atf_bds.stage2_data_shl_comb = stage2_data_shl_comb;

assign trace_atf_bds.stage3_valid_ff = stage3_valid_ff;
assign trace_atf_bds.stage3_sof_ff = stage3_sof_ff;
assign trace_atf_bds.stage3_sof_comb = stage3_sof_comb;
assign trace_atf_bds.stage3_eof_ff = stage3_eof_ff;
assign trace_atf_bds.stage3_data_ff = stage3_data_ff;
assign trace_atf_bds.stage3_data_comb = stage3_data_comb;
assign trace_atf_bds.stage3_size_ff = stage3_size_ff;
assign trace_atf_bds.stage3_size_comb = stage3_size_comb;
assign trace_atf_bds.poisoned = poisoned;

endmodule
