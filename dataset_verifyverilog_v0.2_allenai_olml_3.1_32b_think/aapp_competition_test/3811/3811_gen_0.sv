module wcd_solver (input clk, input rst_n, input start, input [31:0] a_i, input [31:0] b_i, output reg [31:0] result, output reg done);
localparam factor_0 = 2;
localparam factor_1 = 3;
localparam factor_2 = 5;
localparam factor_3 = 7;
localparam factor_4 = 11;
localparam factor_5 = 13;
localparam factor_6 = 17;
localparam factor_7 = 19;
localparam IDLE = 3'd0;
localparam FACTOR_FIRST = 3'd1;
localparam CHECK_PAIR_1 = 3'd2;
localparam CHECK_PAIR_2 = 3'd3;
localparam CHECK_PAIR_3 = 3'd4;
localparam DONE = 3'd5;
reg [2:0] state, next_state;
reg [7:0] valid_factors;
always @(*) begin
   result = 32'hFFFFFFFF;
end
always @(posedge clk or posedge rst_n) begin
   if (!rst_n) begin
      state <= IDLE;
      next_state <= IDLE;
      valid_factors <= 8'b0;
      result <= 32'hFFFFFFFF;
      done <=1'b0;
   end else begin
      next_state <= state;

      case (state)
         IDLE: begin
            if (start) begin
               next_state <= FACTOR_FIRST;
            end
         end
         FACTOR_FIRST: begin
            valid_factors <= 8'b0;
            valid_factors[0] = (a_i % factor_0 == 0) || (b_i % factor_0 == 0);
            valid_factors[1] = (a_i % factor_1 == 0) || (b_i % factor_1 == 0);
            valid_factors[2] = (a_i % factor_2 == 0) || (b_i % factor_2 == 0);
            valid_factors[3] = (a_i % factor_3 == 0) || (b_i % factor_3 == 0);
            valid_factors[4] = (a_i % factor_4 == 0) || (b_i % factor_4 == 0);
            valid_factors[5] = (a_i % factor_5 == 0) || (b_i % factor_5 == 0);
            valid_factors[6] = (a_i % factor_6 == 0) || (b_i % factor_6 == 0);
            valid_factors[7] = (a_i % factor_7 == 0) || (b_i % factor_7 == 0);
            next_state <= CHECK_PAIR_1;
         end
         CHECK_PAIR_1: begin
            valid_factors <= 8'b0;
            valid_factors[0] = valid_factors[0] && ( (a_i % factor_0 ==0) || (b_i % factor_0 ==0) );
            valid_factors[1] = valid_factors[1] && ( (a_i % factor_1 ==0) || (b_i % factor_1 ==0) );
            valid_factors[2] = valid_factors[2] && ( (a_i % factor_2 ==0) || (b_i % factor_2 ==0) );
            valid_factors[3] = valid_factors[3] && ( (a_i % factor_3 ==0) || (b_i % factor_3 ==0) );
            valid_factors[4] = valid_factors[4] && ( (a_i % factor_4 ==0) || (b_i % factor_4 ==0) );
            valid_factors[5] = valid_factors[5] && ( (a_i % factor_5 ==0) || (b_i % factor_5 ==0) );
            valid_factors[6] = valid_factors[6] && ( (a_i % factor_6 ==0) || (b_i % factor_6 ==0) );
            valid_factors[7] = valid_factors[7] && ( (a_i % factor_7 ==0) || (b_i % factor_7 ==0) );
            next_state <= CHECK_PAIR_2;
         end
         CHECK_PAIR_2: begin
            valid_factors <= 8'b0;
            valid_factors[0] = valid_factors[0] && ( (a_i % factor_0 ==0) || (b_i % factor_0 ==0) );
            valid_factors[1] = valid_factors[1] && ( (a_i % factor_1 ==0) || (b_i % factor_1 ==0) );
            valid_factors[2] = valid_factors[2] && ( (a_i % factor_2 ==0) || (b_i % factor_2 ==0) );
            valid_factors[3] = valid_factors[3] && ( (a_i % factor_3 ==0) || (b_i % factor_3 ==0) );
            valid_factors[4] = valid_factors[4] && ( (a_i % factor_4 ==0) || (b_i % factor_4 ==0) );
            valid_factors[5] = valid_factors[5] && ( (a_i % factor_5 ==0) || (b_i % factor_5 ==0) );
            valid_factors[6] = valid_factors[6] && ( (a_i % factor_6 ==0) || (b_i % factor_6 ==0) );
            valid_factors[7] = valid_factors[7] && ( (a_i % factor_7 ==0) || (b_i % factor_7 ==0) );
            next_state <= CHECK_PAIR_3;
         end
         CHECK_PAIR_3: begin
            valid_factors <= 8'b0;
            valid_factors[0] = valid_factors[0] && ( (a_i % factor_0 ==0) || (b_i % factor_0 ==0) );
            valid_factors[1] = valid_factors[1] && ( (a_i % factor_1 ==0) || (b_i % factor_1 ==0) );
            valid_factors[2] = valid_factors[2] && ( (a_i % factor_2 ==0) || (b_i % factor_2 ==0) );
            valid_factors[3] = valid_factors[3] && ( (a_i % factor_3 ==0) || (b_i % factor_3 ==0) );
            valid_factors[4] = valid_factors[4] && ( (a_i % factor_4 ==0) || (b_i % factor_4 ==0) );
            valid_factors[5] = valid_factors[5] && ( (a_i % factor_5 ==0) || (b_i % factor_5 ==0) );
            valid_factors[6] = valid_factors[6] && ( (a_i % factor_6 ==0) || (b_i % factor_6 ==0) );
            valid_factors[7] = valid_factors[7] && ( (a_i % factor_7 ==0) || (b_i % factor_7 ==0) );
            next_state <= DONE;
         end
         DONE: begin
            result <= 32'hFFFFFFFF;
            if (valid_factors[0]) result = factor_0;
            else if (valid_factors[1]) result = factor_1;
            else if (valid_factors[2]) result = factor_2;
            else if (valid_factors[3]) result = factor_3;
            else if (valid_factors[4]) result = factor_4;
            else if (valid_factors[5]) result = factor_5;
            else if (valid_factors[6]) result = factor_6;
            else if (valid_factors[7]) result = factor_7;
            done <= 1'b1;
            next_state <= DONE;
         end
         default: next_state <= IDLE;
      endcase
      state <= next_state;
   end
endmodule