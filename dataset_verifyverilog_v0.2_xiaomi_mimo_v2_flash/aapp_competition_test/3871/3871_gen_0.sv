module reality_show (
input clk,
input rst_n,
input start,
input [2:0] n,
input [2:0] l_i,
input [12:0] s_i,
input [12:0] c_v,
input valid_i,
input done_i,
output reg [15:0] max_profit,
output reg done
);
localparam IDLE=0, SELECT=1, FIGHT=2, UPDATE=3, DONE=4;
reg [2:0] state, next_state;
reg [3:0] count_curr [0:15];
reg [15:0] current_profit;
reg [3:0] cnt_acc [0:16];
reg [3:0] cnt_rej [0:16];
reg [15:0] rev_acc_sum, rev_rej_sum;
reg [3:0] loop_idx;
reg last_flag;
reg [12:0] buf_s_i;
always @(*) begin
case(state)
IDLE: next_state = start ? SELECT : IDLE;
SELECT: next_state = valid_i ? FIGHT : (done_i ? DONE : SELECT);
FIGHT: next_state = (loop_idx == 16) ? UPDATE : FIGHT;
UPDATE: next_state = last_flag ? DONE : SELECT;
DONE: next_state = DONE;
default: next_state = IDLE;
endcase
end
always @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
state <= IDLE;
max_profit <= 0;
done <= 0;
end else begin
state <= next_state;
case(next_state)
IDLE: begin
for (int i=0; i<16; i++) count_curr[i] <= 0;
current_profit <= 0;
max_profit <= 0;
done <= 0;
end
SELECT: begin
done <= 0;
if (valid_i) begin
buf_s_i <= s_i;
last_flag <= done_i;
for (int i=0; i<16; i++) begin
cnt_rej[i] <= count_curr[i];
cnt_acc[i] <= count_curr[i];
end
cnt_rej[16] <= 0;
cnt_acc[16] <= 0;
cnt_acc[l_i - 1] <= count_curr[l_i - 1] + 1;
rev_acc_sum <= 0;
rev_rej_sum <= 0;
loop_idx <= 0;
end
end
FIGHT: begin
if (loop_idx < 16) begin
rev_acc_sum <= rev_acc_sum + (cnt_acc[loop_idx][3:1] * c_v);
cnt_acc[loop_idx] <= {3'b0, cnt_acc[loop_idx][0]};
cnt_acc[loop_idx+1] <= cnt_acc[loop_idx+1] + cnt_acc[loop_idx][3:1];
rev_rej_sum <= rev_rej_sum + (cnt_rej[loop_idx][3:1] * c_v);
cnt_rej[loop_idx] <= {3'b0, cnt_rej[loop_idx][0]};
cnt_rej[loop_idx+1] <= cnt_rej[loop_idx+1] + cnt_rej[loop_idx][3:1];
loop_idx <= loop_idx + 1;
end
end
UPDATE: begin
if ((current_profit - buf_s_i + rev_acc_sum) >= (current_profit + rev_rej_sum)) begin
current_profit <= current_profit - buf_s_i + rev_acc_sum;
if ((current_profit - buf_s_i + rev_acc_sum) > max_profit)
max_profit <= current_profit - buf_s_i + rev_acc_sum;
for (int i=0; i<16; i++) count_curr[i] <= cnt_acc[i];
end else begin
current_profit <= current_profit + rev_rej_sum;
if ((current_profit + rev_rej_sum) > max_profit)
max_profit <= current_profit + rev_rej_sum;
for (int i=0; i<16; i++) count_curr[i] <= cnt_rej[i];
end
end
DONE: begin
done <= 1;
end
endcase
end
end
endmodule