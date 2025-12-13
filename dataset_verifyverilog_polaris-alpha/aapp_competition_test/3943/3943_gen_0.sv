module max_card_score (
  input  clk,
  input  rst_n,
  input  start,
  input  [7:0] a,
  input  [7:0] b,
  output reg signed [16:0] max_score,
  output reg done
);

  // Internal registers
  reg [7:0] a_reg, b_reg;
  reg [8:0] i;                   // iteration index (up to 257)
  reg [8:0] i_bound;             // min(a+2, b+1)

  reg signed [16:0] current_max;
  reg signed [16:0] diff;

  // For v1 computation
  reg [8:0] a2;                  // a + 2
  reg [8:0] t1;                  // a2 - i
  reg [17:0] t1_sq;              // (a2 - i)^2 (fits in 18 bits)
  reg [8:0] i_minus2;            // i-2
  reg signed [18:0] v1;          // v1 up to 18 bits

  // For division (b / i)
  reg [15:0] rem_val;            // remainder during division
  reg [7:0]  quo;                // quotient result
  reg [7:0]  rem;                // remainder result
  reg [8:0]  div_counter;        // loop counter for division (0..255)
  reg        div_active;

  // For v2 computation
  reg [9:0]  quo_p1;             // quo + 1
  reg [19:0] qo_sq;              // quo^2
  reg [19:0] q1_sq;              // (quo+1)^2
  reg [19:0] mul1;               // rem * (quo+1)^2
  reg [19:0] i_minus_rem;        // i - rem
  reg [19:0] mul2;               // (i-rem) * quo^2
  reg signed [20:0] v2;          // v2

  // FSM states
  typedef enum logic [2:0] {
    IDLE        = 3'd0,
    SPECIAL     = 3'd1,
    INIT        = 3'd2,
    SETUP_ITER  = 3'd3,
    DIVIDE      = 3'd4,
    COMPUTE_V2  = 3'd5,
    UPDATE_MAX  = 3'd6,
    FINISH      = 3'd7
  } state_t;

  state_t state, next_state;

  // Sequential state and registers update
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      max_score   <= 17'sd0;
      done        <= 1'b0;
      a_reg       <= 8'd0;
      b_reg       <= 8'd0;
      i           <= 9'd0;
      i_bound     <= 9'd0;
      current_max <= 17'sd0;
      div_active  <= 1'b0;
      div_counter <= 9'd0;
      rem_val     <= 16'd0;
      quo         <= 8'd0;
      rem         <= 8'd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done <= 1'b0;
          if (start) begin
            a_reg <= a;
            b_reg <= b;
          end
        end

        SPECIAL: begin
          // max_score and done are driven in combinational next_state block
        end

        INIT: begin
          // latch derived bounds and initialize
          a2         <= {1'b0, a_reg} + 9'd2;      // a+2
          i_bound    <= (({1'b0, a_reg} + 9'd2) < ({1'b0, b_reg} + 9'd1)) ?
                        ({1'b0, a_reg} + 9'd2) : ({1'b0, b_reg} + 9'd1);
          i          <= 9'd2;
          current_max<= -17'sd131072; // sufficiently small: -2^17
        end

        SETUP_ITER: begin
          // Compute v1 terms
          t1       <= a2 - i;                  // a+2 - i
          t1_sq    <= (a2 - i) * (a2 - i);
          i_minus2 <= i - 9'd2;
          v1       <= $signed({1'b0,t1_sq}) + $signed({10'd0,i_minus2});

          // Start division b_reg / i via iterative subtraction
          quo         <= 8'd0;
          rem_val     <= {8'd0, b_reg};        // 16-bit working remainder
          div_counter <= 9'd0;
          div_active  <= 1'b1;
        end

        DIVIDE: begin
          if (div_active) begin
            if (rem_val >= i && div_counter < 9'd256) begin
              rem_val     <= rem_val - i;
              quo         <= quo + 8'd1;
              div_counter <= div_counter + 9'd1;
            end else begin
              // division complete
              rem        <= rem_val[7:0];
              div_active <= 1'b0;
            end
          end
        end

        COMPUTE_V2: begin
          // Using computed quo, rem
          quo_p1     <= {2'd0,quo} + 10'd1;       // quo+1
          qo_sq      <= quo * quo;               // quo^2
          q1_sq      <= quo_p1 * quo_p1;         // (quo+1)^2
          mul1       <= rem * q1_sq;             // rem*(quo+1)^2
          i_minus_rem<= i - rem;                 // i-rem
          mul2       <= i_minus_rem * qo_sq;     // (i-rem)*quo^2
          v2         <= $signed({1'b0,mul1}) + $signed({1'b0,mul2});
        end

        UPDATE_MAX: begin
          diff <= $signed(v1) - $signed(v2[16:0]);
          if ($signed(v1) - $signed(v2[16:0]) > current_max)
            current_max <= $signed(v1) - $signed(v2[16:0]);

          i <= i + 9'd1;
        end

        FINISH: begin
          max_score <= current_max;
          done      <= 1'b1;
        end

        default: ;
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;

    case (state)
      IDLE: begin
        if (start)
          next_state = SPECIAL;
      end

      SPECIAL: begin
        // Handle special cases combinationally
        if (a_reg == 8'd0 && b_reg == 8'd0) begin
          // Both zero -> score 0
          next_state = FINISH;
        end else if (a_reg == 8'd0) begin
          next_state = FINISH;
        end else if (b_reg == 8'd0) begin
          next_state = FINISH;
        end else begin
          next_state = INIT;
        end
      end

      INIT: begin
        // Move to first iteration setup
        if (i_bound <= 9'd2) begin
          // No valid iterations
          next_state = FINISH;
        end else begin
          next_state = SETUP_ITER;
        end
      end

      SETUP_ITER: begin
        next_state = DIVIDE;
      end

      DIVIDE: begin
        if (!div_active)
          next_state = COMPUTE_V2;
      end

      COMPUTE_V2: begin
        next_state = UPDATE_MAX;
      end

      UPDATE_MAX: begin
        if (i < i_bound)
          next_state = SETUP_ITER;
        else
          next_state = FINISH;
      end

      FINISH: begin
        if (!start)
          next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Special case handling and final outputs (combinational overlay)
  always @(*) begin
    // Default: keep sequential values
    if (state == SPECIAL) begin
      if (a_reg == 8'd0 && b_reg != 8'd0) begin
        // max_score = -b*b
        // 8-bit b -> 16-bit b*b -> fit into 17 bits signed negative
        // Done in FINISH state via next_state; here only combinational hint
      end else if (b_reg == 8'd0 && a_reg != 8'd0) begin
        // max_score = a*a
      end else if (a_reg == 8'd0 && b_reg == 8'd0) begin
        // max_score = 0
      end
    end
  end

  // Override max_score in FINISH state for special cases
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // handled above
    end else begin
      if (state == SPECIAL && next_state == FINISH) begin
        if (a_reg == 8'd0 && b_reg != 8'd0) begin
          max_score <= -$signed({1'b0,(b_reg * b_reg)});
          done      <= 1'b1;
        end else if (b_reg == 8'd0 && a_reg != 8'd0) begin
          max_score <= $signed({1'b0,(a_reg * a_reg)});
          done      <= 1'b1;
        end else if (a_reg == 8'd0 && b_reg == 8'd0) begin
          max_score <= 17'sd0;
          done      <= 1'b1;
        end
      end
    end
  end

endmodule
