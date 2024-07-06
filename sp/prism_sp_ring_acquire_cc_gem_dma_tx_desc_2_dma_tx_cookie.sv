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
module prism_sp_ring_acquire_cc_gem_dma_tx_desc_2_dma_tx_cookie(
	prism_sp_ring_acquire_cookie_convert_interface.slave conv
);

wire gem_dma_tx_desc_t desc;
assign desc = conv.data_in;

wire dma_tx_cookie_t cookie;
assign conv.data_out = cookie;

assign cookie.addr = conv.dma_desc_cur;
assign cookie.size = desc.size;
assign cookie.nocrc = desc.nocrc;
assign cookie.eof = desc.eof;
assign cookie.wrap = desc.wrap;
assign cookie.data_addr[31:0] = desc.addrl;
if (DMA_DESC_64BITADDR) begin
	assign cookie.data_addr[39:32] = desc.addrh;
end

endmodule
