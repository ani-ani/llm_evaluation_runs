module function_counter(
  input clk,
  input rst_n,
  input start,
  input [4:0] p,
  input [4:0] k,
  output reg [29:0] result,
  output reg done
);

  // Constant MOD = 1e9 + 7
  localparam [29:0] MOD = 30'd1000000007;

  // FSM States
  localparam [3:0]
    S_IDLE       = 4'd0,
    S_INIT_CASE0 = 4'd1,
    S_EXP_CASE0  = 4'd2,
    S_INIT_CASE1 = 4'd3,
    S_EXP_CASE1  = 4'd4,
    S_INIT_ORD   = 4'd5,
    S_ORD_MUL    = 4'd6,
    S_ORD_CHECK  = 4'd7,
    S_INIT_EXP_C = 4'd8,
    S_EXP_C      = 4'd9,
    S_DONE       = 4'd10;

  reg [3:0] state, next_state;

  // Registers for computation
  reg [5:0] exp_counter;      // up to 31
  reg [5:0] target_exp;       // exponent target
  reg [59:0] mul_temp;        // for modular multiplication (intermediate)
  reg [29:0] base_reg;        // current base for exponentiation
  reg [29:0] acc_reg;         // accumulator for exponentiation

  // For multiplicative order finding
  reg [29:0] ord_val;         // current value of k^t mod p
  reg [5:0] ord_t;            // current t
  reg [5:0] ord_t_limit;      // max t = p-1
  reg [29:0] k_mod;           // k reduced modulo p
  reg [29:0] p_reg;           // latched p
  reg [29:0] t_val;           // found order t
  reg        ord_found;

  // For exponent with c = (p-1)/t
  reg [5:0] c_val;            // (p-1)/t, <= 31

  // Sequential state and registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= S_IDLE;
      result      <= 30'd0;
      done        <= 1'b0;
      exp_counter <= 6'd0;
      target_exp  <= 6'd0;
      base_reg    <= 30'd0;
      acc_reg     <= 30'd0;
      mul_temp    <= 60'd0;
      ord_val     <= 30'd0;
      ord_t       <= 6'd0;
      ord_t_limit <= 6'd0;
      k_mod       <= 30'd0;
      p_reg       <= 30'd0;
      t_val       <= 30'd0;
      ord_found   <= 1'b0;
      c_val       <= 6'd0;
    end else begin
      state <= next_state;

      case (state)
        // IDLE: wait for start, latch inputs
        S_IDLE: begin
          done   <= 1'b0;
          result <= 30'd0;
          if (start) begin
            p_reg <= {25'd0, p};
            k_mod <= (k >= p) ? (k - p) : {25'd0, k};
          end
        end

        // CASE k == 0: compute p^(p-1)
        S_INIT_CASE0: begin
          // acc = 1, base = p, target_exp = p-1
          acc_reg     <= 30'd1;
          base_reg    <= p_reg % MOD;
          target_exp  <= {1'b0, p} - 6'd1; // p-1, p<=31
          exp_counter <= 6'd0;
        end

        S_EXP_CASE0: begin
          // acc = acc * base mod MOD, repeat target_exp times
          mul_temp    <= acc_reg * base_reg;
          acc_reg     <= (mul_temp % MOD);
          exp_counter <= exp_counter + 6'd1;
        end

        // CASE k == 1: compute p^p
        S_INIT_CASE1: begin
          acc_reg     <= 30'd1;
          base_reg    <= p_reg % MOD;
          target_exp  <= {1'b0, p}; // p
          exp_counter <= 6'd0;
        end

        S_EXP_CASE1: begin
          mul_temp    <= acc_reg * base_reg;
          acc_reg     <= (mul_temp % MOD);
          exp_counter <= exp_counter + 6'd1;
        end

        // Initialize multiplicative order computation for k > 1
        S_INIT_ORD: begin
          ord_val     <= k_mod % p_reg; // k^1 mod p
          ord_t       <= 6'd1;
          ord_t_limit <= {1'b0, p} - 6'd1; // p-1
          ord_found   <= 1'b0;
        end

        // Multiply ord_val by k_mod modulo p to step t
        S_ORD_MUL: begin
          mul_temp <= ord_val * k_mod;
          ord_val  <= (mul_temp % p_reg);
          ord_t    <= ord_t + 6'd1;
        end

        // Check if ord_val == 1 --> found order t
        S_ORD_CHECK: begin
          if (ord_val == 30'd1) begin
            t_val     <= ord_t;
            ord_found <= 1'b1;
          end
        end

        // Initialize exponentiation with exponent c = (p-1)/t
        S_INIT_EXP_C: begin
          // c = (p-1)/t_val, with small integers (p<=31)
          // simple iterative division
          integer i;
          reg [5:0] numer;
          reg [5:0] denom;
          reg [5:0] tmp_c;
          numer = {1'b0,p} - 6'd1;
          denom = t_val[5:0];
          tmp_c = 6'd0;
          for (i = 0; i < 6; i = i + 1) begin
            if (numer >= denom) begin
              numer = numer - denom;
              tmp_c = tmp_c + 6'd1;
            end
          end
          c_val      <= tmp_c;
          acc_reg    <= 30'd1;
          base_reg   <= p_reg % MOD;
          target_exp <= tmp_c;
          exp_counter<= 6'd0;
        end

        // Exponentiate p^c
        S_EXP_C: begin
          mul_temp    <= acc_reg * base_reg;
          acc_reg     <= (mul_temp % MOD);
          exp_counter <= exp_counter + 6'd1;
        end

        // DONE: hold result and done until next start or reset
        S_DONE: begin
          done   <= 1'b1;
          result <= acc_reg % MOD;
        end

        default: ;
      endcase
    end
  end

  // Next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start) begin
          if (k == 5'd0)
            next_state = S_INIT_CASE0;
          else if (k == 5'd1)
            next_state = S_INIT_CASE1;
          else
            next_state = S_INIT_ORD;
        end
      end

      // CASE0: p^(p-1)
      S_INIT_CASE0: begin
        if (target_exp == 6'd0)
          next_state = S_DONE; // p-1=0 only if p=1, not in spec, but safe
        else
          next_state = S_EXP_CASE0;
      end
      S_EXP_CASE0: begin
        if (exp_counter + 6'd1 >= target_exp)
          next_state = S_DONE;
        else
          next_state = S_EXP_CASE0;
      end

      // CASE1: p^p
      S_INIT_CASE1: begin
        if (target_exp == 6'd0)
          next_state = S_DONE;
        else
          next_state = S_EXP_CASE1;
      end
      S_EXP_CASE1: begin
        if (exp_counter + 6'd1 >= target_exp)
          next_state = S_DONE;
        else
          next_state = S_EXP_CASE1;
      end

      // Order finding
      S_INIT_ORD: begin
        // If immediately 1, order is 1; else proceed
        if (ord_val == 30'd1) begin
          next_state = S_INIT_EXP_C;
        end else begin
          next_state = S_ORD_MUL;
        end
      end
      S_ORD_MUL: begin
        next_state = S_ORD_CHECK;
      end
      S_ORD_CHECK: begin
        if (ord_found) begin
          next_state = S_INIT_EXP_C;
        end else if (ord_t >= ord_t_limit) begin
          // Fallback: if not found (shouldn't happen for valid generator), use t = p-1
          next_state = S_INIT_EXP_C;
        end else begin
          next_state = S_ORD_MUL;
        end
      end

      // Exponentiation for c
      S_INIT_EXP_C: begin
        if (target_exp == 6'd0)
          next_state = S_DONE;
        else
          next_state = S_EXP_C;
      end
      S_EXP_C: begin
        if (exp_counter + 6'd1 >= target_exp)
          next_state = S_DONE;
        else
          next_state = S_EXP_C;
      end

      S_DONE: begin
        // Stay done until start deasserts and reasserts
        if (!start)
          next_state = S_IDLE;
        else
          next_state = S_DONE;
      end

      default: next_state = S_IDLE;
    endcase
  end

endmodule