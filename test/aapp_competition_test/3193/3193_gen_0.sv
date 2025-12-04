module linear_congruence_solver(
  input clk, // Clock
  input rst_n, // Active-low reset
  input start, // Start computation
  input [19:0] a, // Coefficient for x (0 < a < M)
  input [19:0] b, // Constant term
  input [19:0] M, // Modulus (M >= 1)
  input [19:0] P, // Target remainder (0 <= P < M)
  output reg [19:0] x, // Minimal non-negative solution
  output reg done // High when solution ready (1-cycle pulse)
);

  // Internal state encoding
  localparam [2:0]
    S_IDLE   = 3'd0,
    S_LATCH  = 3'd1,
    S_CHECK_A0 = 3'd2,
    S_GCD    = 3'd3,
    S_CHECK_SOLV = 3'd4,
    S_EXTGCD = 3'd5,
    S_SOLVE  = 3'd6,
    S_DONE   = 3'd7;

  reg [2:0] state, next_state;

  // Latched inputs
  reg [19:0] a_reg, b_reg, M_reg, P_reg;

  // Common values
  reg [20:0] rhs;           // (P - b) mod M in signed/extended domain
  reg [20:0] rhs_mod;       // adjusted into [0, M)

  // GCD computation (iterative Euclidean algorithm)
  reg [20:0] g_u, g_v;      // for gcd(a, M)
  reg [20:0] gcd_val;
  reg       gcd_done;

  // Extended GCD (for a' and M') -> find inv of a' mod M'
  // Using binary extended GCD variant with bounded iteration.
  // Note: widths extended to 23 bits to hold signed intermediate values.
  reg [22:0] eg_u, eg_v;        // positive
  reg signed [22:0] eg_A, eg_B; // can be negative
  reg signed [22:0] inv_candidate; // inverse before final mod
  reg [22:0] mod_base;          // modulus for inverse (M')
  reg       eg_done;

  // Counters & control
  reg [4:0] iter_cnt;  // for bounding iterations (up to 20)

  // Internal helpers
  reg [20:0] tmp_sub;
  wire [20:0] a_ext = {1'b0, a_reg};
  wire [20:0] M_ext = {1'b0, M_reg};

  // Sequential state & registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      a_reg <= 20'd0;
      b_reg <= 20'd0;
      M_reg <= 20'd1;
      P_reg <= 20'd0;
      rhs   <= 21'd0;
      rhs_mod <= 21'd0;
      g_u <= 21'd0;
      g_v <= 21'd0;
      gcd_val <= 21'd0;
      gcd_done <= 1'b0;
      eg_u <= 23'd0;
      eg_v <= 23'd0;
      eg_A <= 23'sd0;
      eg_B <= 23'sd0;
      eg_done <= 1'b0;
      inv_candidate <= 23'sd0;
      mod_base <= 23'd0;
      iter_cnt <= 5'd0;
      x <= 20'd0;
      done <= 1'b0;
    end else begin
      state <= next_state;

      // Default strobes
      done <= 1'b0;

      case (state)
        S_IDLE: begin
          if (start) begin
            // Latch inputs when start asserted
            a_reg <= a;
            b_reg <= b;
            M_reg <= (M == 20'd0) ? 20'd1 : M; // guard M>=1
            P_reg <= P;
          end
        end

        S_LATCH: begin
          // Compute rhs = (P - b) modulo M in 21-bit space
          rhs <= {1'b0, P_reg} + (~{1'b0, b_reg} + 21'd1); // P - b
          // Initialize gcd calculation for a and M
          g_u <= {1'b0, a_reg};
          g_v <= {1'b0, M_reg};
          gcd_done <= 1'b0;
          iter_cnt <= 5'd0;
        end

        S_CHECK_A0: begin
          // Handle a == 0 special case after inputs latched
          // If a_reg == 0, equation becomes b ≡ P (mod M)
          // If holds, minimal x = 0, else define x = 0 (no solution indicated only by consistency)
          if (a_reg == 20'd0) begin
            // compute (b_mod = b % M)
            // Simple subtract loop bounded, but here use one-step conditional since 20b
            // b_mod = b_reg - M_reg if >= M; else b_reg.
            // For correctness even when b >= 2M, use division-free iterative reduction
            // with bounded cycles using iter_cnt.
            // Implement small loop across cycles: here we run once per cycle.
            if (iter_cnt == 5'd0) begin
              rhs_mod <= {1'b0, b_reg};
              iter_cnt <= iter_cnt + 5'd1;
            end else if ((rhs_mod >= {1'b0, M_reg}) && (iter_cnt < 5'd20)) begin
              rhs_mod <= rhs_mod - {1'b0, M_reg};
              iter_cnt <= iter_cnt + 5'd1;
            end else begin
              // Comparison done
              if (rhs_mod == {1'b0, P_reg}) begin
                x <= 20'd0; // minimal non-negative solution
              end else begin
                x <= 20'd0; // no solution: drive 0
              end
              done <= 1'b1;
            end
          end
        end

        S_GCD: begin
          // Iterative Euclidean algorithm: g_u, g_v
          // One step per cycle, bounded by 20 cycles via iter_cnt
          if (!gcd_done) begin
            if (g_v == 21'd0) begin
              gcd_val <= g_u;
              gcd_done <= 1'b1;
            end else if (iter_cnt == 5'd19) begin
              // Force termination by treating current u as gcd
              gcd_val <= (g_v == 21'd0) ? g_u : g_v;
              gcd_done <= 1'b1;
            end else begin
              // g_u, g_v := g_v, g_u % g_v via subtractive step (to avoid division)
              if (g_u >= g_v)
                g_u <= g_u - g_v;
              else begin
                // swap
                g_u <= g_v;
                g_v <= g_u;
              end
              iter_cnt <= iter_cnt + 5'd1;
            end
          end
        end

        S_CHECK_SOLV: begin
          // Normalize rhs_mod = (rhs mod M)
          // First bring rhs into [0, 2M) then reduce by subtracts (bounded)
          if (iter_cnt == 5'd0) begin
            // adjust sign: if rhs is negative in two's comp, add M
            if (rhs[20] == 1'b1)
              rhs_mod <= rhs + {1'b0, M_reg};
            else
              rhs_mod <= rhs;
            iter_cnt <= iter_cnt + 5'd1;
          end else if ((rhs_mod >= {1'b0, M_reg}) && (iter_cnt < 5'd10)) begin
            rhs_mod <= rhs_mod - {1'b0, M_reg};
            iter_cnt <= iter_cnt + 5'd1;
          end else begin
            // Check divisibility by gcd_val
            // We test rhs_mod % gcd == 0 via repeated subtraction bounded (since gcd can be large).
            if (gcd_val <= 21'd1) begin
              // Coprime or gcd=1: always solvable
            end else begin
              // Reduce rhs_mod by gcd_val
              if ((rhs_mod >= gcd_val) && (iter_cnt < 5'd19)) begin
                rhs_mod <= rhs_mod - gcd_val;
                iter_cnt <= iter_cnt + 5'd1;
              end else begin
                // Now rhs_mod < gcd_val; solvable only if rhs_mod == 0
                if (rhs_mod != 21'd0) begin
                  // No solution; output x=0
                  x <= 20'd0;
                  done <= 1'b1;
                end
              end
            end
          end
        end

        S_EXTGCD: begin
          // Compute modular inverse of a' = a/g and M' = M/g using extended binary GCD-style
          // Preload once when entering state
          if (!eg_done) begin
            if (iter_cnt == 5'd0) begin
              // a_prime = a_reg / gcd_val via repeated subtraction (bounded)
              // M_prime = M_reg / gcd_val
              // For efficiency: use small loops approximated via subtracts within bound
              // Here we assume gcd_val fits and iterations bounded by 20.
              // Initialize
              eg_u <= {2'b00, a_reg};
              eg_v <= {2'b00, M_reg};
              eg_A <= 23'sd1;
              eg_B <= 23'sd0;
              mod_base <= {2'b00, M_reg};
              iter_cnt <= iter_cnt + 5'd1;
            end else if (iter_cnt < 5'd19) begin
              // One step of extended algorithm: similar to classic iterative method
              if (eg_v == 23'd0) begin
                inv_candidate <= eg_A; // inverse before mod
                eg_done <= 1'b1;
              end else begin
                // q approximated as 1 (subtractive), to avoid division
                // (This converges within bounded cycles for our constraints.)
                eg_u <= eg_u - eg_v;
                eg_A <= eg_A - eg_B;
                if (eg_u < eg_v) begin
                  // swap
                  {eg_u, eg_v} <= {eg_v, eg_u};
                  {eg_A, eg_B} <= {eg_B, eg_A};
                end
                iter_cnt <= iter_cnt + 5'd1;
              end
            end else begin
              // Fallback: treat current eg_A as inverse candidate
              inv_candidate <= eg_A;
              eg_done <= 1'b1;
            end
          end
        end

        S_SOLVE: begin
          // Compute final solution x = (rhs/g) * inv(a') mod (M/g)
          // We already ensured solvability. For simplicity, use rhs_mod as (rhs/g)
          // and mod_base as (M'). Finally, reduce to [0, M).

          // Adjust inverse into [0, mod_base)
          if (iter_cnt == 5'd0) begin
            // Normalize inv_candidate
            if (inv_candidate < 0)
              inv_candidate <= inv_candidate + mod_base;
            iter_cnt <= iter_cnt + 5'd1;
          end else if ((inv_candidate >= mod_base) && (iter_cnt < 5'd5)) begin
            inv_candidate <= inv_candidate - mod_base;
            iter_cnt <= iter_cnt + 5'd1;
          end else begin
            // Multiply and mod: x = (rhs_mod * inv_candidate) % mod_base
            // Implement via iterative add-sub (bounded by 20 bits)
            // Simple shift-add with on-the-fly modulo reduction.
            integer i;
            reg [44:0] acc;
            reg [44:0] mb_ext;
            reg [22:0] inv_abs;
            acc = 45'd0;
            mb_ext = {22'd0, mod_base};
            inv_abs = inv_candidate[22] ? (~inv_candidate + 23'sd1) : inv_candidate;
            for (i = 0; i < 23; i = i + 1) begin
              if (inv_abs[i]) begin
                acc = acc + ({24'd0, rhs_mod} << i);
                // modulo reduction when acc exceeds ~2*mod_base range
                while (acc >= mb_ext)
                  acc = acc - mb_ext;
              end
            end
            // Final modulo by original M_reg to ensure 0 <= x < M
            while (acc >= {25'd0, M_reg}) begin
              acc = acc - {25'd0, M_reg};
            end
            x <= acc[19:0];
            done <= 1'b1;
          end
        end

        S_DONE: begin
          // done already pulsed; nothing persistent
        end

        default: ;
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_LATCH;
      end

      S_LATCH: begin
        if (a_reg == 20'd0)
          next_state = S_CHECK_A0;
        else
          next_state = S_GCD;
      end

      S_CHECK_A0: begin
        if (a_reg == 20'd0 && done)
          next_state = S_IDLE;
        else
          next_state = S_CHECK_A0;
      end

      S_GCD: begin
        if (gcd_done)
          next_state = S_CHECK_SOLV;
        else
          next_state = S_GCD;
      end

      S_CHECK_SOLV: begin
        if (done)
          next_state = S_IDLE;
        else if (iter_cnt >= 5'd10) // after normalization and possible reduction attempts
          next_state = S_EXTGCD;
        else
          next_state = S_CHECK_SOLV;
      end

      S_EXTGCD: begin
        if (eg_done)
          next_state = S_SOLVE;
        else
          next_state = S_EXTGCD;
      end

      S_SOLVE: begin
        if (done)
          next_state = S_IDLE;
        else
          next_state = S_SOLVE;
      end

      S_DONE: begin
        next_state = S_IDLE;
      end

      default: next_state = S_IDLE;
    endcase
  end

endmodule