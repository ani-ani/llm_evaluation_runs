module bracket_checker(
  input clk,
  input rst_n,
  input start,
  input [7:0] brackets,
  output reg result,
  output reg done
);

  reg processing;
  reg [2:0] cycle_cnt;
  reg signed [4:0] cnt;
  reg invalid_flag;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      processing <= 1'b0;
      cycle_cnt <= 3'b0;
      cnt <= 5'sd0;
      invalid_flag <= 1'b0;
      result <= 1'b0;
      done <= 1'b0;
    end else begin
      done <= 1'b0;
      
      if (processing) begin
        reg signed [4:0] next_cnt;
        next_cnt = cnt;
        
        if (brackets == 8'h28) next_cnt = cnt + 1;
        else if (brackets == 8'h29) next_cnt = cnt - 1;
        
        cnt <= next_cnt;
        if (next_cnt < 0) invalid_flag <= 1'b1;
        
        if (cycle_cnt < 3'd7) begin
          cycle_cnt <= cycle_cnt + 1;
        end else begin
          processing <= 1'b0;
          done <= 1'b1;
          result <= (invalid_flag || (next_cnt != 0)) ? 1'b0 : 1'b1;
        end
      end else begin
        if (start) begin
          processing <= 1'b1;
          cycle_cnt <= 3'b0;
          cnt <= 5'sd0;
          invalid_flag <= 1'b0;
        end
      end
    end
  end
endmodule