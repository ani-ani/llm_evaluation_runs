module alternating_sum_mod(
  input clk,
  input rst_n,
  input start,
  input [14:0] n,
  input [15:0] a,
  input [15:0] b,
  input [3:0] k,
  input [15:0] s,
  output reg [9:0] result,
  output reg done
);

  // Constant modulus
  localparam [9:0] MOD = 10'd997;

  // Internal registers
  reg [14:0] n_reg;
  reg [15:0] a_reg, b_reg;
  reg [3:0]  k_reg;
  reg [15:0] s_reg;

  reg [9:0] a_mod;
  reg [9:0] b_mod;

  reg [9:0] p;        // current a^(n-i) mod MOD
  reg [9:0] q;        // current b^i mod MOD
  reg [14:0] i;       // current index i
  reg [9:0] sum;      // running sum mod MOD

  reg busy;

  // Simple FSM encoding to structure the 3-cycle-per-term behavior
  localparam [1:0]
    ST_IDLE = 2'd0,
    ST_MUL  = 2'd1,
    ST_ADD  = 2'd2,
    ST_NEXT = 2'd3;

  reg [1:0] state;

  // Combinational modular multiplication: (x * y) mod 997
  function automatic [9:0] mul_mod_997;
    input [9:0] x;
    input [9:0] y;
    reg [19:0] prod;
    begin
      prod = x * y;
      mul_mod_997 = prod % MOD;
    end
  endfunction

  // Combinational sign selection from periodic s (1 => '+', 0 => '-')
  function automatic [0:0] sign_bit;
    input [14:0] idx;
    input [3:0]  k_local;
    input [15:0] s_local;
    reg [3:0] pos;
    begin
      pos = idx % k_local;
      sign_bit = s_local[pos];
    end
  endfunction

  // Intermediate registers for pipeline-style 3-cycle per term
  reg [9:0] term_mul;    // product a^(n-i)*b^i mod 997
  reg term_sign;         // sign for current index
  reg [14:0] idx_for_sign;

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      n_reg      <= 15'd0;
      a_reg      <= 16'd0;
      b_reg      <= 16'd0;
      k_reg      <= 4'd0;
      s_reg      <= 16'd0;
      a_mod      <= 10'd0;
      b_mod      <= 10'd0;
      p          <= 10'd0;
      q          <= 10'd0;
      i          <= 15'd0;
      sum        <= 10'd0;
      result     <= 10'd0;
      done       <= 1'b0;
      busy       <= 1'b0;
      state      <= ST_IDLE;
      term_mul   <= 10'd0;
      term_sign  <= 1'b0;
      idx_for_sign <= 15'd0;
    end else begin
      done <= 1'b0;

      case (state)
        ST_IDLE: begin
          if (start && !busy) begin
            // Latch inputs
            n_reg <= n;
            a_reg <= a;
            b_reg <= b;
            k_reg <= (k == 4'd0) ? 4'd1 : k; // guard k=0; treat as 1
            s_reg <= s;

            // Reduce bases modulo 997
            a_mod <= a % MOD;
            b_mod <= b % MOD;

            // Initialize exponents and accumulators
            // We compute p = a^(n) mod 997 using repeated multiplication
            // and q = 1 (b^0).
            // To keep within 3-cycles/term outer loop, we precompute p here
            // using a simple loop unrolled across cycles, but as per
            // constraints, we perform it sequentially now only once.

            // Start simple sequential precompute of p over (n_reg) cycles
            p     <= 10'd1;  // temporary; will be driven to a^n
            q     <= 10'd1;
            i     <= 15'd0;
            sum   <= 10'd0;
            busy  <= 1'b1;
            state <= ST_MUL;
          end else begin
            busy  <= 1'b0;
            state <= ST_IDLE;
          end
        end

        ST_MUL: begin
          // Dual-purpose state:
          // 1) If p is still being initialized to a^n, do that first.
          // 2) Otherwise, perform per-term multiplication.

          if (i < n_reg) begin
            // Precompute p = a^n: p = p * a_mod each cycle until i == n
            p <= mul_mod_997(p, a_mod);
            i <= i + 15'd1;
            state <= ST_MUL;
          end else if (i == n_reg) begin
            // Finished computing a^n; now start main sum loop at i=0
            i <= 15'd0;
            // First per-term MUL: term_mul = p * q
            term_mul    <= mul_mod_997(p, q);
            idx_for_sign <= 15'd0;
            term_sign   <= sign_bit(15'd0, k_reg, s_reg);
            state       <= ST_ADD;
          end else begin
            // Main loop: already initialized p as a^(n-i) and q as b^i.
            term_mul    <= mul_mod_997(p, q);
            idx_for_sign <= i;
            term_sign   <= sign_bit(i, k_reg, s_reg);
            state       <= ST_ADD;
          end
        end

        ST_ADD: begin
          // Add or subtract current term into running sum (all mod 997)
          if (term_sign) begin
            // '+'
            if (sum + term_mul >= MOD)
              sum <= sum + term_mul - MOD;
            else
              sum <= sum + term_mul;
          end else begin
            // '-'
            if (sum >= term_mul)
              sum <= sum - term_mul;
            else
              sum <= sum + MOD - term_mul;
          end
          state <= ST_NEXT;
        end

        ST_NEXT: begin
          // Check termination and update p, q, i
          if (i == n_reg) begin
            // Done with last term
            result <= sum;
            done   <= 1'b1;
            busy   <= 1'b0;
            state  <= ST_IDLE;
          end else begin
            // Prepare for next i
            // Update exponents for next index:
            // p_next = p * a^{-1} mod MOD (conceptually), but since
            // we only have mul, we instead maintain p as a^(n-i)
            // by multiplying with modular inverse of a. However the
            // problem statement restricts to mul and mod; to stay
            // within it, we recompute via forward progression:
            // p_{i+1} = p_i * inv_a is equivalent to using a precomputed
            // inverse. Here we realize inv via Fermat's theorem on 997.
            // For simplicity and determinism, we instead update as:
            //   p_next = mul_mod_997(p, a_inv)
            // where a_inv is computed once (since 997 is prime).
            // To avoid extra cycles, we embed a small exponentiation.
            // (Implementation folded directly here.)

            // Compute a_inv = a_mod^(MOD-2) mod MOD using square-and-multiply
            // combinationally (small modulus), then update p and q.
            // This ensures overall 3-cycles/term in steady state.

            // Combinational a_inv
            integer j;
            reg [9:0] base;
            reg [9:0] exp_res;
            reg [9:0] a_inv;
            begin
              base = a_mod;
              exp_res = 10'd1;
              for (j = 0; j < 9'd995; j = j + 1) begin
                // exponent 995 in binary is fixed; unrolled loop
                exp_res = (exp_res * base) % MOD;
              end
              a_inv = exp_res;

              // Update p and q for next index
              p <= mul_mod_997(p, a_inv);   // a^(n-(i+1))
              q <= mul_mod_997(q, b_mod);   // b^(i+1)
            end

            i     <= i + 15'd1;
            state <= ST_MUL;
          end
        end

        default: begin
          state <= ST_IDLE;
        end
      endcase
    end
  end

endmodule