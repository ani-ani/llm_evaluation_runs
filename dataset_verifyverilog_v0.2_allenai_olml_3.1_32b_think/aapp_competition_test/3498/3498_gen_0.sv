module priority_ceiling_scheduler (
input clk,
input rst_n,
input start,
input config_valid,
input [15:0] task_start_time [3:0],
input [3:0] task_priority [3:0],
input [1:0] task_inst_type [3:0][7:0],
input [3:0] task_inst_data [3:0][7:0],
input [3:0] task_inst_count [3:0],
input [3:0] resource_ceiling [3:0],
output result_valid,
output [31:0] task_completion_time [3:0],
output [31:0] current_clock
);

always @(*) begin
result_valid = 1'b0;
task_completion_time = 32'd0;
current_clock = 32'd0;
end

always @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
result_valid = 1'b0;
task_completion_time = 32'd0;
current_clock = 32'd0;
end
end
endmodule