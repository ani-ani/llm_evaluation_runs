module right_angle_side (
  input clk,
  input rst_n,
  input start,
  input [7:0] w,
  input [7:0] h,
  output reg [15:0] result,
  output reg done
);
  reg [15:0] sum_store;
  reg [31:0] rem;
  reg [15:0] res;
  reg [4:0] step;
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      res <= 16'b0;
      rem <= 32'b0;
      step <= 5'b0;
      done <= 1'b0;
      result <= 16'b0;
      sum_store <= 16'b0;
    end else begin
      done <= 1'b0;
      if (start) begin
        sum_store <= w * w + h * h;
        rem <= {sum_store, 16'b0};
        res <= 16'b0;
        step <= 5'b0;
      end else if (step < 16) begin
        rem <= rem << 1;
        if (rem[31:15] >= {res, 1'b1}) begin
          rem[31:15] <= rem[31:15] - {res, 1'b1};
          res <= {res[14:0], 1'b1};
        end else begin
          res <= {res[14:0], 1'b0};
        end
        step <= step + 1;
      end else if (step == 16) begin
        result <= res;
        done <= 1'b1;
        step <= 5'b0;
      end
    end
  end
endmodule