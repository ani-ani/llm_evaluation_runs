module traffic_probability (
input clk,
input rst_n,
input start,
input [5:0] light_index,
input [7:0] x_pos,
input [7:0] r_dur,
input [7:0] g_dur,
input config_valid,
output reg [31:0] prob_stop [3:0],
output reg [31:0] prob_pass,
output reg done
);

reg [3:0] config_flags;
reg [3:0] x_pos_arr [3:0];
reg [7:0] r_dur_arr [3:0];
reg [7:0] g_dur_arr [3:0];
reg [3:0] c_vals [3:0];
reg [31:0] current_step;
reg [31:0] total_steps;
reg [31:0] stop_count [3:0];
reg [31:0] pass_count;
reg [2:0] state;
reg done_reg;

always @(posedge clk) begin
if (!rst_n) begin
config_flags <= 4'b0000;
x_pos_arr <= 4'b0000;
r_dur_arr <= 4'b0000;
g_dur_arr <= 4'b0000;
c_vals <= 4'b0000;
current_step <= 0;
total_steps <= 16;
stop_count <= 4'b0000;
pass_count <= 0;
state <= 0;
done_reg <= 0;
end else begin
case (state)
0: begin
if (config_valid && light_index < 4) begin
config_flags[light_index] <= 1;
x_pos_arr[light_index] <= x_pos;
r_dur_arr[light_index] <= r_dur;
g_dur_arr[light_index] <= g_dur;
if (config_flags == 4'b1111 && start) begin
state <= 1;
end
end
end
1: begin
current_step <= current_step + 1;
if (current_step >= 16) begin
state <= 2;
done_reg <= 1;
end
end
2: begin
// Do nothing, stay in done
end
endcase
end
end

assign prob_stop = 4'b0000;
assign prob_pass = 0;
assign done = done_reg;

endmodule