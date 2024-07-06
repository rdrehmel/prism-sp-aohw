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
module mmr_intr_interface_connect(
	mmr_intr_interface.master m,
	mmr_intr_interface.slave s
);

for (genvar i = 0; i < m.N; i++) begin
	assign s.imr[i] = m.imr[i];
	assign s.isr[i] = m.isr[i];
	assign m.isr_pulses[i] = s.isr_pulses[i];
end

endmodule
