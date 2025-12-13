module penguin_plaque_counter(
  input clk,
  input rst_n,
  input start,
  input [4:0] n,       // Max value 16
  input [3:0] k,       // Max value 8
  output reg [31:0] result,
  output reg done
);

  // Parameters
  localparam M = 32'd1000000007;

  // FSM States
  typedef enum logic [2:0] {
    IDLE      = 3'd0,
    CALC_A    = 3'd1,
    CALC_B    = 3'd2,
    MULTIPLY  = 3'd3,
    DONE      = 3'd4
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [31:0] base_reg;          // base for exponentiation and multiplier operand
  reg [7:0]  exp_reg;           // exponent (supports up to 16)
  reg [31:0] pow_reg;           // running power value (mod M)
  reg [31:0] A_reg, B_reg;      // store A and B

  // Sequential multiplier internal signals
  reg [63:0] mul_acc;
  reg [31:0] mul_multiplicand;
  reg [31:0] mul_multiplier;
  reg [5:0]  mul_count;         // up to 32 cycles (we'll use far less)
  reg        mul_active;
  reg [31:0] mul_result_mod;

  // Exponentiation control
  reg [7:0]  exp_target;        // target exponent for current power computation
  reg        pow_done;
  reg        pow_start;
  reg        select_A;          // 1 when computing A, 0 when computing B

  // Simple edge: track if we are in multiplication of final A*B
  reg        final_mul;         // 1 when MULTIPLY state computing result

  // FSM: state register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
    end else begin
      state <= next_state;
    end
  end

  // FSM: next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          if (k == 0) begin
            next_state = DONE;  // invalid: result=0 handled in seq block
          end else begin
            next_state = CALC_A;
          end
        end
      end

      CALC_A: begin
        if (pow_done) begin
          next_state = CALC_B;
        end
      end

      CALC_B: begin
        if (pow_done) begin
          next_state = MULTIPLY;
        end
      end

      MULTIPLY: begin
        if (!mul_active) begin
          next_state = DONE;
        end
      end

      DONE: begin
        // stay DONE until start deasserted then possibly new start
        if (!start) begin
          next_state = IDLE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

  // Sequential multiplier (shift-add) with mod M at end
  // Operates when mul_active=1; one bit processed per cycle
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mul_acc          <= 64'd0;
      mul_multiplicand <= 32'd0;
      mul_multiplier   <= 32'd0;
      mul_count        <= 6'd0;
      mul_active       <= 1'b0;
      mul_result_mod   <= 32'd0;
    end else begin
      if (mul_active) begin
        // Shift-add for current bit
        if (mul_multiplier[0]) begin
          mul_acc <= mul_acc + {32'd0, mul_multiplicand};
        end
        mul_multiplicand <= mul_multiplicand << 1;
        mul_multiplier   <= mul_multiplier >> 1;
        mul_count        <= mul_count + 1'b1;

        // When done with 32 bits, compute mod M and clear active
        if (mul_count == 6'd31) begin
          // Final step uses updated mul_acc from this cycle's operation
          // Note: combinationally, next cycle we output result
          mul_active <= 1'b0;
        end
      end else begin
        // When just finished or idle: latch modular result
        // Only update when previously active and count reached end
        if (mul_count == 6'd31) begin
          // Perform modulo reduction from mul_acc
          // Use simple conditional subtraction loop unrolled (since M < 2^32)
          // First reduce to 32 bits (mod 2^32) then mod M
          // mul_acc up to (M-1)^2 < 2^62, so truncating lower 32 bits alone isn't enough,
          // so we reduce using repeated subtraction from 64-bit.
          // Simple iterative reduction by subtracting M while >=M.
          // This is coded combinationally here using a for loop style.
          // Synthesis will handle since bounds are small.
          integer i;
          reg [63:0] tmp;
          tmp = mul_acc;
          // Bring down modulo M using subtractive method (bounded small loops)
          // Upper bound: (M-1)^2 / M < M, so at most about 1e9 subtractions worst-case.
          // Not acceptable in HW if literal, so instead use modulo via division operator.
          // For ASIC-synthesizable simple solution and small operands, use % operator.
          mul_result_mod <= (mul_acc % M);
          mul_count      <= 6'd0;
          mul_acc        <= 64'd0;
          mul_multiplicand <= 32'd0;
          mul_multiplier <= 32'd0;
        end
      end
    end
  end

  // Power (repeated multiplication) controller
  // Uses the sequential multiplier to compute base^exp_target mod M
  // Protocol:
  //  - pow_start asserted to (re)start with pow_reg=1, base_reg set, exp_reg set.
  //  - For each exponent step: start mul with (pow_reg * base_reg).
  //  - When mul_active finishes, update pow_reg=mul_result_mod, decrement exp_reg.
  //  - When exp_reg==0, set pow_done.
  //  - Handles exp_target==0: pow_reg=1, pow_done immediately.

  typedef enum logic [1:0] {
    P_IDLE  = 2'd0,
    P_MUL   = 2'd1,
    P_WAIT  = 2'd2
  } pstate_t;

  pstate_t pstate, pnext;

  // Power state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pstate   <= P_IDLE;
      pow_reg  <= 32'd1;
      exp_reg  <= 8'd0;
      pow_done <= 1'b0;
    end else begin
      pstate <= pnext;
      case (pstate)
        P_IDLE: begin
          pow_done <= 1'b0;
          if (pow_start) begin
            pow_reg <= 32'd1;
            exp_reg <= exp_target;
            if (exp_target == 0) begin
              pow_done <= 1'b1; // 0 exponent => 1
            end
          end
        end

        P_MUL: begin
          // Wait for mul_active to be low (done), then capture result
          if (!mul_active) begin
            pow_reg <= mul_result_mod;
            if (exp_reg > 0) begin
              exp_reg <= exp_reg - 1'b1;
            end
          end
        end

        P_WAIT: begin
          // Decide next: if more exponent steps, start another mul
          if (exp_reg == 0) begin
            pow_done <= 1'b1;
          end
        end
      endcase
    end
  end

  // Power next-state and multiplier control
  always @(*) begin
    pnext      = pstate;
    pow_start  = 1'b0;

    case (pstate)
      P_IDLE: begin
        if (pow_start) begin
          // handled in seq; next state decided here based on exp_target
          if (exp_target == 0) begin
            pnext = P_IDLE; // immediate done; pow_done set
          end else begin
            // Initiate first multiply: pow_reg (1) * base_reg
            if (!mul_active) begin
              pnext = P_MUL;
            end
          end
        end
      end

      P_MUL: begin
        // If multiplier idle, we must have just finished an operation
        if (!mul_active) begin
          if (exp_reg > 1) begin
            // Need another multiply: start new mul in P_WAIT
            pnext = P_WAIT;
          end else begin
            // That was last multiply
            pnext = P_WAIT;
          end
        end
      end

      P_WAIT: begin
        // After pow_reg updated, decide next
        if (exp_reg == 0) begin
          // done
          pnext = P_IDLE;
        end else begin
          // start next multiply
          if (!mul_active) begin
            pnext = P_MUL;
          end
        end
      end

      default: pnext = P_IDLE;
    endcase
  end

  // Control for starting multiplier based on pstate transitions
  // and current pow_reg, base_reg.
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mul_active       <= 1'b0;
      mul_acc          <= 64'd0;
      mul_multiplicand <= 32'd0;
      mul_multiplier   <= 32'd0;
      mul_count        <= 6'd0;
    end else begin
      // Start new multiplication for exponentiation when in P_MUL and mul inactive
      if ((pstate == P_IDLE || pstate == P_WAIT) && pnext == P_MUL && !mul_active && exp_target != 0) begin
        // Start pow_reg * base_reg
        mul_active       <= 1'b1;
        mul_acc          <= 64'd0;
        mul_multiplicand <= pow_reg % M;
        mul_multiplier   <= base_reg % M;
        mul_count        <= 6'd0;
      end
      // Start next multiply while staying in P_MUL (subsequent steps)
      else if (pstate == P_MUL && !mul_active && exp_reg > 1) begin
        mul_active       <= 1'b1;
        mul_acc          <= 64'd0;
        mul_multiplicand <= mul_result_mod;
        mul_multiplier   <= base_reg % M;
        mul_count        <= 6'd0;
      end
      // Final A*B multiply in MULTIPLY state
      else if (state == MULTIPLY && next_state == MULTIPLY && !mul_active && final_mul) begin
        mul_active       <= 1'b1;
        mul_acc          <= 64'd0;
        mul_multiplicand <= A_reg % M;
        mul_multiplier   <= B_reg % M;
        mul_count        <= 6'd0;
      end
    end
  end

  // Main control: manage A/B computations and final multiply
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      A_reg     <= 32'd0;
      B_reg     <= 32'd0;
      base_reg  <= 32'd0;
      exp_target<= 8'd0;
      select_A  <= 1'b0;
      final_mul <= 1'b0;
      result    <= 32'd0;
      done      <= 1'b0;
    end else begin
      done <= 1'b0;

      case (state)
        IDLE: begin
          final_mul <= 1'b0;
          if (start) begin
            if (k == 0) begin
              // invalid case: result = 0
              result <= 32'd0;
            end else begin
              // Setup for A = k^(k-1) mod M
              select_A   <= 1'b1;
              base_reg   <= (k % M);
              exp_target <= (k > 0) ? (k - 1) : 0;
              // pow_start will be asserted via power FSM when entering
            end
          end
        end

        CALC_A: begin
          // Trigger power computation start once upon entering CALC_A
          if (state != next_state && next_state == CALC_A) begin
            // no-op
          end
          // When power FSM indicates done, store A_reg
          if (pow_done) begin
            A_reg <= pow_reg % M;
          end
        end

        CALC_B: begin
          // Setup for B only once when we just entered CALC_B
          if (state != CALC_B) begin
            // no-op
          end
          // Determine exponent/base for B
          // B = (n-k)^(n-k), with 0^0 = 1 when n==k
          if (pow_done) begin
            // store after done
            B_reg <= pow_reg % M;
          end else begin
            if (!pow_done && pow_start) begin
              // no-op
            end
          end
        end

        MULTIPLY: begin
          // Kick off final multiplication A_reg * B_reg -> result
          final_mul <= 1'b1;
          if (!mul_active && mul_count == 6'd31) begin
            // when multiplier block latches result
            result    <= mul_result_mod;
          end
        end

        DONE: begin
          done      <= 1'b1;
          final_mul <= 1'b0;
        end
      endcase

      // Setup pow_start and parameters when entering CALC_A/CALC_B
      if (state == IDLE && next_state == CALC_A && k != 0) begin
        // Configure A exponentiation
        select_A   <= 1'b1;
        base_reg   <= (k % M);
        exp_target <= (k > 0) ? (k - 1) : 0;
        pow_start  <= 1'b1;
      end else if (state == CALC_A && next_state == CALC_B) begin
        // Configure B exponentiation
        select_A <= 1'b0;
        if (n == k) begin
          // 0^0 = 1
          base_reg   <= 32'd1;
          exp_target <= 8'd0;
        end else begin
          base_reg   <= ((n - k) % M);
          exp_target <= (n - k);
        end
        pow_start <= 1'b1;
      end else begin
        // default
        pow_start <= 1'b0;
      end

      // When leaving CALC_B to MULTIPLY, ensure B_reg captured for n==k immediate case
      if (state == CALC_B && next_state == MULTIPLY && (n == k)) begin
        B_reg <= 32'd1;
      end
    end
  end

endmodule