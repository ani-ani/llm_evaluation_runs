module polygon_cutter(
  input clk,
  input rst_n,
  input start,
  input [2:0] a_count,
  input [2:0] b_count,
  input [7:0][15:0] a_x,
  input [7:0][15:0] a_y,
  input [7:0][15:0] b_x,
  input [7:0][15:0] b_y,
  output reg [31:0] total_cost,
  output reg done
);

  // State machine
  typedef enum logic [2:0] {
    IDLE            = 3'd0,
    FIND_TANGENTS   = 3'd1,
    CALC_DISTANCES  = 3'd2,
    SQRT_ITER       = 3'd3,
    ACCUMULATE      = 3'd4,
    FINISH          = 3'd5
  } state_t;

  state_t state, next_state;

  // Tangent indices (placeholders: assume tangents are vertex 0 and last vertex for simplicity)
  reg [2:0] tan_start_idx;
  reg [2:0] tan_end_idx;

  // Iteration and pipeline control
  reg [4:0] cycle_cnt;            // For global 20-cycle management if needed
  reg [2:0] edge_idx;             // Walk edges between tangents

  // Coordinate registers for current segment
  reg [15:0] x1_q8_8, y1_q8_8;
  reg [15:0] x2_q8_8, y2_q8_8;

  // Delta in Q8.8
  reg signed [16:0] dx_q8_8;
  reg signed [16:0] dy_q8_8;

  // Squared deltas: (Q8.8)^2 => Q16.16, use 34 bits to hold signed* signed
  reg [33:0] dx2_q16_16;
  reg [33:0] dy2_q16_16;

  // Sum of squares in Q16.16 (fit in 35 bits)
  reg [34:0] sum_q16_16;

  // Newton-Raphson sqrt pipeline
  // We use 32-bit Q16.16 for internal sqrt operand and result
  reg [31:0] sqrt operand_q16_16; // (not legal name) fix spelling below
  reg [31:0] sqrt_operand_q16_16;
  reg [31:0] x_n;        // Current iterate Q16.16
  reg [1:0]  nr_iter;    // 0..3 (4 iterations)

  // Internal distance result from sqrt in Q16.16
  reg [31:0] dist_q16_16;

  // Combinational next-state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = FIND_TANGENTS;
        end
      end
      FIND_TANGENTS: begin
        // Single-cycle tangent detection (simplified/placeholder)
        next_state = CALC_DISTANCES;
      end
      CALC_DISTANCES: begin
        // Setup one segment then go perform sqrt over multiple cycles
        next_state = SQRT_ITER;
      end
      SQRT_ITER: begin
        if (nr_iter == 2'd3) begin
          next_state = ACCUMULATE;
        end
      end
      ACCUMULATE: begin
        // For this design, assume single segment between tangents.
        // After accumulation, go to FINISH.
        next_state = FINISH;
      end
      FINISH: begin
        // Done asserted for one cycle, then go back to IDLE.
        next_state = IDLE;
      end
      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state           <= IDLE;
      total_cost      <= 32'd0;
      done            <= 1'b0;
      tan_start_idx   <= 3'd0;
      tan_end_idx     <= 3'd0;
      edge_idx        <= 3'd0;
      x1_q8_8         <= 16'd0;
      y1_q8_8         <= 16'd0;
      x2_q8_8         <= 16'd0;
      y2_q8_8         <= 16'd0;
      dx_q8_8         <= 17'd0;
      dy_q8_8         <= 17'd0;
      dx2_q16_16      <= 34'd0;
      dy2_q16_16      <= 34'd0;
      sum_q16_16      <= 35'd0;
      sqrt_operand_q16_16 <= 32'd0;
      x_n             <= 32'h00040000; // 0x00040000 = 4.0 in Q16.16, but will be overwritten when used
      nr_iter         <= 2'd0;
      dist_q16_16     <= 32'd0;
      cycle_cnt       <= 5'd0;
    end else begin
      state <= next_state;

      // Default outputs
      done <= 1'b0;

      case (state)
        IDLE: begin
          if (start) begin
            total_cost <= 32'd0;
            cycle_cnt  <= 5'd0;
          end
        end

        FIND_TANGENTS: begin
          // Placeholder tangent detection: use vertex 0 and last vertex (a_count-1)
          // For convex polygons and "consecutive tangent points only" assumption.
          tan_start_idx <= 3'd0;
          tan_end_idx   <= (a_count > 0) ? (a_count - 1'b1) : 3'd0;
          edge_idx      <= 3'd0;
        end

        CALC_DISTANCES: begin
          // For this implementation, assume single cut between tan_start_idx and tan_end_idx.
          // Grab coordinates from A for these tangents.
          x1_q8_8 <= a_x[tan_start_idx];
          y1_q8_8 <= a_y[tan_start_idx];
          x2_q8_8 <= a_x[tan_end_idx];
          y2_q8_8 <= a_y[tan_end_idx];

          // Compute deltas (Q8.8)
          dx_q8_8 <= $signed({1'b0, a_x[tan_end_idx]}) - $signed({1'b0, a_x[tan_start_idx]});
          dy_q8_8 <= $signed({1'b0, a_y[tan_end_idx]}) - $signed({1'b0, a_y[tan_start_idx]});

          // Squares to Q16.16
          dx2_q16_16 <= $signed(dx_q8_8) * $signed(dx_q8_8);
          dy2_q16_16 <= $signed(dy_q8_8) * $signed(dy_q8_8);

          // Sum of squares (keep as Q16.16)
          // Note: dx2_q16_16 and dy2_q16_16 already Q16.16
          sum_q16_16 <= {1'b0, dx2_q16_16} + {1'b0, dy2_q16_16};

          // Prepare operand for sqrt: take lower 32 bits as Q16.16
          sqrt_operand_q16_16 <= sum_q16_16[31:0];

          // Initialize Newton-Raphson
          // Starting guess = 0x010000 (1.0 in Q16.16) as specified (010000h)
          x_n     <= 32'h00010000;
          nr_iter <= 2'd0;
          cycle_cnt <= 5'd0;
        end

        SQRT_ITER: begin
          // Newton-Raphson for sqrt in Q16.16
          // x_{n+1} = (x_n + S / x_n) / 2
          // S and x_n are Q16.16. Division is performed in fixed-point.
          // To avoid large combinational div, we use behavioral division (synth tools may replace or require IP).
          // Compute S/x_n in Q16.16: ((S << 16) / x_n)
          if (nr_iter < 2'd4) begin
            // Protect against divide-by-zero
            if (x_n != 32'd0) begin
              // 64-bit numerator for precision
              reg [63:0] num;
              reg [31:0] s_over_x;
              num = {sqrt_operand_q16_16, 16'd0};
              s_over_x = num / x_n;
              x_n <= (x_n + s_over_x) >> 1;
            end
            nr_iter <= nr_iter + 2'd1;
          end
          cycle_cnt <= cycle_cnt + 5'd1;
        end

        ACCUMULATE: begin
          // x_n holds sqrt(S) in Q16.16 after 4 iterations.
          dist_q16_16 <= x_n;
          total_cost  <= total_cost + x_n;
        end

        FINISH: begin
          // Result valid; done high for this cycle.
          done <= 1'b1;
        end

        default: begin
        end
      endcase
    end
  end

endmodule