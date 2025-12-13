module polyline_xfinder(
  input clk,
  input rst_n,
  input start,
  input [23:0] a,
  input [23:0] b,
  output reg [63:0] x,
  output reg valid
);

  // FSM states
  localparam IDLE      = 3'd0;
  localparam PREP      = 3'd1;
  localparam DIV1      = 3'd2;
  localparam DIV2      = 3'd3;
  localparam FINAL     = 3'd4;

  reg [2:0] state, next_state;

  // Latched inputs
  reg [23:0] a_r, b_r;

  // Intermediate integer values
  reg [24:0] sum_ab;        // a + b fits in 25 bits
  reg [24:0] diff_ab;       // a - b (non-negative when used) fits in 25 bits

  // k1, k0 (integer divisors results)
  reg [31:0] k1;
  reg [31:0] k0;
  reg        k0_valid;

  // Numerators for divisions (Q32.32: (integer << 32))
  reg [63:0] num1;          // (a + b) in Q32.32
  reg [63:0] num0;          // (a - b) in Q32.32

  // Denominators
  reg [63:0] den1;          // 2 * k1 in integer (use lower bits)
  reg [63:0] den0;          // 2 * k0 in integer

  // Divider shared resources
  reg [63:0] dividend;
  reg [63:0] divisor;
  reg [63:0] quotient;
  reg [63:0] remainder;
  reg [5:0]  iter_cnt;      // 0..63, but we use 32 cycles
  reg        div_busy;

  // Results
  reg [63:0] x1_q;
  reg [63:0] x0_q;
  reg        x1_valid;
  reg        x0_valid;

  // Control which division we are performing
  reg        doing_div1;

  // Combinational next state
  always @* begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = PREP;
      end

      PREP: begin
        // Decide path based on b_r and precomputed values
        if (b_r > a_r) begin
          // No solution: move directly to FINAL
          next_state = FINAL;
        end else begin
          // Start first division for x1
          next_state = DIV1;
        end
      end

      DIV1: begin
        if (!div_busy) begin
          // If k0 is valid, go to second division, else finalize
          if (k0_valid)
            next_state = DIV2;
          else
            next_state = FINAL;
        end
      end

      DIV2: begin
        if (!div_busy) begin
          next_state = FINAL;
        end
      end

      FINAL: begin
        // One cycle output; then wait for next start
        if (!start)
          next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Sequential FSM and core logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= IDLE;
      a_r        <= 24'd0;
      b_r        <= 24'd0;
      sum_ab     <= 25'd0;
      diff_ab    <= 25'd0;
      k1         <= 32'd0;
      k0         <= 32'd0;
      k0_valid   <= 1'b0;
      num1       <= 64'd0;
      num0       <= 64'd0;
      den1       <= 64'd0;
      den0       <= 64'd0;
      dividend   <= 64'd0;
      divisor    <= 64'd0;
      quotient   <= 64'd0;
      remainder  <= 64'd0;
      iter_cnt   <= 6'd0;
      div_busy   <= 1'b0;
      doing_div1 <= 1'b0;
      x1_q       <= 64'd0;
      x0_q       <= 64'd0;
      x1_valid   <= 1'b0;
      x0_valid   <= 1'b0;
      x          <= 64'd0;
      valid      <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          valid      <= 1'b0;
          x          <= 64'd0;
          x1_valid   <= 1'b0;
          x0_valid   <= 1'b0;
          div_busy   <= 1'b0;
          iter_cnt   <= 6'd0;
          if (start) begin
            // Latch inputs
            a_r    <= a;
            b_r    <= b;
          end
        end

        PREP: begin
          // Compute basic quantities from latched a_r, b_r
          sum_ab  <= a_r + b_r;

          // Prepare (a - b) if a_r >= b_r (only used when valid)
          if (b_r <= a_r)
            diff_ab <= a_r - b_r;
          else
            diff_ab <= 25'd0;

          // Default
          x1_valid <= 1'b0;
          x0_valid <= 1'b0;

          if (b_r > a_r) begin
            // No solution case; result handled in FINAL
            k1       <= 32'd0;
            k0       <= 32'd0;
            k0_valid <= 1'b0;
            num1     <= 64'd0;
            num0     <= 64'd0;
            den1     <= 64'd0;
            den0     <= 64'd0;
            div_busy <= 1'b0;
            iter_cnt <= 6'd0;
          end else begin
            // Compute k1 = floor((a + b)/(2*b))
            // And k0 = floor((a - b)/(2*b)) if applicable
            // Use simple combinational division (since operands are small ints)
            // Guard b_r != 0; if b_r==0, 2*b_r==0 -> no valid k; treat as no solution
            if (b_r != 24'd0) begin
              // denominator_int = 2*b_r
              // k1
              k1 <= (sum_ab) / ( {b_r,1'b0} );
              // k0 only if diff_ab > 0
              if (diff_ab > 25'd0) begin
                k0 <= (diff_ab) / ( {b_r,1'b0} );
              end else begin
                k0 <= 32'd0;
              end
            end else begin
              k1 <= 32'd0;
              k0 <= 32'd0;
            end

            // Will refine k0_valid and numerators/denominators on next state edge
            div_busy <= 1'b0;
            iter_cnt <= 6'd0;
          end
        end

        DIV1: begin
          if (!div_busy) begin
            // Finalize k0_valid based on prepared values
            if (b_r != 24'd0 && b_r <= a_r) begin
              // k1 already computed; enforce k1 >= 1
              if (k1 == 32'd0)
                k1 <= 32'd1;

              // k0 usable only if > 0
              if (k0 > 32'd0)
                k0_valid <= 1'b1;
              else
                k0_valid <= 1'b0;
            end else begin
              k0_valid <= 1'b0;
            end

            // Prepare division for x1 = (a + b)/(2*k1)
            num1     <= {sum_ab, 32'd0}; // Q32.32
            den1     <= {32'd0, (k1 << 1)}; // 2*k1 as integer in low bits

            // Start divider for x1
            dividend   <= {sum_ab, 32'd0};
            divisor    <= {32'd0, (k1 << 1)};
            quotient   <= 64'd0;
            remainder  <= 64'd0;
            iter_cnt   <= 6'd0;
            div_busy   <= 1'b1;
            doing_div1 <= 1'b1;
          end else begin
            // Iterative unsigned restoring division (32 cycles for 64b/64b to 32 frac bits)
            if (iter_cnt < 6'd32) begin
              // Shift remainder and bring next dividend bit (from MSB side)
              remainder <= {remainder[62:0], dividend[63]};
              dividend  <= {dividend[62:0], 1'b0};

              if (remainder >= divisor) begin
                remainder <= remainder - divisor;
                quotient  <= {quotient[62:0], 1'b1};
              end else begin
                quotient  <= {quotient[62:0], 1'b0};
              end

              iter_cnt <= iter_cnt + 6'd1;
            end else begin
              // Done 32 steps
              div_busy <= 1'b0;
              x1_q     <= quotient;
              x1_valid <= 1'b1;
            end
          end
        end

        DIV2: begin
          if (!div_busy) begin
            // Prepare and start division for x0 = (a - b)/(2*k0)
            num0       <= {diff_ab, 32'd0};
            den0       <= {32'd0, (k0 << 1)};

            dividend   <= {diff_ab, 32'd0};
            divisor    <= {32'd0, (k0 << 1)};
            quotient   <= 64'd0;
            remainder  <= 64'd0;
            iter_cnt   <= 6'd0;
            div_busy   <= 1'b1;
            doing_div1 <= 1'b0;
          end else begin
            // Same 32-cycle division core
            if (iter_cnt < 6'd32) begin
              remainder <= {remainder[62:0], dividend[63]};
              dividend  <= {dividend[62:0], 1'b0};

              if (remainder >= divisor) begin
                remainder <= remainder - divisor;
                quotient  <= {quotient[62:0], 1'b1};
              end else begin
                quotient  <= {quotient[62:0], 1'b0};
              end

              iter_cnt <= iter_cnt + 6'd1;
            end else begin
              div_busy <= 1'b0;
              x0_q     <= quotient;
              x0_valid <= k0_valid; // only meaningful if k0_valid
            end
          end
        end

        FINAL: begin
          // Determine output based on computed values and conditions
          if (b_r > a_r || b_r == 24'd0 || k1 == 32'd0) begin
            // No solution cases: b>a, b==0 (division by zero), or invalid k1
            x     <= 64'd0;
            valid <= 1'b0;
          end else begin
            // Select minimal positive x among x1 (always valid here) and x0 (if valid)
            if (x0_valid) begin
              if (x0_q < x1_q)
                x <= x0_q;
              else
                x <= x1_q;
            end else begin
              x <= x1_q;
            end
            valid <= 1'b1;
          end

          // Clear internal flags for next transaction (outputs hold until next start)
          div_busy   <= 1'b0;
          iter_cnt   <= 6'd0;
          x1_valid   <= x1_valid;
          x0_valid   <= x0_valid;
        end

        default: begin
          // Should not occur; reset-like behavior
          valid      <= 1'b0;
          x          <= 64'd0;
          div_busy   <= 1'b0;
          iter_cnt   <= 6'd0;
        end
      endcase
    end
  end

endmodule