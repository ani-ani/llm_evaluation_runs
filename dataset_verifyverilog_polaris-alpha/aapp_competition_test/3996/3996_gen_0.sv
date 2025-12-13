module cup_probability(
  input clk,
  input rst_n,
  input start,
  input [3:0] k,
  input [15:0] a [0:7],
  output reg [31:0] p,
  output reg [31:0] q,
  output reg done
);

  // Constants
  localparam [31:0] MOD  = 32'd1000000007;
  localparam [31:0] INV2 = 32'd500000004;   // 2^{-1} mod MOD
  localparam [31:0] INV3 = 32'd333333336;   // 3^{-1} mod MOD

  // State encoding
  localparam [2:0]
    S_IDLE   = 3'd0,
    S_INIT   = 3'd1,
    S_EXP    = 3'd2,
    S_MODPOW = 3'd3,
    S_FINAL  = 3'd4,
    S_DONE   = 3'd5;

  reg [2:0] state, next_state;

  // Registers for exponent product and loop index
  reg [3:0] idx;
  reg [255:0] exp_prod;    // product of a_i (supports large products)
  reg parity_even_seen;    // 1 if any a_i is even

  // Modular exponentiation registers: compute 2^exp_prod mod MOD
  reg        mp_active;
  reg [255:0] mp_exp;
  reg [31:0] mp_base;
  reg [31:0] mp_result;

  // Latched copies
  reg [31:0] beta_reg;
  reg [31:0] alpha_reg;

  // Combinational next state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start) next_state = S_INIT;
      end
      S_INIT: begin
        if (!start) next_state = S_IDLE; // guard if start drops immediately
        else if (k != 0) next_state = S_EXP;
        else next_state = S_IDLE; // invalid k
      end
      S_EXP: begin
        // after k cycles of exponent accumulation -> MODPOW
        if (idx == k) next_state = S_MODPOW;
      end
      S_MODPOW: begin
        // wait until modular exponentiation finishes
        if (mp_active == 1'b0) next_state = S_FINAL;
      end
      S_FINAL: begin
        next_state = S_DONE;
      end
      S_DONE: begin
        if (!start) next_state = S_IDLE; // done holds high until next start pulse
      end
      default: next_state = S_IDLE;
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state            <= S_IDLE;
      p                <= 32'd0;
      q                <= 32'd0;
      done             <= 1'b0;
      idx              <= 4'd0;
      exp_prod         <= 256'd1;
      parity_even_seen <= 1'b0;
      mp_active        <= 1'b0;
      mp_exp           <= 256'd0;
      mp_base          <= 32'd0;
      mp_result        <= 32'd1;
      beta_reg         <= 32'd0;
      alpha_reg        <= 32'd0;
    end else begin
      state <= next_state;

      case (state)
        S_IDLE: begin
          // Outputs cleared when not computing
          done             <= 1'b0;
          p                <= 32'd0;
          q                <= 32'd0;
          idx              <= 4'd0;
          exp_prod         <= 256'd1;
          parity_even_seen <= 1'b0;
          mp_active        <= 1'b0;
          mp_exp           <= 256'd0;
          mp_base          <= 32'd0;
          mp_result        <= 32'd1;
          beta_reg         <= 32'd0;
          alpha_reg        <= 32'd0;
        end

        S_INIT: begin
          // Initialize accumulation on start
          if (start && k != 0) begin
            idx              <= 4'd0;
            exp_prod         <= 256'd1;
            parity_even_seen <= 1'b0;
            // clear mp
            mp_active        <= 1'b0;
            mp_exp           <= 256'd0;
            mp_base          <= 32'd0;
            mp_result        <= 32'd1;
            beta_reg         <= 32'd0;
            alpha_reg        <= 32'd0;
            done             <= 1'b0;
          end else begin
            // invalid or no start: hold/return to IDLE via next_state
            done <= 1'b0;
          end
        end

        S_EXP: begin
          // Process one exponent a[idx] per cycle
          if (idx < k) begin
            // Update product of exponents
            exp_prod <= exp_prod * a[idx];
            // Track if any exponent is even
            if (!a[idx][0]) begin
              parity_even_seen <= 1'b1;
            end
            idx <= idx + 1'b1;
          end
        end

        S_MODPOW: begin
          // Start modular exponentiation once when entering MODPOW
          if (!mp_active && mp_exp == 256'd0) begin
            mp_active <= 1'b1;
            mp_exp    <= exp_prod;
            mp_base   <= 32'd2;
            mp_result <= 32'd1;
          end else if (mp_active) begin
            // Binary exponentiation loop: one bit per cycle
            if (mp_exp != 256'd0) begin
              if (mp_exp[0]) begin
                // mp_result = (mp_result * mp_base) % MOD
                mp_result <= ( (mp_result * mp_base) % MOD );
              end
              mp_exp  <= mp_exp >> 1;
              mp_base <= ( (mp_base * mp_base) % MOD );
            end else begin
              // Done with exponentiation
              mp_active <= 1'b0;
            end
          end
        end

        S_FINAL: begin
          // Compute beta = (2^exp_prod / 2) mod MOD = 2^exp_prod * inv2 mod MOD
          // mp_result holds 2^exp_prod mod MOD from S_MODPOW
          beta_reg <= (mp_result * INV2) % MOD;

          // parity_flag: +1 if any even exponent else -1 (MOD-1)
          // alpha = (beta + parity_flag) * inv3 mod MOD
          if (parity_even_seen) begin
            // parity_flag = +1
            alpha_reg <= ((beta_reg + 32'd1) % MOD * INV3) % MOD;
          end else begin
            // parity_flag = -1 => (MOD - 1)
            alpha_reg <= ((beta_reg + (MOD - 32'd1)) % MOD * INV3) % MOD;
          end
        end

        S_DONE: begin
          // Drive outputs and hold done high until next start deasserts
          p    <= alpha_reg;
          q    <= beta_reg;
          done <= 1'b1;
        end

        default: begin
          // Safety default: go to IDLE-like state
          done             <= 1'b0;
          p                <= 32'd0;
          q                <= 32'd0;
          idx              <= 4'd0;
          exp_prod         <= 256'd1;
          parity_even_seen <= 1'b0;
          mp_active        <= 1'b0;
          mp_exp           <= 256'd0;
          mp_base          <= 32'd0;
          mp_result        <= 32'd1;
          beta_reg         <= 32'd0;
          alpha_reg        <= 32'd0;
        end
      endcase
    end
  end

endmodule