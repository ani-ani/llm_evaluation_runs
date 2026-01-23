module date_validator (
input clk,
input rst_n, // active-low reset
input start,
input [79:0] date_str,
output reg valid,
output reg done
);
localparam IDLE = 3'd0,
PARSE = 3'd1,
CHECK_FORMAT = 3'd2,
CHECK_MONTH = 3'd3,
CHECK_DAY = 3'd4,
DONE = 3'd5;
reg [2:0] state, next_state;
reg [79:0] latched_date_str;
reg [7:0] char_m1, char_m2, char_dash1, char_d1, char_d2, char_dash2, char_y1, char_y2, char_y3, char_y4;
reg [4:0] month_num;
reg [5:0] day_num;
reg valid;
reg latch_enable;
always @(posedge clk or negedge rst_n) begin
if (!rst_n) begin
state <= IDLE;
next_state <= IDLE;
latched_date_str <= 0;
char_m1 <= 0; char_m2 <=0; char_dash1 <=0; char_d1 <=0; char_d2 <=0; char_dash2 <=0; char_y1 <=0; char_y2 <=0; char_y3 <=0; char_y4 <=0;
month_num <=0; day_num <=0;
valid <=0;
done <=0;
latch_enable <=0;
end else begin
state <= next_state;
if (latch_enable) begin
latched_date_str <= date_str;
end
valid <= valid;
done <= (state == DONE);
end
end
always @(*) begin
next_state = state;
latch_enable = 0;
case (state)
IDLE:
if (start) begin
latch_enable = 1;
next_state = IDLE;
end else begin
next_state = IDLE;
end
PARSE:
char_m1 = latched_date_str[7:0];
char_m2 = latched_date_str[15:8];
char_dash1 = latched_date_str[23:16];
char_d1 = latched_date_str[31:24];
char_d2 = latched_date_str[39:32];
char_dash2 = latched_date_str[47:40];
char_y1 = latched_date_str[55:48];
char_y2 = latched_date_str[63:56];
char_y3 = latched_date_str[71:64];
char_y4 = latched_date_str[79:72];
month_num = (char_m2 - 48) << 4 | (char_m1 - 48);
day_num = (char_d1 - 48) << 4 | (char_d2 - 48);
next_state = CHECK_FORMAT;
CHECK_FORMAT:
valid = 1'b1;
if (char_dash1 != 8'h2D || char_dash2 != 8'h2D) begin
valid = 1'b0;
end
if (char_m1 < 8'h30 || char_m1 > 8'h39 || char_m2 < 8'h30 || char_m2 > 8'h39) begin
valid = 1'b0;
end
if (char_d1 < 8'h30 || char_d1 > 8'h39 || char_d2 < 8'h30 || char_d2 > 8'h39) begin
valid = 1'b0;
end
if (char_y1 < 8'h30 || char_y1 > 8'h39 || char_y2 < 8'h30 || char_y2 > 8'h39 || char_y3 < 8'h30 || char_y3 > 8'h39 || char_y4 < 8'h30 || char_y4 > 8'h39) begin
valid = 1'b0;
end
next_state = CHECK_MONTH;
CHECK_MONTH:
if (month_num < 1 || month_num > 12) begin
valid = 1'b0;
end
next_state = CHECK_DAY;
CHECK_DAY:
if (month_num == 2) begin
if (day_num < 1 || day_num > 29) begin
valid = 1'b0;
end
end else if (month_num ==4 || month_num ==6 || month_num ==9 || month_num ==11) begin
if (day_num < 1 || day_num > 30) begin
valid = 1'b0;
end
end else begin
if (day_num < 1 || day_num > 31) begin
valid = 1'b0;
end
end
next_state = DONE;
DONE:
next_state = DONE;
endcase
end
}