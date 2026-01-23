module digit_distance(input clk, input rst_n, input start, input [31:0] n1, input [31:0] n2, output reg [7:0] result, output reg done);
reg [31:0] diff_reg;
reg [7:0] sum_reg;
reg [3:0] digit_cnt;
reg [2:0] state_reg;

always @(posedge clk or !rst_n) begin
   if (!rst_n) begin
      diff_reg <= 32'd0;
      sum_reg <= 8'd0;
      digit_cnt <= 4'd0;
      state_reg <= 2'd0;
   end else begin
      case(state_reg)
         2'd0: begin // IDLE
            if (start) begin
               state_reg <= 2'd1;
            end
         end
         2'd1: begin // CALC_DIFF
            wire signed [31:0] n1_signed = n1;
            wire signed [31:0] n2_signed = n2;
            wire signed [31:0] diff_signed = n1_signed - n2_signed;
            wire [31:0] diff_abs;
            assign diff_abs = (diff_signed >=0) ? unsigned(diff_signed) : unsigned(~diff_signed +1);
            diff_reg <= diff_abs;
            sum_reg <= 8'd0;
            digit_cnt <= 4'd10;
            state_reg <= 2'd2;
         end
         2'd2: begin // EXTRACT_DIGITS
            if (digit_cnt > 0) begin
               diff_reg <= diff_reg / 10;
               sum_reg <= sum_reg + (diff_reg % 10);
               digit_cnt <= digit_cnt - 1;
               if (digit_cnt == 1) begin
                  state_reg <= 2'd3;
               end else begin
                  state_reg <= 2'd2;
               end
            end else begin
               state_reg <= 2'd3;
            end
         end
         2'd3: begin // DONE
            state_reg <= 2'd3;
         end
      endcase
   end
end

assign result = sum_reg;
assign done = (state_reg == 3'd3);

endmodule