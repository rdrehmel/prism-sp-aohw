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
interface mmr_trigger_interface#(
	parameter int N,
	parameter int WIDTH
);

logic [WIDTH-1:0] tsr [N];
logic [WIDTH-1:0] tsr_invpulses [N];

modport master(
	input tsr,
	output tsr_invpulses
);
modport slave(
	output tsr,
	input tsr_invpulses
);

endinterface
