module frog_flower_sync(
  input clk, // Clock
  input rst_n, // Active-low reset
  input start, // Start computation
  input [15:0] m, // Modulo value (2 ≤ m ≤ 65535)
  input [15:0] h1, a1, x1, y1, // Frog parameters (h1 ≠ a1)
  input [15:0] h2, a2, x2, y2, // Flower parameters (h2 ≠ a2)
  output reg [11:0] time_out, // Minimum sync time (0-3071)
  output reg done, // High when finished
  output reg fail // High if no solution found
);

  // Internal state registers
  reg [15:0] cur_h1;
  reg [15:0] cur_h2;
  reg [11:0] cycle_cnt;
  reg        active; // Indicates computation in progress

  // Next-state wires
  wire [31:0] mult1 = cur_h1 * x1;
  wire [31:0] mult2 = cur_h2 * x2;
  wire [31:0] sum1  = mult1 + y1;
  wire [31:0] sum2  = mult2 + y2;

  // Simple iterative modulo using truncation is not valid; use '%' operator.
  wire [15:0] next_h1 = sum1 % m;
  wire [15:0] next_h2 = sum2 % m;

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Asynchronous reset
      cur_h1    <= 16'd0;
      cur_h2    <= 16'd0;
      cycle_cnt <= 12'd0;
      time_out  <= 12'd0;
      done      <= 1'b0;
      fail      <= 1'b0;
      active    <= 1'b0;
    end else begin
      if (!start) begin
        // Idle / hold state when start is low
        cur_h1    <= h1;
        cur_h2    <= h2;
        cycle_cnt <= 12'd0;
        time_out  <= 12'd0;
        done      <= 1'b0;
        fail      <= 1'b0;
        active    <= 1'b0;
      end else begin
        // Start asserted
        if (!active) begin
          // Initialize computation on first active cycle
          cur_h1    <= h1;
          cur_h2    <= h2;
          cycle_cnt <= 12'd0;
          time_out  <= 12'd0;
          done      <= 1'b0;
          fail      <= 1'b0;
          active    <= 1'b1;
        end else if (!done) begin
          // Perform next LCG step while searching
          cur_h1    <= next_h1;
          cur_h2    <= next_h2;
          cycle_cnt <= cycle_cnt + 12'd1;

          // Check for simultaneous match using updated values
          if ((next_h1 == a1) && (next_h2 == a2)) begin
            done     <= 1'b1;
            fail     <= 1'b0;
            time_out <= cycle_cnt + 12'd1;
            active   <= 1'b0;
          end else if (cycle_cnt == 12'hFFF) begin
            // Exceeded 3072 cycles (0..3071); no solution found
            done     <= 1'b1;
            fail     <= 1'b1;
            time_out <= 12'd0;
            active   <= 1'b0;
          end
        end
      end
    end
  end

endmodule