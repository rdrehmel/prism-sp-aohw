/*
 * Copyright (c) 2024 Robert Drehmel
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
module prism_counter#(
	parameter int NIDS,
	parameter int ID_WIDTH = $clog2(NIDS),
	parameter int MAX_VALUE,
	parameter int VALUE_WIDTH = $clog2(MAX_VALUE+1)
)
(
	input wire logic clock,
	input wire logic resetn,

	input wire logic [ID_WIDTH-1:0] monitor_id,
	input wire logic monitor_reset,
	output wire logic [VALUE_WIDTH-1:0] monitor_count,

	input wire logic [ID_WIDTH-1:0] op_id,
	input wire logic op_incr
);

var logic [VALUE_WIDTH-1:0] values [NIDS];
assign monitor_count = values[monitor_id];

always_ff @(posedge clock) begin
	if (!resetn) begin
		for (int i = 0; i < NIDS; i++) begin
			values[i] <= '0;
		end
	end
	else begin
		if (op_incr) begin
			values[op_id] <= values[op_id] + 1;
		end
		if (monitor_reset) begin
			values[monitor_id] <= '0;
		end
	end
end

endmodule
