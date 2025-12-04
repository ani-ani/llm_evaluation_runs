module lucas_number(
  input clk,             // Clock
  input rst_n,           // Active-low reset
  input start,           // Start computation (pulse)
  input [3:0] n,         // Lucas number index (0-15)
  
  output reg [10:0] result,  // Lucas number value (11-bit output)
  output reg done        // High when computation is complete
);

  // Internal registers
  reg [3:0] count;       // Iteration counter
  reg [10:0] prev2;      // L(k-2)
  reg [10:0] prev1;      // L(k-1)
  reg state;             // 0=IDLE/READY, 1=COMPUTING

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all registers
      state <= 1'b0;
      done <= 1'b0;
      result <= 11'd0;
      prev1 <= 11'd0;
      prev2 <= 11'd0;
      count <= 4'd0;
    end
    else begin
      if (state == 1'b0) begin
        if (done == 1'b0) begin
          if (start == 1'b1) begin
            // Start new computation from IDLE
            prev1 <= 11'd0;
            prev2 <= 11'd0;
            count <= 4'd0;
            if (n == 4'd0) begin
              result <= 11'd2;
              done <= 1'b1;
              state <= 1'b0;
            end
            else if (n == 4'd1) begin
              result <= 11'd1;
              done <= 1'b1;
              state <= 1'b0;
            end
            else begin
              // Initialize for iterative computation
              prev2 <= 11'd2;   // L0
              prev1 <= 11'd1;   // L1
              count <= 4'd0;    // Start iteration counter
              state <= 1'b1;
              done <= 1'b0;
            end
          end
        end
        else begin
          // In DONE state, wait for reset or new start
          if (start == 1'b1) begin
            prev1 <= 11'd0;
            prev2 <= 11'd0;
            count <= 4'd0;
            if (n == 4'd0) begin
              result <= 11'd2;
              done <= 1'b1;
            end
            else if (n == 4'd1) begin
              result <= 11'd1;
              done <= 1'b1;
            end
            else begin
              prev2 <= 11'd2;
              prev1 <= 11'd1;
              count <= 4'd0;
              state <= 1'b1;
              done <= 1'b0;
            end
          end
        end
      end
      else begin
        // COMPUTING state
        if (count == (n - 1)) begin
          // Completed (n-1) iterations
          result <= prev1;
          done <= 1'b1;
          state <= 1'b0;
        end
        else begin
          // Perform one iteration
          prev2 <= prev1;
          prev1 <= prev1 + prev2;  // L(k) = L(k-1) + L(k-2)
          count <= count + 1;
        end
      end
    end
  end
endmodule