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
interface prism_axi_calc_interface #(
	parameter int AXI_ADDR_WIDTH,
	parameter int AXI_DATA_WIDTH
);

localparam OFFSET_WIDTH = $clog2(AXI_DATA_WIDTH/8);

logic i_valid;
logic [AXI_ADDR_WIDTH-1:0] i_address;
logic [15:0] i_length;
logic i_axhshake;

logic o_valid;
logic [AXI_ADDR_WIDTH-1:0] o_axaddr;
logic [7:0] o_axlen;
/*
 * The format of o_last_beat_size is (number_of_bytes - 1).
 */
logic [OFFSET_WIDTH-1:0] o_last_beat_size;
logic o_is_last_burst;

modport master(
	output i_valid,
	output i_address,
	output i_length,
	output i_axhshake,
	input o_valid,
	input o_axaddr,
	input o_axlen,
	input o_last_beat_size,
	input o_is_last_burst
);
modport slave(
	input i_valid,
	input i_address,
	input i_length,
	input i_axhshake,
	output o_valid,
	output o_axaddr,
	output o_axlen,
	output o_last_beat_size,
	output o_is_last_burst
);

endinterface
