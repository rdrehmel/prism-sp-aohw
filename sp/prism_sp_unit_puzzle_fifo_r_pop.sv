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
module prism_sp_unit_puzzle_fifo_r_pop#(
	parameter int OUT_WIDTH = 32
)
(
	input wire logic clk,
	input wire logic rst,

	input wire logic pulse,
	fifo_read_interface.master fifo_r,
	output var logic [OUT_WIDTH-1:0] out
);

localparam int nwords = fifo_r.DATA_WIDTH / OUT_WIDTH;
localparam int remnbits = fifo_r.DATA_WIDTH % OUT_WIDTH;
localparam int lastnbits = remnbits ? remnbits : OUT_WIDTH;
localparam int lastidx = remnbits ? nwords : nwords - 1;

var logic [lastidx:0] sel;

always_ff @(posedge clk) begin
	fifo_r.rd_en <= 1'b0;

	if (rst) begin
		sel <= '0;
		sel[0] <= 1'b1;
	end
	else begin
		if (pulse) begin
			fifo_r.rd_en <= sel[lastidx];
			if (lastidx > 0)
				sel <= { sel[lastidx-1:0], sel[lastidx] };
		end
	end
end

if (lastidx == 0) begin
	assign out = fifo_r.rd_data;
end
else if (lastidx == 1) begin
	always_comb begin
		out = '0;
		unique case (sel)
		2'b01: out = fifo_r.rd_data[(0*OUT_WIDTH) +: OUT_WIDTH];
		2'b10: out = OUT_WIDTH'(fifo_r.rd_data[(1*OUT_WIDTH) +: lastnbits]);
		endcase
	end
end
else if (lastidx == 2) begin
	always_comb begin
		out = '0;
		unique case (sel)
		3'b001: out = fifo_r.rd_data[(0*OUT_WIDTH) +: OUT_WIDTH];
		3'b010: out = fifo_r.rd_data[(1*OUT_WIDTH) +: OUT_WIDTH];
		3'b100: out = OUT_WIDTH'(fifo_r.rd_data[(2*OUT_WIDTH) +: lastnbits]);
		endcase
	end
end
else if (lastidx == 3) begin
	always_comb begin
		out = '0;
		unique case (sel)
		4'b0001: out = fifo_r.rd_data[(0*OUT_WIDTH) +: OUT_WIDTH];
		4'b0010: out = fifo_r.rd_data[(1*OUT_WIDTH) +: OUT_WIDTH];
		4'b0100: out = fifo_r.rd_data[(2*OUT_WIDTH) +: OUT_WIDTH];
		4'b1000: out = OUT_WIDTH'(fifo_r.rd_data[(3*OUT_WIDTH) +: lastnbits]);
		endcase
	end
end
else if (lastidx == 4) begin
	always_comb begin
		out = '0;
		unique case (sel)
		5'b00001: out = fifo_r.rd_data[(0*OUT_WIDTH) +: OUT_WIDTH];
		5'b00010: out = fifo_r.rd_data[(1*OUT_WIDTH) +: OUT_WIDTH];
		5'b00100: out = fifo_r.rd_data[(2*OUT_WIDTH) +: OUT_WIDTH];
		5'b01000: out = fifo_r.rd_data[(3*OUT_WIDTH) +: OUT_WIDTH];
		5'b10000: out = OUT_WIDTH'(fifo_r.rd_data[(4*OUT_WIDTH) +: lastnbits]);
		endcase
	end
end
else begin
	$fatal("fifo_r.DATA_WIDTH=%d OUT_WIDTH=%d lastidx=%d is not supported.\n",
		fifo_r.DATA_WIDTH, OUT_WIDTH, lastidx);
end
endmodule
