/*
 * Copyright (c) 2023-2024 Robert Drehmel
 *
 * Licensed under the Apache License), .s(Version 2.0 (the "License"));
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing), .s(software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND), .s(either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
module prism_sp_puzzle_fifo_mixer
#(
	parameter int NFIFOS = 8,
	parameter int ENABLE_PUZZLE_FIFO_R [NFIFOS],
	parameter int ENABLE_PUZZLE_FIFO_W [NFIFOS]
)
(
	input wire logic clock,
	input wire logic resetn,

	fifo_read_interface.slave puzzle_hw_fifo_r_0,
	fifo_write_interface.slave puzzle_hw_fifo_w_0,
	fifo_read_interface.slave puzzle_hw_fifo_r_1,
	fifo_write_interface.slave puzzle_hw_fifo_w_1,
	fifo_read_interface.slave puzzle_hw_fifo_r_2,
	fifo_write_interface.slave puzzle_hw_fifo_w_2,
	fifo_read_interface.slave puzzle_hw_fifo_r_3,
	fifo_write_interface.slave puzzle_hw_fifo_w_3,

	fifo_read_interface.slave puzzle_sw_fifo_r_0,
	fifo_write_interface.slave puzzle_sw_fifo_w_0,
	fifo_read_interface.slave puzzle_sw_fifo_r_1,
	fifo_write_interface.slave puzzle_sw_fifo_w_1,
	fifo_read_interface.slave puzzle_sw_fifo_r_2,
	fifo_write_interface.slave puzzle_sw_fifo_w_2,
	fifo_read_interface.slave puzzle_sw_fifo_r_3,
	fifo_write_interface.slave puzzle_sw_fifo_w_3,

	fifo_read_interface.master puzzle_fifo_r_0,
	fifo_write_interface.master puzzle_fifo_w_0,
	fifo_read_interface.master puzzle_fifo_r_1,
	fifo_write_interface.master puzzle_fifo_w_1,
	fifo_read_interface.master puzzle_fifo_r_2,
	fifo_write_interface.master puzzle_fifo_w_2,
	fifo_read_interface.master puzzle_fifo_r_3,
	fifo_write_interface.master puzzle_fifo_w_3
);

if (ENABLE_PUZZLE_FIFO_R[0] == 0) begin
	fifo_read_interface_connect(.m(puzzle_fifo_r_0), .s(puzzle_hw_fifo_r_0));
end
else if (ENABLE_PUZZLE_FIFO_R[0] == 1) begin
	fifo_read_interface_connect(.m(puzzle_fifo_r_0), .s(puzzle_sw_fifo_r_0));
end

if (ENABLE_PUZZLE_FIFO_W[0] == 0) begin
	fifo_write_interface_connect(.m(puzzle_fifo_w_0), .s(puzzle_hw_fifo_w_0));
end
else if (ENABLE_PUZZLE_FIFO_W[0] == 1) begin
	fifo_write_interface_connect(.m(puzzle_fifo_w_0), .s(puzzle_sw_fifo_w_0));
end

if (ENABLE_PUZZLE_FIFO_R[1] == 0) begin
	fifo_read_interface_connect(.m(puzzle_fifo_r_1), .s(puzzle_hw_fifo_r_1));
end
else if (ENABLE_PUZZLE_FIFO_R[1] == 1) begin
	fifo_read_interface_connect(.m(puzzle_fifo_r_1), .s(puzzle_sw_fifo_r_1));
end

if (ENABLE_PUZZLE_FIFO_W[1] == 0) begin
	fifo_write_interface_connect(.m(puzzle_fifo_w_1), .s(puzzle_hw_fifo_w_1));
end
else if (ENABLE_PUZZLE_FIFO_W[1] == 1) begin
	fifo_write_interface_connect(.m(puzzle_fifo_w_1), .s(puzzle_sw_fifo_w_1));
end

if (ENABLE_PUZZLE_FIFO_R[2] == 0) begin
	fifo_read_interface_connect(.m(puzzle_fifo_r_2), .s(puzzle_hw_fifo_r_2));
end
else if (ENABLE_PUZZLE_FIFO_R[2] == 1) begin
	fifo_read_interface_connect(.m(puzzle_fifo_r_2), .s(puzzle_sw_fifo_r_2));
end

if (ENABLE_PUZZLE_FIFO_W[2] == 0) begin
	fifo_write_interface_connect(.m(puzzle_fifo_w_2), .s(puzzle_hw_fifo_w_2));
end
else if (ENABLE_PUZZLE_FIFO_W[2] == 1) begin
	fifo_write_interface_connect(.m(puzzle_fifo_w_2), .s(puzzle_sw_fifo_w_2));
end

if (ENABLE_PUZZLE_FIFO_R[3] == 0) begin
	fifo_read_interface_connect(.m(puzzle_fifo_r_3), .s(puzzle_hw_fifo_r_3));
end
else if (ENABLE_PUZZLE_FIFO_R[3] == 1) begin
	fifo_read_interface_connect(.m(puzzle_fifo_r_3), .s(puzzle_sw_fifo_r_3));
end

if (ENABLE_PUZZLE_FIFO_W[3] == 0) begin
	fifo_write_interface_connect(.m(puzzle_fifo_w_3), .s(puzzle_hw_fifo_w_3));
end
else if (ENABLE_PUZZLE_FIFO_W[3] == 1) begin
	fifo_write_interface_connect(.m(puzzle_fifo_w_3), .s(puzzle_sw_fifo_w_3));
end

endmodule
