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
module prism_sp_puzzle_hw_gem_irq (
	input wire logic clock,
	input wire logic resetn,

	mmr_intr_interface.master mmr_i,

	fifo_read_interface.master fifo_r
);

always_ff @(posedge clock) begin
	fifo_r.rd_en <= 1'b0;
	mmr_i.isr_pulses[0] <= '0;

	if (!resetn) begin
	end
	else begin
		if (!fifo_r.empty) begin
			fifo_r.rd_en <= 1'b1;
			mmr_i.isr_pulses[0] <= 1'b1;
		end
	end
end

endmodule
