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
interface prism_packinstr_interface#(
	// Number of AXI beats/transfers
	parameter int NTRANSFERS,
	parameter int TRANSFER_WIDTH = $clog2(NTRANSFERS),
	parameter int IN_DATA_WIDTH,
	parameter int NELEMENTS,
	parameter int ELEMENT_WIDTH = $clog2(NELEMENTS),
	parameter int OUT_DATA_WIDTH
);

// transfer is the current AXI beat#.
logic [TRANSFER_WIDTH-1:0] transfer;
// din is the current AXI data.
logic [IN_DATA_WIDTH-1:0] din;

// element is the element index in which to write.
logic [ELEMENT_WIDTH-1:0] element;
// dout is the data to write.
logic [OUT_DATA_WIDTH-1:0] dout;
// we is the write strobe for the data.
logic [(OUT_DATA_WIDTH/8)-1:0] we;

modport master(
	output transfer,
	output din,
	input element,
	input dout,
	input we
);
modport slave(
	input transfer,
	input din,
	output element,
	output dout,
	output we
);
endinterface
