module power_calculator(
  input clk,
  input rst_n,
  input start,
  input [3:0] a,
  input [3:0] b,
  output reg [31:0] result,
  output reg done
);

  // Internal state
  reg [3:0] rem; // remaining multiplications (also serves as busy indicator when rem != 0)

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 32'd1;
      done <= 1'b0;
      rem <= 4'd0;
    end else begin
      // Default: hold values unless updated below
      result <= result;
      done <= 1'b0;
      rem <= rem;

      if (rem == 4'd0) begin
        // Idle: accept new job
        if (start) begin
          if (b == 4'd0) begin
            result <= 32'd1;  // a^0 = 1 (even if a == 0)
            done   <= 1'b1;
            rem    <= 4'd0;
          end else if (a == 4'd0) begin
            result <= 32'd0;  // 0^b = 0 for b > 0
            done   <= 1'b1;
            rem    <= 4'd0;
          end else begin
            // Normal case: result <- 1, perform b multiplications
            result <= 32'd1;
            done   <= 1'b0;
            rem    <= b;      // rem != 0 marks busy
          end
        end else begin
          // No start pulse; keep outputs stable (result=1, done=0) in idle
          result <= 32'd1;
          done   <= 1'b0;
          rem    <= 4'd0;
        end
      end else begin
        // Performing repeated multiplication: result = result * a (b times)
        result <= result * a; // Unsigned multiplication, result truncated to 32 bits if overflow
        if (rem == 4'd1) begin
          done <= 1'b1;
          rem  <= 4'd0;
        end else begin
          done <= 1'b0;
          rem  <= rem - 1;
        end
      end
    end
  end

endmodule
