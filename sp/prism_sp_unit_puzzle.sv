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

module prism_sp_unit_puzzle #(
	parameter int NFIFOS,
	parameter int RESULT_WIDTH,
	parameter int RX_INSTANCE,
	parameter int TX_INSTANCE
)
(
	input wire logic clk,
	input wire logic rst,

	input sp_inputs_t sp_inputs,
	unit_issue_interface.unit issue,
	unit_writeback_interface.unit wb,

	input wire logic [SP_UNIT_PUZZLE_NCMDS-1:0] issue_cmd,
	output wire logic [SP_UNIT_PUZZLE_NCMDS-1:0] cmds_busy,
	output wire logic [SP_UNIT_PUZZLE_NCMDS-1:0] cmds_done,
	output var logic [RESULT_WIDTH-1:0] result,

	fifo_read_interface.master puzzle_fifo_r_0,
	fifo_write_interface.master puzzle_fifo_w_0,
	fifo_read_interface.master puzzle_fifo_r_1,
	fifo_write_interface.master puzzle_fifo_w_1,
	fifo_read_interface.master puzzle_fifo_r_2,
	fifo_write_interface.master puzzle_fifo_w_2,
	fifo_read_interface.master puzzle_fifo_r_3,
	fifo_write_interface.master puzzle_fifo_w_3
);

wire logic puzzle_fifo_r_empty [NFIFOS];
wire logic puzzle_fifo_w_full [NFIFOS];

assign puzzle_fifo_r_empty[0] = puzzle_fifo_r_0.empty;
assign puzzle_fifo_r_empty[1] = puzzle_fifo_r_1.empty;
assign puzzle_fifo_r_empty[2] = puzzle_fifo_r_2.empty;
assign puzzle_fifo_r_empty[3] = puzzle_fifo_r_3.empty;
assign puzzle_fifo_w_full[0] = puzzle_fifo_w_0.full;
assign puzzle_fifo_w_full[1] = puzzle_fifo_w_1.full;
assign puzzle_fifo_w_full[2] = puzzle_fifo_w_2.full;
assign puzzle_fifo_w_full[3] = puzzle_fifo_w_3.full;

/*
 * Command "puzzle FIFO empty"
 */
prism_sp_unit_basic_cmd prism_sp_unit_basic_cmd_puzzle_fifo_r_empty(
	.clk,
	.rst,
	.issue,
	.wb,
	.issue_cmd(issue_cmd[CMD_PUZZLE_FIFO_R_EMPTY]),
	.cmd_done(cmds_done[CMD_PUZZLE_FIFO_R_EMPTY]),
	.cmd_busy(cmds_busy[CMD_PUZZLE_FIFO_R_EMPTY])
);

var logic fifo_r_empty_result;

always_ff @(posedge clk) begin
	if (rst) begin
	end
	else begin
		// Unpulse

		if (issue.new_request & issue.ready & issue_cmd[CMD_PUZZLE_FIFO_R_EMPTY]) begin
			fifo_r_empty_result <= puzzle_fifo_r_empty[sp_inputs.fn3[1:0]];
		end
	end
end

/*
 * Command "puzzle FIFO pop"
 */
prism_sp_unit_basic_cmd prism_sp_unit_basic_cmd_puzzle_fifo_r_pop(
	.clk,
	.rst,
	.issue,
	.wb,
	.issue_cmd(issue_cmd[CMD_PUZZLE_FIFO_R_POP]),
	.cmd_done(cmds_done[CMD_PUZZLE_FIFO_R_POP]),
	.cmd_busy(cmds_busy[CMD_PUZZLE_FIFO_R_POP])
);

var logic [31:0] fifo_r_pop_result;
wire logic [31:0] prism_sp_unit_puzzle_fifo_r_pop_0_out;
wire logic [31:0] prism_sp_unit_puzzle_fifo_r_pop_1_out;
wire logic [31:0] prism_sp_unit_puzzle_fifo_r_pop_2_out;
wire logic [31:0] prism_sp_unit_puzzle_fifo_r_pop_3_out;

wire logic fifo_r_pulse = issue.new_request & issue.ready & issue_cmd[CMD_PUZZLE_FIFO_R_POP];

if (RX_INSTANCE && ENABLE_RX_PUZZLE_SW_FIFO_R[0] ||
	TX_INSTANCE && ENABLE_TX_PUZZLE_SW_FIFO_R[0]) begin
