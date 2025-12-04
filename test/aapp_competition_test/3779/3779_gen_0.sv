module tax_divine_digit(
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [15:0] k,
  input [15:0] denomination_0,
  input [15:0] denomination_1,
  input [15:0] denomination_2,
  input [15:0] denomination_3,
  input [15:0] denomination_4,
  input [15:0] denomination_5,
  input [15:0] denomination_6,
  input [15:0] denomination_7,
  output reg [15:0] g,
  output reg [15:0] total,
  output reg done
);

  // State encoding
  localparam IDLE        = 3'd0;
  localparam MOD_COMPUTE= 3'd1;
  localparam GCD_ITER    = 3'd2;
  localparam DIVIDE      = 3'd3;
  localparam DONE        = 3'd4;

  reg [2:0] state, next_state;

  // Index for denominations
  reg [3:0] idx;
  reg [3:0] next_idx;

  // Precomputed modulus values
  reg [15:0] mod_val [0:7];

  // GCD working registers
  reg [15:0] current_g;
  reg [15:0] next_current_g;
  reg [15:0] gcd_a, gcd_b;
  reg [15:0] next_gcd_a, next_gcd_b;

  // Divider registers (sequential subtractive division)
  reg [15:0] div_numer;
  reg [15:0] div_denom;
  reg [15:0] div_quot;
  reg [15:0] next_div_numer;
  reg [15:0] next_div_denom;
  reg [15:0] next_div_quot;

  // Internal done pulse control
  reg done_next;

  // Combinational helpers for denomination selection
  wire [15:0] denom_sel =
      (idx == 4'd0) ? denomination_0 :
      (idx == 4'd1) ? denomination_1 :
      (idx == 4'd2) ? denomination_2 :
      (idx == 4'd3) ? denomination_3 :
      (idx == 4'd4) ? denomination_4 :
      (idx == 4'd5) ? denomination_5 :
      (idx == 4'd6) ? denomination_6 :
      (idx == 4'd7) ? denomination_7 : 16'd0;

  // Sequential state and register update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      g          <= 16'd0; // per instruction: initialize g<=k is requested, but k may change; g is meaningful after computation
      total      <= 16'd0;
      done       <= 1'b0;
      idx        <= 4'd0;
      current_g  <= 16'd0;
      gcd_a      <= 16'd0;
      gcd_b      <= 16'd0;
      div_numer  <= 16'd0;
      div_denom  <= 16'd0;
      div_quot   <= 16'd0;
      mod_val[0] <= 16'd0;
      mod_val[1] <= 16'd0;
      mod_val[2] <= 16'd0;
      mod_val[3] <= 16'd0;
      mod_val[4] <= 16'd0;
      mod_val[5] <= 16'd0;
      mod_val[6] <= 16'd0;
      mod_val[7] <= 16'd0;
    end else begin
      state      <= next_state;
      idx        <= next_idx;
      current_g  <= next_current_g;
      gcd_a      <= next_gcd_a;
      gcd_b      <= next_gcd_b;
      div_numer  <= next_div_numer;
      div_denom  <= next_div_denom;
      div_quot   <= next_div_quot;
      done       <= done_next;

      // Update outputs g and total only when assigned in states
      if (next_state == IDLE && !start) begin
        // keep g and total as last computed results
      end
    end
  end

  // Combinational next-state and datapath logic
  always @(*) begin
    // Default assignments
    next_state      = state;
    next_idx        = idx;
    next_current_g  = current_g;
    next_gcd_a      = gcd_a;
    next_gcd_b      = gcd_b;
    next_div_numer  = div_numer;
    next_div_denom  = div_denom;
    next_div_quot   = div_quot;
    done_next       = 1'b0;

    case (state)
      IDLE: begin
        // As per requirement: on reset g<=k,total<=0,done<=0 handled in reset.
        // Here, wait for start pulse.
        if (start) begin
          // Initialize current_g with k; handle k==0 corner by treating as 0 for now
          next_current_g = k;

          // Precompute all mod_val in following state; initialize idx
          next_idx   = 4'd0;

          // Clear previous division-related
          next_div_numer = 16'd0;
          next_div_denom = 16'd0;
          next_div_quot  = 16'd0;

          next_state = MOD_COMPUTE;
        end
      end

      MOD_COMPUTE: begin
        // Compute denomination_i mod k for current idx
        // If idx >= n, skip to GCD processing
        if (idx < n) begin
          // Handle k==0: by problem constraints, k>=2, so division safe
          // Simple modulus via subtractive approach or conditional:
          // For efficiency, if denom < k, mod = denom, else subtract k once repeatedly.
          // Here we use conditional since 16-bit ranges are limited for single step; for exact
          // behavior, use % operator (synthesizable).
          case (idx)
            4'd0: mod_val[0] = denomination_0 % k;
            4'd1: mod_val[1] = denomination_1 % k;
            4'd2: mod_val[2] = denomination_2 % k;
            4'd3: mod_val[3] = denomination_3 % k;
            4'd4: mod_val[4] = denomination_4 % k;
            4'd5: mod_val[5] = denomination_5 % k;
            4'd6: mod_val[6] = denomination_6 % k;
            4'd7: mod_val[7] = denomination_7 % k;
            default: ;
          endcase

          next_idx = idx + 4'd1;
          next_state = MOD_COMPUTE;
        end else begin
          // All mods computed for i in [0, n-1]
          // Initialize GCD iteration:
          if (n == 4'd0) begin
            // No denominations: gcd defaults to k (or k if zero condition). Handle per spec.
            next_current_g = (k == 16'd0) ? 16'd0 : k;
            next_state = DIVIDE;

            // Setup division in DIVIDE state later
            next_div_numer = k;
            next_div_denom = (k == 16'd0) ? 16'd1 : next_current_g;
            next_div_quot  = 16'd0;
          end else begin
            // Start with current_g = k; setup first pair for GCD
            next_idx   = 4'd0;
            next_gcd_a = (k == 16'd0) ? 16'd0 : k;
            next_gcd_b = mod_val[0];
            next_state = GCD_ITER;
          end
        end
      end

      GCD_ITER: begin
        // Sequential Euclidean GCD between gcd_a and gcd_b, per denomination
        // Perform one step per cycle using modulo operation (synthesizable for small widths)

        // Handle base cases
        if (gcd_b == 16'd0) begin
          // gcd result is gcd_a for this denomination
          next_current_g = (gcd_a == 16'd0) ? k : gcd_a; // if gcd becomes 0, resolve to k

          // Move to next denomination or to DIVIDE if done
          if (idx + 4'd1 < n) begin
            // Next denomination index
            next_idx   = idx + 4'd1;
            next_gcd_a = ( (gcd_a == 16'd0) ? k : gcd_a );
            next_gcd_b = mod_val[idx + 4'd1];
            next_state = GCD_ITER;
          end else begin
            // All denominations processed, proceed to DIVIDE
            next_state = DIVIDE;

            // Initialize division: total = k / current_g
            // Ensure current_g not zero; if zero, treat as k (per requirement gcd=0->k)
            if ( ( (gcd_a == 16'd0) ? k : gcd_a ) == 16'd0 ) begin
              next_div_denom = 16'd1;
            end else begin
              next_div_denom = ( (gcd_a == 16'd0) ? k : gcd_a );
            end
            next_div_numer = k;
            next_div_quot  = 16'd0;
          end
        end else begin
          // Regular Euclid iteration step
          next_gcd_a = gcd_b;
          next_gcd_b = gcd_a % gcd_b;
          next_state = GCD_ITER;
        end
      end

      DIVIDE: begin
        // Sequential subtractive or iterative division: k / current_g
        // Using iterative subtraction: each cycle subtract denom from numer
        if (div_denom == 16'd0) begin
          // Prevent divide-by-zero; per spec should not occur, fallback to total=0
          next_div_quot  = 16'd0;
          next_div_numer = 16'd0;
          next_state     = DONE;
        end else if (div_numer >= div_denom) begin
          next_div_numer = div_numer - div_denom;
          next_div_quot  = div_quot + 16'd1;
          next_state     = DIVIDE;
        end else begin
          // Division complete
          // Latch final g and total here
          // current_g should already hold gcd; if 0 interpret as k
          // (Resolve here for safety.)
          // Note: Use blocking for outputs outside always@(*) - so assign via tasks:
          // handled in DONE state sequentially.
          next_state = DONE;
        end
      end

      DONE: begin
        // One cycle pulse done, outputs g and total valid.
        done_next = 1'b1;

        // Capture results in this combinational block via blocking assigns to outputs:
        // Use current_g as final gcd; if zero, resolve to k.
        // Then total = div_quot.

        // Return to IDLE next cycle
        next_state = IDLE;
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Output update for g and total based on states and internal regs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      g     <= k;
      total <= 16'd0;
    end else begin
      if (state == GCD_ITER && next_state == DIVIDE) begin
        // Just finished all GCD iterations
        g <= (next_current_g == 16'd0) ? k : next_current_g;
      end else if (state == DIVIDE && next_state == DONE) begin
        // Capture total when division finished
        total <= div_quot;
      end else if (state == MOD_COMPUTE && next_state == DIVIDE) begin
        // Case n==0, gcd default to k
        g <= (k == 16'd0) ? 16'd0 : k;
      end
    end
  end

endmodule