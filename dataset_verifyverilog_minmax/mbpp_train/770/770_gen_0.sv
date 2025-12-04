// odd_power_sum: Computes sum of (2*i-1)^4 for i=1..n, one term per clock
module odd_power_sum (
  input clk,
  input rst_n,
  input start,
  input [7:0] n,
  output reg [39:0] sum = 0,
  output reg done = 0
);

  // State and control
  reg run;                 // 1 while computing
  reg [7:0] cap_n;         // captured n on start
  reg [7:0] count;         // current i (1..n)

  // Next-state logic
  always @(*) begin
    if (!rst_n) begin
      run = 1'b0;
      cap_n = 8'b0;
      count = 8'b0;
      sum = 40'b0;
      done = 1'b0;
    end else begin
      if (start) begin
        run  = 1'b1;
        cap_n = n;
        count = 8'b1;     // start at i=1
        sum   = 40'b0;
        done  = 1'b0;
      end else if (run) begin
        if (count == cap_n) begin
          run  = 1'b0;
          cap_n = cap_n;
          count = cap_n;
          sum   = sum;
          done  = 1'b1;
        end else begin
          run  = 1'b1;
          cap_n = cap_n;
          count = count + 1;
          sum   = sum;
          done  = 1'b0;
        end
      end else begin
        run  = 1'b0;
        cap_n = cap_n;
        count = count;
        sum   = sum;
        done  = 1'b0;
      end
    end
  end

  // Sequential update (when running, compute one term per cycle)
  always @(posedge clk) begin
    if (!rst_n) begin
      // stay reset
    end else if (start) begin
      // initialized by comb block above
    end else if (run) begin
      // current odd number for this cycle (count was already incremented by comb block)
      reg [15:0] odd;
      reg [31:0] odd2;
      reg [63:0] odd4;

      odd  = (2 * count) - 1;
      odd2 = odd * odd;
      odd4 = odd2 * odd2;
      sum  = sum + odd4[39:0];
    end
  end

endmodule