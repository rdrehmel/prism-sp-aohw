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
module prism_sp_ring_acquire_cc_gem_dma_rx_desc_2_dma_rx_cookie(
	prism_sp_ring_acquire_cookie_convert_interface.slave conv
);

wire gem_dma_rx_desc_t desc;
assign desc = conv.data_in;

wire dma_rx_cookie_t cookie;
assign conv.data_out = cookie;

assign cookie.addr = conv.dma_desc_cur;
// The 2 LSB of the ADDRL field are used for the
// WRAP and VALID bits.
// the gem_dma_rx_desc_t type does not include these
// bits in the .addrl field, so we have to add them
// to get the correct byte address.
assign cookie.data_addr[31:0] = { desc.addrl, 2'b00 };
if (DMA_DESC_64BITADDR) begin
	assign cookie.data_addr[39:32] = desc.addrh;
end
assign cookie.wrap = desc.wrap;

endmodule
