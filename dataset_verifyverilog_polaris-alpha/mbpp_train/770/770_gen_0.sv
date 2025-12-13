module odd_power_sum (
  input        clk,
  input        rst_n,
  input        start,
  input  [7:0] n,
  output reg [39:0] sum = 40'd0,
  output reg       done = 1'b0
);

  // Internal registers
  reg [7:0]  n_reg;         // Latched n
  reg [7:0]  idx;           // Current term index i (1..n)
  reg [8:0]  odd;           // Current odd number (2i-1), max 509 fits in 9 bits
  reg        busy;          // Computation in progress

  // Combinational for (2i-1)^4
  wire [17:0] odd_sq;       // odd^2 (max 509^2 = 259081 < 2^18)
  wire [35:0] odd_fourth;   // odd^4 (max < 2^36)

  assign odd_sq     = odd * odd;
  assign odd_fourth = odd_sq * odd_sq;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      sum  <= 40'd0;
      done <= 1'b0;
      n_reg <= 8'd0;
      idx <= 8'd0;
      odd <= 9'd1;
      busy <= 1'b0;
    end else begin
      // Default done low unless just finished
      done <= 1'b0;

      if (start && !busy) begin
        // Start new computation
        n_reg <= n;
        idx   <= 8'd1;
        odd   <= 9'd1;      // first odd = 1
        sum   <= 40'd0;
        busy  <= (n != 8'd0);
        if (n == 8'd0) begin
          // For n=0, result is 0 and done immediately
          done <= 1'b1;
        end
      end else if (busy) begin
        // Accumulate current term
        sum <= sum + {4'd0, odd_fourth}; // extend to 40 bits

        if (idx == n_reg) begin
          // Completed n terms
          busy <= 1'b0;
          done <= 1'b1;
        end else begin
          // Prepare next term
          idx <= idx + 8'd1;
          odd <= odd + 9'd2;
        end
      end
    end
  end

endmodule