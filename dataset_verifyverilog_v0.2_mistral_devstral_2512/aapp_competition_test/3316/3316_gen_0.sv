module lottery_probability (
  input clk,
  input rst_n,
  input start,
  input [7:0] m,
  input [7:0] n,
  input [7:0] t,
  input [7:0] p,
  output reg [31:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    CALC_KMIN,
    COMPUTE_ITER,
    DIVIDE,
    DONE
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [7:0] k_min;
  reg [7:0] k;
  reg [7:0] k_max;

  reg [47:0] numerator_acc;  // Q16.16 accumulator (48-bit for safety)
  reg [47:0] denominator;    // Q16.16 denominator (48-bit for safety)

  reg [47:0] comb_p_k;      // C(p,k) in Q16.16
  reg [47:0] comb_m_p_n_k;  // C(m-p,n-k) in Q16.16

  reg [31:0] temp_result;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      result <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = CALC_KMIN;
      end
      CALC_KMIN: next_state = COMPUTE_ITER;
      COMPUTE_ITER: begin
        if (k == k_max) next_state = DIVIDE;
      end
      DIVIDE: next_state = DONE;
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      k_min <= 0;
      k <= 0;
      k_max <= 0;
      numerator_acc <= 0;
      denominator <= 0;
      comb_p_k <= 0;
      comb_m_p_n_k <= 0;
      temp_result <= 0;
    end else begin
      case (state)
        CALC_KMIN: begin
          // Calculate k_min = ceil(p/t)
          k_min <= (p + t - 1) / t;
          k_max <= (p < n) ? p : n;
          k <= k_min;
          numerator_acc <= 0;
          denominator <= 0;
        end
        COMPUTE_ITER: begin
          // Compute C(p,k) and C(m-p,n-k)
          comb_p_k <= compute_combination(p, k);
          comb_m_p_n_k <= compute_combination(m - p, n - k);

          // Accumulate numerator: C(p,k) * C(m-p,n-k)
          numerator_acc <= numerator_acc + (comb_p_k * comb_m_p_n_k) / 65536;

          // Increment k
          if (k < k_max) begin
            k <= k + 1;
          end
        end
        DIVIDE: begin
          // Compute denominator C(m,n)
          denominator <= compute_combination(m, n);

          // Final division: numerator / denominator
          if (denominator != 0) begin
            temp_result <= (numerator_acc * 65536) / denominator;
          end else begin
            temp_result <= 0;
          end
        end
        DONE: begin
          result <= temp_result;
          done <= 1;
        end
      endcase
    end
  end

  // Combination calculation function (iterative)
  function [47:0] compute_combination(input [7:0] a, input [7:0] b);
    reg [47:0] comb;
    reg [7:0] i;
    
    if (b == 0 || a == b) begin
      comb = 65536;  // Q16.16 representation of 1
    end else if (b > a) begin
      comb = 0;
    end else begin
      comb = 65536;  // Start with 1 in Q16.16
      for (i = 1; i <= b; i = i + 1) begin
        // Multiply by (a - i + 1) and divide by i
        comb = (comb * (a - i + 1)) / i;
      end
    end
    
    return comb;
  endfunction

endmodule