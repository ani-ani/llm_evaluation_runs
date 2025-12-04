module palindromic_sequence_counter(
  input clk, // clock
  input rst_n, // active-low reset
  input start, // pulse high to start computation
  input [15:0] N, // sequence length (1 ≤ N ≤ 65535)
  input [15:0] K, // max element value (1 ≤ K ≤ 65535)
  output reg [31:0] result, // final answer
  output reg done // high when computation finished
);
  parameter MOD = 32'd1000000007;
  parameter MAX_DIVISORS = 6'd32; // hard cap to meet ≤70 cycle constraint
  parameter IDLE = 3'd0;
  parameter PRECOMP_POW = 3'd1;
  parameter FIND_DIVS = 3'd2;
  parameter PROCESS_DIV = 3'd3;
  parameter COMPLETE = 3'd4;

  reg [2:0] state, next_state;
  reg [15:0] n_q, k_q;
  reg [5:0] div_count; // number of divisors found (capped to MAX_DIVISORS)
  reg [15:0] divisors [0:MAX_DIVISORS-1];
  reg [5:0] div_idx; // index into divisors during processing
  reg [5:0] p2_idx;  // index for precomputed powers-of-two
  reg [31:0] k_pows [0:15]; // K^(2^i) mod MOD for i=0..15
  reg [31:0] ans;
  reg [31:0] sum_prev_terms; // Σ_{d'<d} term(d')

  // Internal helpers
  function [31:0] mul_mod;
    input [31:0] a;
    input [31:0] b;
    logic [63:0] t;
  begin
    t = 64'(a) * 64'(b);
    mul_mod = t[31:0]; // MOD fits in 32 bits, truncation mod 2^32 is equivalent to mod 2^32
    // Apply MOD correction if needed (optional; safe and cheap)
    if (mul_mod >= MOD) mul_mod = mul_mod - MOD; // at most one correction needed here due to MOD < 2^31
  end
  endfunction

  // K^e built from precomputed K^(2^i)
  function [31:0] pow_from_cache;
    input [15:0] e;
    reg [31:0] acc;
    reg [15:0] tmp;
    integer i;
  begin
    acc = 32'd1;
    tmp = e;
    for (i = 0; i < 16; i = i + 1) begin
      if (tmp[0]) acc = mul_mod(acc, k_pows[i]);
      tmp = tmp >> 1;
    end
    pow_from_cache = acc;
  end
  endfunction

  // Sequential logic with synchronous reset
  always @(posedge clk) begin
    if (!rst_n) begin
      state <= IDLE;
      n_q <= 16'd0;
      k_q <= 16'd0;
      div_count <= 6'd0;
      div_idx <= 6'd0;
      p2_idx <= 6'd0;
      ans <= 32'd0;
      sum_prev_terms <= 32'd0;
      result <= 32'd0;
      done <= 1'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            n_q <= N;
            k_q <= K;
            div_count <= 6'd0;
            div_idx <= 6'd0;
            p2_idx <= 6'd0;
            ans <= 32'd0;
            sum_prev_terms <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
            // Begin power precomputation on next cycle
            state <= PRECOMP_POW;
          end else begin
            state <= IDLE;
          end
        end

        // Precompute K^(2^i) for i=0..15 in 16 cycles
        PRECOMP_POW: begin
          if (p2_idx == 6'd0) begin
            k_pows[0] <= mul_mod(k_q % MOD, k_q % MOD); // K^2
          end else begin
            k_pows[p2_idx] <= mul_mod(k_pows[p2_idx-1], k_pows[p2_idx-1]); // (K^(2^(i-1)))^2
          end
          if (p2_idx == 6'd15) begin
            // Move to divisor finding after precompute
            state <= FIND_DIVS;
            p2_idx <= 6'd0;
          end else begin
            p2_idx <= p2_idx + 1'b1;
            state <= PRECOMP_POW;
          end
        end

        // Enumerate divisors up to MAX_DIVISORS; handle remainder (N mod i == 0)
        FIND_DIVS: begin
          if (div_count >= MAX_DIVISORS) begin
            // cap reached, go process
            state <= PROCESS_DIV;
          end else if (div_count == 6'd0) begin
            // always include 1
            divisors[0] <= 16'd1;
            div_count <= 6'd1;
            // Start i at 2
            div_idx <= 16'd2; // reuse div_idx as 'i' in this state
            state <= FIND_DIVS;
          end else begin
            // div_idx holds current 'i'
            if (div_idx <= n_q) begin
              if ((n_q % div_idx) == 16'd0) begin
                divisors[div_count] <= div_idx;
                div_count <= div_count + 1'b1;
              end
              div_idx <= div_idx + 1'b1;
              state <= FIND_DIVS;
            end else begin
              // done scanning
              state <= PROCESS_DIV;
            end
          end
        end

        // Process divisors in ascending order (stored order), 1 per cycle
        PROCESS_DIV: begin
          if (div_idx >= div_count) begin
            state <= COMPLETE;
          end else begin
            // term(d) = K^ceil(d/2) - sum_prev_terms mod MOD
            // ceil(d/2) = (d+1)/2 for integer d
            // Compute K^((d+1)/2) using precomputed powers
            // Note: K^1 is k_q % MOD, which is also K^(2^0) is K^2, so we handle e=1 separately.
            // However, we only stored K^(2^i). To get K^1, we can compute K^1 = K, which is in k_q.
            // We'll construct e=(d+1)>>1 and multiply by K if e was odd before shifting? No: we need K^e, not K^(2e).
            // We'll build K^((d+1)/2) by binary method from caches. For e<=32768, bits up to 15 are enough.
            // The caches start from 2^0, so e==1 case: acc stays 1, but we need to multiply by K once.
            // We'll handle the special case inline using a small block below.
            
            // Compute e = (d+1)/2
            [15:0] d_val;
            [15:0] e_val;
            d_val = divisors[div_idx];
            e_val = (d_val + 16'd1) >> 1; // ceil(d/2)

            // Build K^e_val using cached K^(2^i)
            [31:0] ke_val;
            reg [31:0] acc_pow;
            reg [15:0] tmp_e;
            integer j;
            acc_pow = 32'd1;
            tmp_e = e_val;
            for (j = 0; j < 16; j = j + 1) begin
              if (tmp_e[0]) acc_pow = mul_mod(acc_pow, k_pows[j]);
              tmp_e = tmp_e >> 1;
            end
            // If e_val is 0 (cannot happen here as d>=1), ke_val would be 1.
            // If e_val == 1, above loop yields 1 because no bit is set. Fix it:
            if (e_val == 16'd1) acc_pow = (k_q % MOD);
            ke_val = acc_pow;

            // term = (ke_val + MOD - sum_prev_terms) % MOD
            [31:0] term;
            term = ke_val + MOD - sum_prev_terms;
            if (term >= MOD) term = term - MOD;

            // contribution: if d is odd -> d * term, else -> (d/2) * term
            [31:0] mult_factor;
            [31:0] contrib;
            if (d_val[0]) begin // odd
              mult_factor = 32'(d_val);
            end else begin // even
              mult_factor = 32'(d_val >> 1);
            end
            contrib = mul_mod(mult_factor, term);
            ans <= ans + contrib;
            if (ans >= MOD) ans <= ans - MOD;

            sum_prev_terms <= sum_prev_terms + term;
            if (sum_prev_terms >= MOD) sum_prev_terms <= sum_prev_terms - MOD;

            div_idx <= div_idx + 1'b1;
            state <= PROCESS_DIV;
          end
        end

        COMPLETE: begin
          result <= ans;
          done <= 1'b1;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

  // combinational next-state (optional, not strictly required but kept for clarity)
  always_comb begin
    case (state)
      IDLE: next_state = start ? PRECOMP_POW : IDLE;
      PRECOMP_POW: next_state = (p2_idx == 6'd15) ? FIND_DIVS : PRECOMP_POW;
      FIND_DIVS: next_state = (div_count >= MAX_DIVISORS) ? PROCESS_DIV :
                              (div_count == 6'd0 ? FIND_DIVS :
                              (div_idx > n_q ? PROCESS_DIV : FIND_DIVS));
      PROCESS_DIV: next_state = (div_idx >= div_count) ? COMPLETE : PROCESS_DIV;
      COMPLETE: next_state = IDLE;
      default: next_state = IDLE;
    endcase
  end

endmodule
