/*
 * Copyright (c) 2023-2024 Robert Drehmel
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
import prism_sp_config::*;

module prism_sp_tx_checksum #(
	parameter int DATA_WIDTH
)
(
	input wire logic clock,
	input wire logic resetn,

	input wire logic i_valid,
	input wire logic [DATA_WIDTH-1:0] i_data,
	input wire logic i_sof,
	input wire logic i_eof,

	fifo_write_interface.master tx_csum_fifo_w,

	output trace_checksum_t trace_csum
);

localparam int OFFSET_WIDTH = $clog2(DATA_WIDTH / 8);
localparam int PACKET_ETH_TYPE_OFF = 12;
localparam int PACKET_IPV4_HDR_OFF = 14;
localparam logic [15:0] ETH_TYPE_IPV4 = 16'h0800;
localparam logic [7:0] IP_PROTO_TCP = 8'h06;
localparam logic [7:0] IP_PROTO_UDP = 8'h11;
localparam int NSTAGES = 3;

typedef enum logic [1:0] {
	IP_STATE_IDLE,
	IP_STATE_WORD1,
	IP_STATE_WORD2
} ip_state_t;
var ip_state_t ip_state;

typedef enum logic [2:0] {
	L4_STATE_IDLE,
	L4_STATE_WORD1,
	L4_STATE_TCPWORD2,
	L4_STATE_TCPWORD3,
	L4_STATE_UDPWORD2,
	L4_STATE_WORDX
} l4_state_t;
var l4_state_t l4_state;

function logic [15:0] reverse(input logic [15:0] data);
	return { data[7:0], data[15:8] };
endfunction

/*
 * -------------------------------------------------------------------
 * This process builds the pipeline for valid, sof, and eof.
 */
var logic pipe_valid [NSTAGES];
var logic pipe_sof [NSTAGES];
var logic pipe_eof [NSTAGES];
always_ff @(posedge clock) begin
	for (int i = 1; i < NSTAGES; i++) begin
		pipe_valid[i] <= pipe_valid[i - 1];
		pipe_sof[i] <= pipe_sof[i - 1];
		pipe_eof[i] <= pipe_eof[i - 1];
	end
	pipe_valid[0] <= i_valid;
	pipe_sof[0] <= i_sof;
	pipe_eof[0] <= i_eof;
end
/*
 * -------------------------------------------------------------------
 * This process handles data from the 0th word (0-based).
 */
var logic [15:0] cyc0_lev0_ff;
always_ff @(posedge clock) begin
	cyc0_lev0_ff <= reverse(i_data[7*16 +: 16]);
	// cyc0_lev0_ff is consumed by
	//   l4_cyc1_lev0_0_ff
	// and
	//   ip_cyc1_lev0_ff
	// No need to push it furhter down the pipeline.
end
/*
 * -------------------------------------------------------------------
 * This process handles assorted values.
 */
var logic [1:0] pipe_eth_type [NSTAGES];
var logic [1:0] pipe_ip_proto [NSTAGES];
always_ff @(posedge clock) begin
	for (int i = 1; i < NSTAGES; i++) begin
		pipe_eth_type[i] <= pipe_eth_type[i - 1];
	end
	case (reverse(i_data[6*16+:16]))
	ETH_TYPE_IPV4: pipe_eth_type[0] <= 2'b01;
	default: pipe_eth_type[0] <= 2'b00;
	endcase

	for (int i = 1; i < NSTAGES; i++) begin
		pipe_ip_proto[i] <= pipe_ip_proto[i - 1];
	end
	case (i_data[7*8+:8])
	IP_PROTO_TCP: pipe_ip_proto[0] <= 2'b01;
	IP_PROTO_UDP: pipe_ip_proto[0] <= 2'b10;
	default: pipe_ip_proto[0] <= 2'b00;
	endcase
end
/*
 * -------------------------------------------------------------------
 * This process handles data from the 1st word (0-based) for IP.
 */
