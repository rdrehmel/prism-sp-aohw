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
module prism_sp_puzzle_hw_gem_sink
(
	input wire logic clock,
	input wire logic resetn,

	fifo_read_interface.master i_cookie_fifo_r
);

typedef enum logic {
	STATE_FETCH_COOKIE,
	STATE_FIFO_CYCLE
} state_t;
var state_t state;

always_ff @(posedge clock) begin
	// Unpulse
	i_cookie_fifo_r.rd_en <= 1'b0;

	if (!resetn) begin
		state <= STATE_FETCH_COOKIE;
	end
	else begin
		case (state)
		STATE_FETCH_COOKIE: begin
			if (!i_cookie_fifo_r.empty) begin
				i_cookie_fifo_r.rd_en <= 1'b1;
				state <= STATE_FIFO_CYCLE;
			end
		end
		STATE_FIFO_CYCLE: begin
			state <= STATE_FETCH_COOKIE;
		end
		endcase
	end
end

endmodule
