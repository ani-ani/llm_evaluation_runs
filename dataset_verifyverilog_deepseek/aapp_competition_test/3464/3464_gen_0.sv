module casino_profit_calculator(
  input clk,
  input rst_n,
  input start,
  input [15:0] x,
  input [15:0] p,
  output reg [31:0] max_profit,
  output reg done
);
  localparam MAX_BETS = 16;
  typedef enum logic [1:0] {IDLE, CALCULATING, DONE} state_t;
  state_t state;
  reg [4:0] current_n;
  reg [31:0] max_profit_reg;
  wire signed [31:0] curr_exp_profit;
  reg [31:0] scale_refund;
  reg [31:0] p_fixed;
  reg [31:0] one_minus_p_fixed;
  reg [15:0] p_saved;
  reg [15:0] x_saved;
  
  always_comb begin : ExpectedProfit
    automatic logic [31:0] sum = 0;
    automatic logic [15:0] bin_coeff;
    automatic logic [31:0] term;
    automatic logic [31:0] p_pow, q_pow;
    automatic signed [31:0] payout;
    automatic integer k;
    for (k=0; k<=current_n; k++) begin
      bin_coeff = binom(current_n, k);
      p_pow = power(p_fixed, k);
      q_pow = power(one_minus_p_fixed, current_n - k);
      term = (bin_coeff * p_pow) / (32'sd1 << 16);
      term = (term * q_pow) / (32'sd1 << 16);
      payout = (32'sd2 * k - current_n) << 16;
      if (payout < 0)
        payout = (payout * scale_refund) >> 16;
      term = (term * payout) >> 16;
      sum += term;
    end
    curr_exp_profit = sum;
  end
  
  function automatic [15:0] binom(input logic [4:0] n, input logic [4:0] k);
    if (n < k) return 0;
    else if (k == 0 || k == n) binom = 1;
    else binom = binom(n-1, k-1) + binom(n-1, k);
  endfunction
  
  function automatic [31:0] power(input [31:0] base, input integer exp);
    if (exp == 0) power = 32'h10000;
    else begin
      power = 32'sh10000;
      for (int i=0; i < exp; i++)
        power = (power * base) >> 16;
    end
  endfunction
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      max_profit_reg <= 0;
      current_n <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            p_fixed <= (p * 32'h68DB8) >> 16;
            one_minus_p_fixed <= ((10000 - p) * 32'h68DB8) >> 16;
            scale_refund <= ((10000 - x) * 32'h68DB) >> 16;
            p_saved <= p;
            x_saved <= x;
            current_n <= 0;
            state <= CALCULATING;
            done <= 0;
          end
        end
        CALCULATING: begin
          if (current_n < MAX_BETS) begin
            current_n <= current_n + 1;
            if ($signed(curr_exp_profit) > $signed(max_profit_reg))
              max_profit_reg <= curr_exp_profit;
          end else begin
            if ($signed(curr_exp_profit) > $signed(max_profit_reg))
              max_profit_reg <= curr_exp_profit;
            state <= DONE;
            done <= 1;
            max_profit <= max_profit_reg;
          end
        end
        DONE: begin
          done <= 1;
          state <= IDLE;
        end
        default: state <= IDLE;
      endcase
    end
  end
endmodule