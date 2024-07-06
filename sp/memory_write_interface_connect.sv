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
module memory_write_interface_connect(
	memory_write_interface.master m,
	memory_write_interface.slave s
);

assign m.addr = s.addr;
assign m.len = s.len;
assign m.start = s.start;
assign s.busy = m.busy;
assign s.done = m.done;
assign s.error = m.error;

endmodule
