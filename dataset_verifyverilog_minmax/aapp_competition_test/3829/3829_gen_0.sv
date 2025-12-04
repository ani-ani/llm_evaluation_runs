module dice_expectation (
  input clk,
  input rst_n,
  input start,
  input [2:0] m,
  input [3:0] n,
  output reg [31:0] result,
  output reg done
);

  // Q16.16 fixed-point helpers
  function [31:0] q16_16_one;
    q16_16_one = 32'h00010000; // 1.0 in Q16.16
  endfunction

  function [31:0] q16_16_half;
    q16_16_half = 32'h00008000; // 0.5 in Q16.16
  endfunction

  // State encoding
  typedef enum logic [3:0] {
    S_IDLE        = 4'd0,
    S_INV_A       = 4'd1,  // Stage 1: compute 1/m (a/b) using 65536/m
    S_INV_B       = 4'd2,  // Stage 2: register 1/m
    S_TERM_PREP   = 4'd3,  // Setup for each term (i * 1/m)
    S_MUL         = 4'd4,  // Multiplication cycle for pow
    S_MUL_DONE    = 4'd5,  // Latch mult result
    S_SUM         = 4'd6,  // Accumulate term into sum
    S_DONE_PULSE  = 4'd7
  } state_t;

  state_t state, state_next;

  // Counters
  logic [3:0] i_cnt, i_cnt_next;     // i from 1..m-1
  logic [3:0] j_cnt, j_cnt_next;     // exponent loop 0..n
  logic [3:0] m_reg, m_next;
  logic [3:0] n_reg, n_next;

  // Fixed-point registers
  logic [31:0] inv_m, inv_m_next;          // 1/m in Q16.16
  logic [31:0] base, base_next;            // (i/m) in Q16.16
  logic [31:0] pow_val, pow_val_next;      // current power
  logic [31:0] sum_q, sum_q_next;          // sum((i/m)^n) in Q16.16

  // Multiplication pipeline (combinational compute; registered result next cycle)
  logic [31:0] mult_a, mult_b;
  logic [63:0] prod_raw;
  logic [31:0] prod_rounded;
  assign prod_raw = $signed({1'b0, mult_a}) * $signed({1'b0, mult_b});
  // Round-to-nearest, ties away from zero (add 0.5 LSB in Q16.16)
  assign prod_rounded = prod_raw[47:16] + ((prod_raw[15] == 1'b1) ? 1 : 0);

  // Control flops
  logic valid_mult, valid_mult_next;

  // Sequential logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      i_cnt <= 4'd0;
      j_cnt <= 4'd0;
      m_reg  <= 4'd1;
      n_reg  <= 4'd0;
      inv_m  <= 32'h0;
      base   <= 32'h0;
      pow_val<= 32'h0;
      sum_q  <= 32'h0;
      valid_mult <= 1'b0;
      result <= 32'h0;
      done   <= 1'b0;
    end else begin
      state <= state_next;
      i_cnt <= i_cnt_next;
      j_cnt <= j_cnt_next;
      m_reg  <= m_next;
      n_reg  <= n_next;
      inv_m  <= inv_m_next;
      base   <= base_next;
      pow_val<= pow_val_next;
      sum_q  <= sum_q_next;
      valid_mult <= valid_mult_next;
      result <= 32'h0; // default; will set in DONE_PULSE
      done   <= 1'b0;  // default; will set pulse in DONE_PULSE
    end
  end

  // Combinational next-state logic
  always_comb begin
    // defaults
    state_next = state;
    i_cnt_next = i_cnt;
    j_cnt_next = j_cnt;
    m_next     = m_reg;
    n_next     = n_reg;
    inv_m_next = inv_m;
    base_next  = base;
    pow_val_next = pow_val;
    sum_q_next = sum_q;
    valid_mult_next = valid_mult;

    // Inputs to multiplier
    mult_a = 32'h0;
    mult_b = 32'h0;

    case (state)
      S_IDLE: begin
        if (start) begin
          m_next = m;
          n_next = n;
          sum_q_next = 32'h0;
          inv_m_next = 32'h0;
          i_cnt_next = 4'd1; // will start with i=1
          j_cnt_next = 4'd0;
          state_next = S_INV_A;
        end else begin
          state_next = S_IDLE;
        end
      end

      // 1/m computation: 65536/m (Q16.16)
      S_INV_A: begin
        inv_m_next = (m_reg == 3'd0) ? 32'h0 : (32'h00010000 / {29'b0, m_reg});
        state_next = S_INV_B;
      end

      S_INV_B: begin
        state_next = S_TERM_PREP;
      end

      // Setup (i * 1/m) for current i
      S_TERM_PREP: begin
        // If m <= 1, skip loop and go to done
        if (m_reg <= 3'd1) begin
          state_next = S_DONE_PULSE;
        end else begin
          base_next = (inv_m * {29'b0, i_cnt});
          pow_val_next = q16_16_one(); // start at 1.0
          state_next = S_MUL;
        end
      end

      // Multiply cycle for exponentiation
      S_MUL: begin
        // if n==0, skip exponentiation loop entirely (pow stays 1.0)
        if (n_reg == 4'd0) begin
          state_next = S_SUM;
        end else begin
          mult_a = pow_val;
          mult_b = base;
          valid_mult_next = 1'b1;
          state_next = S_MUL_DONE;
        end
      end

      // Latch multiplication result and update exponent counter
      S_MUL_DONE: begin
        if (valid_mult) begin
          pow_val_next = prod_rounded;
        end
        valid_mult_next = 1'b0;
        // increment exponent loop counter
        j_cnt_next = j_cnt + 1;
        // decide next step: another multiply or go to sum
        if (j_cnt + 1 >= n_reg) begin
          state_next = S_SUM;
        end else begin
          state_next = S_MUL;
        end
      end

      // Accumulate this term
      S_SUM: begin
        sum_q_next = sum_q + pow_val;
        i_cnt_next = i_cnt + 1;
        // if all terms processed, finalize
        if (i_cnt + 1 >= m_reg) begin
          state_next = S_DONE_PULSE;
        end else begin
          state_next = S_TERM_PREP;
        end
      end

      // Finalize result and pulse done
      S_DONE_PULSE: begin
        // E = m - sum_q; all in Q16.16
        // m (integer) in Q16.16 is m * 65536
        result = ({29'b0, m_reg} << 16) - sum_q;
        done   = 1'b1;
        state_next = S_IDLE;
      end

      default: begin
        state_next = S_IDLE;
      end
    endcase
  end

endmodule
