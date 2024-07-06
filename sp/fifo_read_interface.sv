/*
 * Copyright (c) 2021 Robert Drehmel
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
interface fifo_read_interface#(
	parameter int DATA_WIDTH = 32,
	parameter int DATA_COUNT_WIDTH = 1
);

logic clock;
logic reset;
logic [DATA_WIDTH-1:0] rd_data;
logic rd_en;
logic empty;
logic almost_empty;
logic [DATA_COUNT_WIDTH-1:0] rd_data_count;

modport master(
	output clock,
	output reset,
	input rd_data,
	output rd_en,
	input empty,
	input almost_empty,
	input rd_data_count
);
modport slave(
	input clock,
	input reset,
	output rd_data,
	input rd_en,
	output empty,
	output almost_empty,
	output rd_data_count
);

modport inputs(
	input clock,
	input reset,
	input rd_data,
	input rd_en,
	input empty,
	input almost_empty,
	input rd_data_count
);
modport outputs(
	output clock,
	output reset,
	output rd_data,
	output rd_en,
	output empty,
	output almost_empty,
	output rd_data_count
);

endinterface