prism_sp_unit_puzzle_fifo_r_pop prism_sp_unit_puzzle_fifo_r_pop_0(
	.clk,
	.rst,
	.pulse(fifo_r_pulse & sp_inputs.fn3[1:0] == 2'b00),
	.fifo_r(puzzle_fifo_r_0),
	.out(prism_sp_unit_puzzle_fifo_r_pop_0_out)
);
end
else begin
assign prism_sp_unit_puzzle_fifo_r_pop_0_out = '0;
end

if (RX_INSTANCE && ENABLE_RX_PUZZLE_SW_FIFO_R[1] ||
	TX_INSTANCE && ENABLE_TX_PUZZLE_SW_FIFO_R[1]) begin
prism_sp_unit_puzzle_fifo_r_pop prism_sp_unit_puzzle_fifo_r_pop_1(
	.clk,
	.rst,
	.pulse(fifo_r_pulse & sp_inputs.fn3[1:0] == 2'b01),
	.fifo_r(puzzle_fifo_r_1),
	.out(prism_sp_unit_puzzle_fifo_r_pop_1_out)
);
end
else begin
assign prism_sp_unit_puzzle_fifo_r_pop_1_out = '0;
end

if (RX_INSTANCE && ENABLE_RX_PUZZLE_SW_FIFO_R[2] ||
	TX_INSTANCE && ENABLE_TX_PUZZLE_SW_FIFO_R[2]) begin
prism_sp_unit_puzzle_fifo_r_pop prism_sp_unit_puzzle_fifo_r_pop_2(
	.clk,
	.rst,
	.pulse(fifo_r_pulse & sp_inputs.fn3[1:0] == 2'b10),
	.fifo_r(puzzle_fifo_r_2),
	.out(prism_sp_unit_puzzle_fifo_r_pop_2_out)
);
end
else begin
assign prism_sp_unit_puzzle_fifo_r_pop_2_out = '0;
end

if (RX_INSTANCE && ENABLE_RX_PUZZLE_SW_FIFO_R[3] ||
	TX_INSTANCE && ENABLE_TX_PUZZLE_SW_FIFO_R[3]) begin
prism_sp_unit_puzzle_fifo_r_pop prism_sp_unit_puzzle_fifo_r_pop_3(
	.clk,
	.rst,
	.pulse(fifo_r_pulse & sp_inputs.fn3[1:0] == 2'b11),
	.fifo_r(puzzle_fifo_r_3),
	.out(prism_sp_unit_puzzle_fifo_r_pop_3_out)
);
end
else begin
assign prism_sp_unit_puzzle_fifo_r_pop_3_out = '0;
end

always_ff @(posedge clk) begin
	if (rst) begin
	end
	else begin
		if (issue.new_request & issue.ready & issue_cmd[CMD_PUZZLE_FIFO_R_POP]) begin
			case (sp_inputs.fn3[1:0])
			2'b00: fifo_r_pop_result <= prism_sp_unit_puzzle_fifo_r_pop_0_out;
			2'b01: fifo_r_pop_result <= prism_sp_unit_puzzle_fifo_r_pop_1_out;
			2'b10: fifo_r_pop_result <= prism_sp_unit_puzzle_fifo_r_pop_2_out;
			2'b11: fifo_r_pop_result <= prism_sp_unit_puzzle_fifo_r_pop_3_out;
			endcase
		end
	end
end

/*
 * Command "pipline FIFO full"
 */
prism_sp_unit_basic_cmd prism_sp_unit_basic_cmd_puzzle_fifo_w_full(
	.clk,
	.rst,
	.issue,
	.wb,
	.issue_cmd(issue_cmd[CMD_PUZZLE_FIFO_W_FULL]),
	.cmd_done(cmds_done[CMD_PUZZLE_FIFO_W_FULL]),
	.cmd_busy(cmds_busy[CMD_PUZZLE_FIFO_W_FULL])
);

var logic fifo_w_full_result;

always_ff @(posedge clk) begin
	if (rst) begin
	end
	else begin
		// Unpulse

		if (issue.new_request & issue.ready & issue_cmd[CMD_PUZZLE_FIFO_W_FULL]) begin
			fifo_w_full_result <= puzzle_fifo_w_full[sp_inputs.fn3[1:0]];
		end
	end
end

/*
 * Command "puzzle FIFO push"
 */
prism_sp_unit_basic_cmd prism_sp_unit_basic_cmd_puzzle_fifo_w_push(
	.clk,
	.rst,
	.issue,
	.wb,
	.issue_cmd(issue_cmd[CMD_PUZZLE_FIFO_W_PUSH]),
	.cmd_done(cmds_done[CMD_PUZZLE_FIFO_W_PUSH]),
	.cmd_busy(cmds_busy[CMD_PUZZLE_FIFO_W_PUSH])
);

wire logic fifo_w_pulse = issue.new_request & issue.ready & issue_cmd[CMD_PUZZLE_FIFO_W_PUSH];

if (RX_INSTANCE && ENABLE_RX_PUZZLE_SW_FIFO_W[0] ||
	TX_INSTANCE && ENABLE_TX_PUZZLE_SW_FIFO_W[0]) begin
prism_sp_unit_puzzle_fifo_w_push prism_sp_unit_puzzle_fifo_w_push_0 (
	.clk,
	.rst,

	.pulse(fifo_w_pulse & (sp_inputs.fn3[1:0] == 2'b00)),
	.fifo_w(puzzle_fifo_w_0),
	.in(sp_inputs.rs1)
);
end

if (RX_INSTANCE && ENABLE_RX_PUZZLE_SW_FIFO_W[1] ||
	TX_INSTANCE && ENABLE_TX_PUZZLE_SW_FIFO_W[1]) begin
prism_sp_unit_puzzle_fifo_w_push prism_sp_unit_puzzle_fifo_w_push_1 (
	.clk,
	.rst,

	.pulse(fifo_w_pulse & (sp_inputs.fn3[1:0] == 2'b01)),
	.fifo_w(puzzle_fifo_w_1),
	.in(sp_inputs.rs1)
);
end

if (RX_INSTANCE && ENABLE_RX_PUZZLE_SW_FIFO_W[2] ||
	TX_INSTANCE && ENABLE_TX_PUZZLE_SW_FIFO_W[2]) begin
prism_sp_unit_puzzle_fifo_w_push prism_sp_unit_puzzle_fifo_w_push_2 (
	.clk,
	.rst,

	.pulse(fifo_w_pulse & (sp_inputs.fn3[1:0] == 2'b10)),
	.fifo_w(puzzle_fifo_w_2),
	.in(sp_inputs.rs1)
);
end

if (RX_INSTANCE && ENABLE_RX_PUZZLE_SW_FIFO_W[3] ||
	TX_INSTANCE && ENABLE_TX_PUZZLE_SW_FIFO_W[3]) begin
prism_sp_unit_puzzle_fifo_w_push prism_sp_unit_puzzle_fifo_w_push_3 (
	.clk,
	.rst,

	.pulse(fifo_w_pulse & (sp_inputs.fn3[1:0] == 2'b11)),
	.fifo_w(puzzle_fifo_w_3),
	.in(sp_inputs.rs1)
);
end

`ifdef EASY_POPPUSH_IMPL
/*
 * This implementation suffices for FIFOs with a write width of
 * $bits(sp_inputs.rs1) (i.e., 32).
 */
always_ff @(posedge clk) begin
	puzzle_fifo_w_0.wr_en <= 1'b0;
	puzzle_fifo_w_1.wr_en <= 1'b0;
	puzzle_fifo_w_2.wr_en <= 1'b0;
	puzzle_fifo_w_3.wr_en <= 1'b0;

	if (rst) begin
	end
	else begin
		if (issue.new_request & issue.ready & issue_cmd[CMD_PUZZLE_FIFO_W_PUSH]) begin
			unique case (sp_inputs.fn3[1:0])
			2'b00: begin
				puzzle_fifo_w_0.wr_en <= 1'b1;
				puzzle_fifo_w_0.wr_data <= sp_inputs.rs1;
			end
			2'b01: begin
				puzzle_fifo_w_1.wr_en <= 1'b1;
				puzzle_fifo_w_1.wr_data <= sp_inputs.rs1;
			end
			2'b10: begin
				puzzle_fifo_w_2.wr_en <= 1'b1;
				puzzle_fifo_w_2.wr_data <= sp_inputs.rs1;
			end
			2'b11: begin
				puzzle_fifo_w_3.wr_en <= 1'b1;
				puzzle_fifo_w_3.wr_data <= sp_inputs.rs1;
			end
			endcase
		end
	end
end
`endif

`ifdef SUPPORT_PUSH8
/*
 * Command "puzzle FIFO push-8"
 */
prism_sp_unit_basic_cmd prism_sp_unit_basic_cmd_puzzle_push8(
	.clk,
	.rst,
	.issue,
	.wb,
	.issue_cmd(issue_cmd[CMD_PUZZLE_FIFO_W_PUSH8]),
	.cmd_done(cmds_done[CMD_PUZZLE_FIFO_W_PUSH8]),
	.cmd_busy(cmds_busy[CMD_PUZZLE_FIFO_W_PUSH8])
);

always_ff @(posedge clk) begin
	if (rst) begin
	end
	else begin
		// Unpulse
		puzzle_fifo_w_wr_data <= '0;

		if (issue.new_request & issue.ready & issue_cmd[CMD_PUZZLE_FIFO_W_PUSH8]) begin
			puzzle_fifo_w_wr_data[sp_inputs.fn3[1:0]] <= { sp_inputs.rs2, sp_inputs.rs1 };
		end
	end
end
`endif // SUPPORT_PUSH8

/*
 * Remember current command
 */
var logic [SP_UNIT_PUZZLE_NCMDS-1:0] cur_cmd;

always_ff @(posedge clk) begin
	if (rst) begin
	end
	else begin
		if (issue.new_request & issue.ready) begin
			cur_cmd <= issue_cmd;
		end
	end
end

always_comb begin
	result = '0;

	// "Reverse case" statement for one-hot encoding.
	case (1'b1)
	cur_cmd[CMD_PUZZLE_FIFO_R_EMPTY]: result[0] = fifo_r_empty_result;
	cur_cmd[CMD_PUZZLE_FIFO_R_POP]: result = fifo_r_pop_result;
	cur_cmd[CMD_PUZZLE_FIFO_W_FULL]: result[0] = fifo_w_full_result;
	endcase
end

endmodule
