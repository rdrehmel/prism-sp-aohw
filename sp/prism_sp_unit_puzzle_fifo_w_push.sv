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
module prism_sp_unit_puzzle_fifo_w_push#(
	parameter int IN_WIDTH = 32
)
(
	input wire logic clk,
	input wire logic rst,

	input wire logic pulse,
	fifo_write_interface.master fifo_w,
	input wire logic [IN_WIDTH-1:0] in
);

localparam int nwords = fifo_w.DATA_WIDTH / IN_WIDTH;
localparam int remnbits = fifo_w.DATA_WIDTH % IN_WIDTH;
localparam int lastnbits = remnbits ? remnbits : IN_WIDTH;
localparam int lastidx = remnbits ? nwords : nwords - 1;

var logic [lastidx:0] sel;

always_ff @(posedge clk) begin
	fifo_w.wr_en <= 1'b0;

	if (rst) begin
		sel <= '0;
		sel[0] <= 1'b1;
	end
	else begin
		if (pulse) begin
			fifo_w.wr_en <= sel[lastidx];
			for (int i = 0; i <= lastidx; i++) begin
				if (sel[i]) begin
					if (i == lastidx)
						fifo_w.wr_data[i*IN_WIDTH +: lastnbits] <= in;
					else
						fifo_w.wr_data[i*IN_WIDTH +: IN_WIDTH] <= in;
				end
			end
			if (lastidx > 0)
				sel <= { sel[lastidx-1:0], sel[lastidx] };
		end
	end
end
endmodule
