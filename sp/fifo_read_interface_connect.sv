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
module fifo_read_interface_connect(
	fifo_read_interface.master m,
	fifo_read_interface.slave s
);

assign m.clock = s.clock;
assign m.reset = s.reset;
assign s.rd_data = m.rd_data;
assign m.rd_en = s.rd_en;
assign s.empty = m.empty;
assign s.almost_empty = m.almost_empty;
assign s.rd_data_count = m.rd_data_count;

endmodule
