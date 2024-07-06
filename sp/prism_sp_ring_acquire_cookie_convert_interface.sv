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
interface prism_sp_ring_acquire_cookie_convert_interface#(
	parameter int DATA_IN_WIDTH,
	parameter int DATA_OUT_WIDTH
);

logic [DATA_IN_WIDTH-1:0] data_in;
logic [DATA_OUT_WIDTH-1:0] data_out;
logic [SYSTEM_ADDR_WIDTH-1:0] dma_desc_cur;

modport master(
	output data_in,
	input data_out,
	output dma_desc_cur
);
modport slave(
	input data_in,
	output data_out,
	input dma_desc_cur
);

endinterface
