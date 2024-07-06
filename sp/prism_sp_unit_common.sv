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
import prism_sp_config::*;

module prism_sp_unit_common#(
	parameter int RESULT_WIDTH
)
(
	input wire logic clk,
	input wire logic rst,

	input sp_inputs_t sp_inputs,
	unit_issue_interface.unit issue,
	unit_writeback_interface.unit wb,

	input wire logic [SP_UNIT_COMMON_NCMDS-1:0] issue_cmd,
	output wire logic [SP_UNIT_COMMON_NCMDS-1:0] cmds_busy,
	output wire logic [SP_UNIT_COMMON_NCMDS-1:0] cmds_done,
	output var logic [RESULT_WIDTH-1:0] result,

	mmr_readwrite_interface.master mmr_rw,
	mmr_read_interface.master mmr_r,
	mmr_trigger_interface.master mmr_t,
	mmr_intr_interface.master mmr_i
);

var logic [SP_UNIT_COMMON_NCMDS-1:0] cmds_busy_ff;
var logic [SP_UNIT_COMMON_NCMDS-1:0] cmds_busy_comb;
var logic [SP_UNIT_COMMON_NCMDS-1:0] cmds_done_ff;
var logic [SP_UNIT_COMMON_NCMDS-1:0] cmds_done_comb;
assign cmds_busy = cmds_busy_ff;
assign cmds_done = cmds_done_ff;

/*
 * Command "LOAD REG"
 */
var logic [31:0] load_reg_cur;

prism_sp_unit_basic_cmd prism_sp_unit_basic_cmd_common_load_reg(
	.clk(clk),
	.rst(rst),
	.issue(issue),
	.wb(wb),
	.issue_cmd(issue_cmd[CMD_COMMON_LOAD_REG]),
	.cmd_done(cmds_done[CMD_COMMON_LOAD_REG]),
	.cmd_busy(cmds_busy[CMD_COMMON_LOAD_REG])
);

always_ff @(posedge clk) begin
	if (rst) begin
	end
	else begin
		if (issue.new_request & issue.ready & issue_cmd[CMD_COMMON_LOAD_REG]) begin
			if (sp_inputs.rs1[MMR_R_BITN]) begin
`ifndef VERILATOR
				if (mmr_r.INDEX_WIDTH == 0)
					load_reg_cur <= mmr_r.data[0];
				else
					load_reg_cur <= mmr_r.data[sp_inputs.rs1[0 +: mmr_r.INDEX_WIDTH]];
`endif
			end
			else begin
`ifndef VERILATOR
				if (mmr_rw.INDEX_WIDTH == 0)
					load_reg_cur <= mmr_rw.data[0];
				else
					load_reg_cur <= mmr_rw.data[sp_inputs.rs1[0 +: mmr_rw.INDEX_WIDTH]];
`endif
			end
		end
	end
end

/*
 * Command "STORE REG"
 */
prism_sp_unit_basic_cmd prism_sp_unit_basic_cmd_common_store_reg(
	.clk(clk),
	.rst(rst),
	.issue(issue),
	.wb(wb),
	.issue_cmd(issue_cmd[CMD_COMMON_STORE_REG]),
	.cmd_done(cmds_done[CMD_COMMON_STORE_REG]),
	.cmd_busy(cmds_busy[CMD_COMMON_STORE_REG])
);

always_ff @(posedge clk) begin
	if (rst) begin
		mmr_rw.store <= 1'b0;
	end
	else begin
		// Unpulse
		mmr_rw.store <= 1'b0;

		if (issue.new_request & issue.ready & issue_cmd[CMD_COMMON_STORE_REG]) begin
			mmr_rw.store <= 1'b1;
`ifndef VERILATOR
			if (mmr_rw.INDEX_WIDTH == 0)
				mmr_rw.store_idx <= 0;
			else
				mmr_rw.store_idx <= sp_inputs.rs1[0 +:mmr_rw.INDEX_WIDTH];
`endif
			mmr_rw.store_data <= sp_inputs.rs2;
		end
	end
end

/*
 * Command "READ TRIGGER"
 */
var logic common_read_trigger_result_ff;

prism_sp_unit_basic_cmd prism_sp_unit_basic_cmd_common_read_trigger(
	.clk(clk),
	.rst(rst),
	.issue(issue),
	.wb(wb),
	.issue_cmd(issue_cmd[CMD_COMMON_READ_TRIGGER]),
	.cmd_done(cmds_done[CMD_COMMON_READ_TRIGGER]),
	.cmd_busy(cmds_busy[CMD_COMMON_READ_TRIGGER])
);

wire logic [$clog2(mmr_t.WIDTH)-1:0] mmr_t_tsr_cursel = sp_inputs.fn3[5] ?
	sp_inputs.rs1[$clog2(mmr_t.WIDTH)-1:0] :
	sp_inputs.fn3[$clog2(mmr_t.WIDTH)-1:0];

always_ff @(posedge clk) begin
	if (rst) begin
	end
	else begin
		// unpulse
		mmr_t.tsr_invpulses[0] <= '0;

		if (issue.new_request & issue.ready & issue_cmd[CMD_COMMON_READ_TRIGGER]) begin
			// XXX reserve the fn3 MSB ([6]) for waiting for a trigger to occur.

			// If we prefer register-based indexing
			common_read_trigger_result_ff <= mmr_t.tsr[0][mmr_t_tsr_cursel];
			mmr_t.tsr_invpulses[0][mmr_t_tsr_cursel] <= mmr_t.tsr[0][mmr_t_tsr_cursel];
		end
	end
end

/*
 * Command "INTR"
 */
prism_sp_unit_basic_cmd prism_sp_unit_basic_cmd_common_intr(
	.clk(clk),
	.rst(rst),
	.issue(issue),
	.wb(wb),
	.issue_cmd(issue_cmd[CMD_COMMON_INTR]),
	.cmd_done(cmds_done[CMD_COMMON_INTR]),
	.cmd_busy(cmds_busy[CMD_COMMON_INTR])
);

always_ff @(posedge clk) begin
	if (rst) begin
		for (int i = 0; i < mmr_i.N; i++)
			mmr_i.isr_pulses[i] <= '0;
	end
	else begin
		// Unpulse
		for (int i = 0; i < mmr_i.N; i++) begin
			mmr_i.isr_pulses[i] <= '0;
		end

		if (issue.new_request & issue.ready & issue_cmd[CMD_COMMON_INTR]) begin
			if (mmr_i.N == 1) begin
				mmr_i.isr_pulses[0] <= sp_inputs.rs2;
			end
			else begin
				mmr_i.isr_pulses[sp_inputs.rs1[$clog2(mmr_i.N) - 1:0]] <= sp_inputs.rs2;
			end
		end
	end
end

var logic [SP_UNIT_COMMON_NCMDS-1:0] cur_cmd;

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
	cur_cmd[CMD_COMMON_LOAD_REG]: result = load_reg_cur;
	cur_cmd[CMD_COMMON_READ_TRIGGER]: result = common_read_trigger_result_ff;
	endcase
end

endmodule
