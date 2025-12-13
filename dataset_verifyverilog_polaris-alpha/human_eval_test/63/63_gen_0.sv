module fibfib_calculator(
  input clk,
  input rst_n,
  input [3:0] n,
  input start,
  output reg [11:0] result,
  output reg done
);

  reg [11:0] a; // fibfib(k-3)
  reg [11:0] b; // fibfib(k-2)
  reg [11:0] c; // fibfib(k-1)
  reg [3:0]  cnt;
  reg        busy;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Initialize to base cases and idle
      a      <= 12'd0;
      b      <= 12'd0;
      c      <= 12'd1;
      cnt    <= 4'd0;
      result <= 12'd0;
      done   <= 1'b0;
      busy   <= 1'b0;
    end else begin
      // Default
      done <= 1'b0;

      if (!busy) begin
        // Wait for start pulse to begin computation
        if (start) begin
          // Initialize for new computation
          a   <= 12'd0; // fibfib(0)
          b   <= 12'd0; // fibfib(1)
          c   <= 12'd1; // fibfib(2)
          cnt <= 4'd0;
          busy <= 1'b1;
        end
      end else begin
        // Busy: perform one step per cycle
        if (cnt >= n) begin
          // Current value is ready based on n
          if (n == 4'd0) begin
            result <= 12'd0;
          end else if (n == 4'd1) begin
            result <= 12'd0;
          end else if (n == 4'd2) begin
            result <= 12'd1;
          end else begin
            // For k >= 3, c holds fibfib(k)
            result <= c;
          end
          done <= 1'b1;
          busy <= 1'b0;
        end else begin
          // cnt < n: update sequence
          if (cnt < 4'd2) begin
            // Advance through base indices 0,1,2 without changing values
            cnt <= cnt + 4'd1;
          end else begin
            // For k >= 3: next = a + b + c
            // a,b,c currently correspond to fibfib(k-3), fibfib(k-2), fibfib(k-1)
            // After update, they correspond to next step
            {a, b, c} <= {b, c, a + b + c};
            cnt <= cnt + 4'd1;
          end
        end
      end
    end
  end

endmodule