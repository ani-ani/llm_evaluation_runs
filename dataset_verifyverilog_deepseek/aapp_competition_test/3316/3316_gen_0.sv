module lottery_probability (input clk, input rst_n, input start, input [4:0] m, input [3:0] n, input [3:0] t, input [4:0] p, output reg [31:0] probability, output reg done);
  reg [4:0] cycle;
  reg [4:0] m_reg, n_reg, t_reg, p_reg;
  reg [3:0] k, k_min, k_max;
  reg [31:0] numerator, denominator_val;
  
  // Calculate Combinatorial with protection
  function automatic [15:0] comb(input [4:0] n, input [4:0] k);
    reg [31:0] res;
    integer i;
    begin
      if (k > n) comb = 0;
      else if (k == 0 || k == n) comb = 1;
      else begin
        if (k > n - k) k = n - k; // Optimize
        res = 1;
        for (i = 1; i <= k; i = i + 1) begin
          res = res * (n - i + 1) / i;
        end
        comb = res[15:0];
      end
    end
  endfunction
  
  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 0;
      probability <= 0;
      cycle <= 0;
    end else if (cycle == 5'd0) begin
      // IDLE state
      done <= 0;
      probability <= 0;
      if (start) begin
        m_reg <= m;
        n_reg <= n;
        t_reg <= t;
        p_reg <= p;
        k_min <= (p + t - 1) / t; // ceil(p/t)
        cycle <= cycle + 1;
        numerator <= 0;
      end
    end else if (cycle < 5'd9) begin
      // Processing k terms (8 cycles)
      if (cycle == 1) begin
        // Calculate k_max = min(n_reg, p_reg, n_reg - (m_reg - p_reg >= 0 ? m_reg - p_reg : 0)) but simpler
        k_max <= (n_reg < p_reg) ? n_reg : p_reg;
        k <= k_min;
        denominator_val <= comb(m_reg, n_reg);
      end else if (cycle > 1 && cycle < 5'd9) begin
        if (k <= k_max && k <= n_reg && (n_reg - k) <= (m_reg - p_reg)) begin
          numerator <= numerator + (comb(p_reg, k) * comb(m_reg - p_reg, n_reg - k));
          k <= k + 1;
        end
      end
      cycle <= cycle + 1;
    end else if (cycle < 5'd20) begin
      // 11 cycles for division
      reg [47:0] dividend;
      reg [15:0] divisor;
      reg [31:0] quot;
      dividend = numerator << 16;
      divisor = denominator_val;
      if (divisor == 0) quot = 0;
      else quot = dividend / divisor;
      probability <= quot;
      cycle <= cycle + 1;
      if (cycle == 5'd19) done <= 1;
    end else if (cycle == 5'd20) begin
      done <= 0;
      cycle <= 0;
    end
  end
endmodule