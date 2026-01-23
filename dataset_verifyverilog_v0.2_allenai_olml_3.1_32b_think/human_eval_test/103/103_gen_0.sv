module rounded_avg (input clk, input rst_n, input start, input [7:0] n, input [7:0] m, output reg [7:0] result, output reg error, output reg done);
parameter IDLE = 3'd0, CHECK_RANGE = 3'd1, CALC_SUM = 3'd2, CALC_COUNT = 3'd3, DIVIDE = 3'd4, ROUND = 3'd5, DONE = 3'd6;
reg [2:0] state, next_state;
reg [7:0] sum, count;
reg [8:0] temp_sum;
reg [7:0] average;
reg [1:0] done_counter;
reg [8:0] remainder;
always_ff @(posedge clk or negedge rst_n) begin if (!rst_n) begin state <= IDLE; next_state <= IDLE; sum <= 8'd0; count <= 8'd0; temp_sum <= 9'd0; average <= 8'd0; done_counter <= 2'd0; error <= 1'b0; done <= 1'b0; result <= 8'd0; end else begin state <= next_state; if (start) begin error <= 1'b0; done <= 1'b0; end end end
always_comb begin next_state = state; temp_sum = n + m; case ({state}) IDLE: next_state = start ? CHECK_RANGE : IDLE; CHECK_RANGE: begin if (n > m) begin error = 1'b1; next_state = DONE; end else next_state = CALC_SUM; end CALC_SUM: next_state = CALC_COUNT; CALC_COUNT: begin count = m - n + 1; next_state = DIVIDE; end DIVIDE: begin average = temp_sum / count; next_state = ROUND; end ROUND: begin remainder = temp_sum - (average * count); if (remainder >= (count + 1)/2) average = average + 1; result = average[7:0]; next_state = DONE; end DONE: begin if (done_counter == 0) done = 1'b1; else done = 1'b0; done_counter = done_counter == 0 ? 3'd3 : done_counter - 1; next_state = done_counter == 0 ? IDLE : DONE; end endcase end
endmodule