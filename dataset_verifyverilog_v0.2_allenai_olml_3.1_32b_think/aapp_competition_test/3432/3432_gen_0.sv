module minimal_max_sum (
 input clk,
 input rst_n,
 input start,
 input [6:0] a_in,
 input [6:0] b_in,
 input data_valid,
 output reg [7:0] result,
 output reg done,
 output reg error
);

reg [6:0] a_arr [8];
reg [6:0] b_arr [8];
reg [3:0] pair_count;
reg [2:0] state;
localparam IDLE = 3'd0,
COLLECT = 3'd1,
SORT_A = 3'd2,
SORT_B = 3'd3,
CALCULATE = 3'd4,
DONE = 3'd5;
reg error_flag;
reg done_flag;
reg [2:0] sort_a_pass, sort_a_idx;
reg [2:0] sort_b_pass, sort_b_idx;
reg [3:0] calc_count;
reg [7:0] current_max;
reg [2:0] next_state;

always @(posedge clk) begin
 if (!rst_n) begin
 pair_count <= 4'd0;
a_arr[0] <= 8'd0; a_arr[1] <=8'd0; a_arr[2] <=8'd0; a_arr[3] <=8'd0;
a_arr[4] <=8'd0; a_arr[5] <=8'd0; a_arr[6] <=8'd0; a_arr[7] <=8'd0;
b_arr[0] <=8'd0; b_arr[1] <=8'd0; b_arr[2] <=8'd0; b_arr[3] <=8'd0;
b_arr[4] <=8'd0; b_arr[5] <=8'd0; b_arr[6] <=8'd0; b_arr[7] <=8'd0;
 state <= IDLE;
 error_flag <= 1'b0;
 done_flag <= 1'b0;
 result <= 8'd0;
 current_max <= 8'd0;
 calc_count <=4'd0;
 sort_a_pass <=3'd0;
 sort_a_idx <=3'd0;
 sort_b_pass <=3'd0;
 sort_b_idx <=3'd0;
 next_state <= IDLE;
 end else begin
 next_state = state;
 case (state)
 IDLE: begin
 if (start) next_state = COLLECT;
 end
 COLLECT: begin
 if (data_valid && pair_count >=8) begin
 error_flag <= 1'b1;
 end
 if (data_valid && pair_count <8) begin
 a_arr[pair_count] <= a_in;
 b_arr[pair_count] <= b_in;
 pair_count <= pair_count +1;
 if (pair_count ==8) begin
 next_state = SORT_A;
 end
 end
 if (pair_count ==8) begin
 next_state = SORT_A;
 end
 end
 SORT_A: begin
 if (sort_a_pass <7) begin
 if (sort_a_idx <7) begin
 if (a_arr[sort_a_idx] > a_arr[sort_a_idx +1]) begin
 a_arr[sort_a_idx] <= a_arr[sort_a_idx +1];
 a_arr[sort_a_idx +1] <= a_arr[sort_a_idx];
 end
 sort_a_idx <= sort_a_idx +1;
 end else begin
 sort_a_pass <= sort_a_pass +1;
 sort_a_idx <=3'd0;
 end
 next_state = SORT_A;
 end else begin
 sort_b_pass <=3'd0;
 sort_b_idx <=3'd0;
 next_state = SORT_B;
 end
 end
 SORT_B: begin
 if (sort_b_pass <7) begin
 if (sort_b_idx <7) begin
 if (b_arr[sort_b_idx] < b_arr[sort_b_idx +1]) begin
 b_arr[sort_b_idx] <= b_arr[sort_b_idx +1];
 b_arr[sort_b_idx +1] <= b_arr[sort_b_idx];
 end
 sort_b_idx <= sort_b_idx +1;
 end else begin
 sort_b_pass <= sort_b_pass +1;
 sort_b_idx <=3'd0;
 end
 next_state = SORT_B;
 end else begin
 calc_count <=4'd0;
 current_max <=8'd0;
 next_state = CALCULATE;
 end
 end
 CALCULATE: begin
 if (calc_count < pair_count) begin
 current_max <= (a_arr[calc_count] + b_arr[calc_count] > current_max) ? (a_arr[calc_count] + b_arr[calc_count]) : current_max;
 calc_count <= calc_count +1;
 next_state = CALCULATE;
 end else begin
 result <= current_max;
 next_state = DONE;
 end
 end
 DONE: begin
 done_flag <= 1'b1;
 next_state = DONE;
 end
 default: next_state = IDLE;
 endcase
 state <= next_state;
 done <= done_flag;
 error <= error_flag;
 end
endmodule