var logic [16:0] ip_cyc1_lev0_ff;
var logic [17:0] ip_cyc1_lev1_ff;
var logic [18:0] ip_cyc1_lev2_ff;
always_ff @(posedge clock) begin
	ip_cyc1_lev0_ff <= ($bits(ip_cyc1_lev0_ff))'(reverse(i_data[5*16 +: 16])) + cyc0_lev0_ff;
	ip_cyc1_lev1_ff <= ($bits(ip_cyc1_lev1_ff))'(ip_cyc1_lev0_ff) + lev0_add_ff[3];
	ip_cyc1_lev2_ff <= ($bits(ip_cyc1_lev2_ff))'(ip_cyc1_lev1_ff) + lev1_add_ff[0];
end
/*
 * -------------------------------------------------------------------
 * This process handles data from the 2nd word (0-based) for IP.
 */
var logic [15:0] ip_cyc2_lev0_ff;
var logic [15:0] ip_cyc2_lev1_ff;
var logic [15:0] ip_cyc2_lev2_ff;
always_ff @(posedge clock) begin
	ip_cyc2_lev0_ff <= reverse(i_data[0*16 +: 16]);
	ip_cyc2_lev1_ff <= ip_cyc2_lev0_ff;
	ip_cyc2_lev2_ff <= ip_cyc2_lev1_ff;
end
/*
 * -------------------------------------------------------------------
 * This process handles data from the 1st word (0-based) for UDP/TCP.
 */
var logic [15:0] l4_cyc1_lev0_0_ff;
var logic [16:0] l4_cyc1_lev0_1_ff;
var logic [15:0] l4_cyc1_lev1_0_ff;
var logic [17:0] l4_cyc1_lev1_1_ff;
var logic [18:0] l4_cyc1_lev2_ff;
always_ff @(posedge clock) begin
	l4_cyc1_lev0_0_ff <= (reverse(i_data[0*16 +: 16]) - { 10'b0000000000, cyc0_lev0_ff[8+:4], 2'b00 });
	l4_cyc1_lev0_1_ff <= ($bits(l4_cyc1_lev0_1_ff))'(i_data[7*8 +: 8]) + reverse(i_data[5*16 +: 16]);

	l4_cyc1_lev1_0_ff <= l4_cyc1_lev0_0_ff;
	l4_cyc1_lev1_1_ff <= ($bits(l4_cyc1_lev1_1_ff))'(l4_cyc1_lev0_1_ff) + lev0_add_ff[3];

	l4_cyc1_lev2_ff <= ($bits(l4_cyc1_lev2_ff))'(l4_cyc1_lev1_0_ff) + l4_cyc1_lev1_1_ff;
end
/*
 * -------------------------------------------------------------------
 * This process handles data from the 2nd word (0-based).
 */
var logic [15:0] udp_cyc2_lev0_ff;
var logic [16:0] udp_cyc2_lev1_ff;
var logic [17:0] udp_cyc2_lev2_ff;
always_ff @(posedge clock) begin
	udp_cyc2_lev0_ff <= reverse(i_data[5*16 +: 16]);
	udp_cyc2_lev1_ff <= ($bits(udp_cyc2_lev1_ff))'(udp_cyc2_lev0_ff) + lev0_add_ff[3];
	udp_cyc2_lev2_ff <= ($bits(udp_cyc2_lev2_ff))'(udp_cyc2_lev1_ff) + lev1_add_ff[0];
end
/*
 * -------------------------------------------------------------------
 * This process handles data from the 3rd word (0-based).
 */
