module babylonian_sqrt(
  input        clk,
  input        rst_n,
  input        start,
  input  [31:0] num,      // Q16.16 input
  output reg [15:0] result, // Q8.8 output
  output reg   done
);

  // Internal registers
  reg [31:0] g;                 // current guess in Q16.16
  reg [31:0] n_reg;             // latched input number Q16.16
  reg [3:0]  iter_cnt;          // iteration counter (0-10)
  reg        busy;              // indicates computation in progress
  reg        start_d;           // delayed start for edge detection

  // Combinational signals
  reg        start_pulse;
  reg [31:0] div_result;        // num / g (Q16.16)
  reg [31:0] new_guess;         // next guess (Q16.16)

  // ------------------------------
  // Simple edge detector for start
  // ------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      start_d <= 1'b0;
    else
      start_d <= start;
  end

  always @(*) begin
    start_pulse = start & ~start_d;
  end

  // ------------------------------
  // Gate-level safe 32-bit unsigned divider
  // Computes: dividend / divisor (Q16.16 maintained by scaling)
  // Here used as: (n_reg << 16) / g to get Q16.16 result
  // ------------------------------
  function automatic [31:0] safe_div_q16;
    input [31:0] dividend_q16;   // treated as Q16.16
    input [31:0] divisor_q16;    // treated as Q16.16
    reg   [63:0] dividend_ext;
    reg   [63:0] quotient;
    reg   [63:0] remainder;
    integer i;
  begin
    // Protect against zero divisor; return max value (no X)
    if (divisor_q16 == 32'd0) begin
      safe_div_q16 = 32'hFFFF_FFFF;
    end else begin
      // Implement restoring division: integer division of 64b / 32b
      dividend_ext = {dividend_q16, 32'd0}; // left shift to maintain Q16.16 scaling when dividing by Q16.16
      quotient     = 64'd0;
      remainder    = 64'd0;

      for (i = 63; i >= 0; i = i - 1) begin
        remainder = {remainder[62:0], dividend_ext[i]};
        if (remainder[63:32] >= divisor_q16) begin
          remainder[63:32] = remainder[63:32] - divisor_q16;
          quotient[i]      = 1'b1;
        end else begin
          quotient[i]      = 1'b0;
        end
      end

      // quotient is Q16.16 result
      safe_div_q16 = quotient[31:0];
    end
  end
  endfunction

  // ------------------------------
  // Main sequential control & iteration
  // ------------------------------
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      g        <= 32'd0;
      n_reg    <= 32'd0;
      iter_cnt <= 4'd0;
      busy     <= 1'b0;
      result   <= 16'd0;
      done     <= 1'b0;
    end else begin
      done <= 1'b0; // default

      // Start of new operation
      if (start_pulse && !busy) begin
        n_reg <= num;
        if (num == 32'd0) begin
          // Special case: zero input -> result zero, done next cycle
          g        <= 32'd0;
          iter_cnt <= 4'd10; // directly mark as complete path
          busy     <= 1'b1;
        end else begin
          // Initialize guess g = num/2 in Q16.16
          g        <= {num[31], num[30:1]}; // arithmetic shift right by 1 (since Q16.16 signed-like behavior not needed, but safe)
          iter_cnt <= 4'd0;
          busy     <= 1'b1;
        end
      end else if (busy) begin
        // When busy, perform up to 10 iterations
        if (iter_cnt < 4'd10) begin
          if (iter_cnt == 4'd9) begin
            // 10th cycle: finalize result from current guess g
            // Q16.16 -> Q8.8 by discarding 8 LSB fractional bits
            result <= g[23:8];
            done   <= 1'b1;
            busy   <= 1'b0;
            iter_cnt <= iter_cnt + 1'b1;
          end else begin
            // Iterative Babylonian update:
            // new_g = (g + num/g) / 2

            // Compute num/g in Q16.16 using safe division
            div_result <= safe_div_q16(n_reg, g);

            // Note: Use non-blocking for actual state update
            // new_guess = (g + div_result) >> 1
            new_guess <= (g + div_result) >> 1;

            // Apply updated guess for next iteration
            g        <= (g + div_result) >> 1;
            iter_cnt <= iter_cnt + 1'b1;
          end
        end else begin
          // Safety: if iter_cnt >= 10, clear busy
          busy <= 1'b0;
        end
      end
    end
  end

endmodule