var logic [15:0] tcp_cyc3_lev0_ff;
var logic [16:0] tcp_cyc3_lev1_ff;
var logic [17:0] tcp_cyc3_lev2_ff;
always_ff @(posedge clock) begin
	tcp_cyc3_lev0_ff <= reverse(i_data[0*16 +: 16]);
	tcp_cyc3_lev1_ff <= ($bits(tcp_cyc3_lev1_ff))'(tcp_cyc3_lev0_ff) + lev0_add_ff[1];
	tcp_cyc3_lev2_ff <= ($bits(tcp_cyc3_lev2_ff))'(tcp_cyc3_lev1_ff) + lev1_add_ff[1];
end
/*
 * -------------------------------------------------------------------
 */
localparam int LEV0N = (DATA_WIDTH / 16) / 2;
localparam int LEV1N = LEV0N / 2;
localparam int LEV2N = LEV1N / 2;
localparam int LEV0_RES_WIDTH = $clog2(((1 << 16) - 1) * 2);
localparam int LEV1_RES_WIDTH = $clog2(((1 << LEV0_RES_WIDTH) - 1 ) * 2);
localparam int LEV2_RES_WIDTH = $clog2(((1 << LEV1_RES_WIDTH) - 1 ) * 2);

wire logic [LEV0_RES_WIDTH-1:0] lev0_add [LEV0N];
for (genvar i = 0; i < LEV0N; i++) begin
	assign lev0_add[i] = ($bits(lev0_add[i]))'(reverse(i_data[(i*2)*16 +: 16])) + reverse(i_data[(i*2+1)*16 +: 16]);
end

wire logic [LEV1_RES_WIDTH-1:0] lev1_add [LEV1N];
for (genvar i = 0; i < LEV1N; i++) begin
	assign lev1_add[i] = ($bits(lev1_add[i]))'(lev0_add_ff[i*2]) + lev0_add_ff[i*2+1];
end

wire logic [LEV2_RES_WIDTH-1:0] lev2_add [LEV2N];
for (genvar i = 0; i < LEV2N; i++) begin
	assign lev2_add[i] = ($bits(lev2_add[i]))'(lev1_add_ff[i*2]) + lev1_add_ff[i*2+1];
end

var logic [LEV0_RES_WIDTH-1:0] lev0_add_ff [LEV0N];
var logic [LEV1_RES_WIDTH-1:0] lev1_add_ff [LEV1N];
var logic [LEV2_RES_WIDTH-1:0] lev2_add_ff [LEV2N];

always_ff @(posedge clock) begin
	for (int i = 0; i < LEV0N; i++) begin
		lev0_add_ff[i] <= lev0_add[i];
	end
	for (int i = 0; i < LEV1N; i++) begin
		lev1_add_ff[i] <= lev1_add[i];
	end
	for (int i = 0; i < LEV2N; i++) begin
		lev2_add_ff[i] <= lev2_add[i];
	end
end
/*
 * -------------------------------------------------------------------
 */

var logic [SP_CSUM_IP_SUM_WIDTH-1:0] ip_sum;
var logic [SP_CSUM_L4_SUM_WIDTH-1:0] l4_sum;
var logic [1:0] eth_type;
var logic [1:0] ip_proto;
var logic commit_checksum;

wire logic p_valid = pipe_valid[NSTAGES-1];
wire logic p_sof = pipe_sof[NSTAGES-1];
wire logic p_eof = pipe_eof[NSTAGES-1];

// 17 bits because these might have one carry bit still.
wire logic [16:0] folded_ip_sum = ip_sum[15:0] + 16'(ip_sum[$bits(ip_sum)-1:16]);
wire logic [16:0] folded_l4_sum = l4_sum[15:0] + 16'(l4_sum[$bits(l4_sum)-1:16]);

always_ff @(posedge clock) begin
	tx_csum_fifo_w.wr_en <= 1'b0;

	if (!resetn) begin
		ip_state <= IP_STATE_IDLE;
		l4_state <= L4_STATE_IDLE;
		commit_checksum <= 1'b0;
	end
	else begin
		// This will be executed in the same clock cycle as
		// the next start of frame when data is presented
		// with 0 cycle delay.
		if (commit_checksum) begin
			commit_checksum <= 1'b0;
			tx_csum_fifo_w.wr_en <= 1'b1;

			// Set the layer 3 checksum type.
			// 00: None
			// 01: IPv4
			tx_csum_fifo_w.wr_data[0 +: 2] <= eth_type;
			tx_csum_fifo_w.wr_data[2 +: 16] <= ~(folded_ip_sum[15:0] + 16'(folded_ip_sum[16]));

			// Set the layer 4 checksum type.
			// 00: None
			// 01: TCP
			// 10: UDP
			tx_csum_fifo_w.wr_data[2+16 +: 2] <= ip_proto;
			tx_csum_fifo_w.wr_data[2+16+2 +: 16] <= ~(folded_l4_sum[15:0] + 16'(folded_l4_sum[16]));
		end

		if (p_valid) begin
			if (p_eof) begin
				// Commit checksum.
				commit_checksum <= 1'b1;
			end

			case (ip_state)
			IP_STATE_IDLE: begin
				if (p_sof) begin
					eth_type <= pipe_eth_type[NSTAGES-1];
					ip_state <= IP_STATE_WORD1;
				end
			end
			IP_STATE_WORD1: begin
				ip_sum <= ($bits(ip_sum))'(ip_cyc1_lev2_ff);
				ip_state <= IP_STATE_WORD2;
			end
			IP_STATE_WORD2: begin
				ip_sum <= ip_sum + ($bits(ip_sum))'(ip_cyc2_lev2_ff);
				// Finish up.
				ip_state <= IP_STATE_IDLE;
			end
			endcase

			if (p_eof) begin
				ip_state <= IP_STATE_IDLE;
			end

			case (l4_state)
			L4_STATE_IDLE: begin
				if (p_sof) begin
					l4_state <= L4_STATE_WORD1;
				end
			end
			L4_STATE_WORD1: begin
				ip_proto <= pipe_ip_proto[NSTAGES-1];

				if (pipe_ip_proto[NSTAGES-1] == 2'b01) begin
					// If TCP
					l4_state <= L4_STATE_TCPWORD2;
				end
				else if (pipe_ip_proto[NSTAGES-1] == 2'b10) begin
					// If UDP
					l4_state <= L4_STATE_UDPWORD2;
				end
				else begin
					l4_state <= L4_STATE_IDLE;
				end

				l4_sum <= ($bits(l4_sum))'(l4_cyc1_lev2_ff);
			end
			L4_STATE_UDPWORD2: begin
				l4_sum <= l4_sum + ($bits(l4_sum))'(udp_cyc2_lev2_ff);
				l4_state <= L4_STATE_WORDX;
			end
			L4_STATE_TCPWORD2: begin
				l4_sum <= l4_sum + ($bits(l4_sum))'(lev2_add_ff[0]);
				l4_state <= L4_STATE_TCPWORD3;
			end
			L4_STATE_TCPWORD3: begin
				l4_sum <= l4_sum + ($bits(l4_sum))'(tcp_cyc3_lev2_ff);
				l4_state <= L4_STATE_WORDX;
			end
			L4_STATE_WORDX: begin
				l4_sum <= l4_sum + ($bits(l4_sum))'(lev2_add_ff[0]);
			end
			endcase

			if (p_eof) begin
				l4_state <= L4_STATE_IDLE;
			end
		end
	end
end

`ifdef efderer
assign trace_csum.ip_state = ip_state;
assign trace_csum.l4_state = l4_state;
assign trace_csum.p_valid = p_valid;
assign trace_csum.p_sof = p_sof;
assign trace_csum.p_eof = p_eof;
assign trace_csum.commit_checksum = commit_checksum;
assign trace_csum.eth_type = eth_type;
assign trace_csum.ip_sum = ip_sum;
assign trace_csum.ip_proto = ip_proto;
assign trace_csum.l4_sum = l4_sum;
`endif

endmodule
