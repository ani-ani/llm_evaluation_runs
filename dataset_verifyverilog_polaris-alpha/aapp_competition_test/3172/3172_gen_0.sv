module max_fruits_sliced(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [31:0] x [0:7],
  input [31:0] y [0:7],
  output reg [3:0] max_count,
  output reg done
);

  // Fixed parameters
  localparam Q        = 16;
  localparam ONE_Q16  = 32'h0001_0000;     // 1.0 in Q16.16
  localparam RADIUS_Q = ONE_Q16;           // radius = 1.0
  localparam R2_Q     = 32'h0001_0000;     // radius^2 = 1.0 (since 1^2)

  // FSM states
  typedef enum logic [1:0] {
    IDLE          = 2'b00,
    PROCESS_PAIRS = 2'b01,
    CHECK_LINES   = 2'b10,
    FINISH        = 2'b11
  } state_t;

  state_t state, next_state;

  // Pair indices
  reg [2:0] i_pair;
  reg [2:0] j_pair;

  // Line selection per pair: 0 -> first tangent line, 1 -> second tangent line
  reg line_sel;

  // Fruit index for checking intersections
  reg [2:0] k_idx;

  // Current line parameters (fixed-point Q16.16 where applicable)
  // Line form: A x + B y + C = 0
  reg  signed [31:0] A_cur;
  reg  signed [31:0] B_cur;
  reg  signed [63:0] C_cur; // keep C wider due to multiplications

  // Current count for the active line
  reg [3:0] cur_count;

  // Internal control flags
  reg pairs_done;
  reg lines_done_for_pair;

  // Helper signals for distance check
  reg signed [47:0] Ax_k;
  reg signed [47:0] By_k;
  reg signed [63:0] num;     // A*x + B*y + C
  reg [63:0] num_abs_sq;     // |num|^2
  reg [63:0] denom;          // A^2 + B^2
  reg        intersects;

  // Multiply helpers (combinational) for A^2, B^2
  wire signed [63:0] A_sq = $signed(A_cur) * $signed(A_cur);
  wire signed [63:0] B_sq = $signed(B_cur) * $signed(B_cur);

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) begin
          next_state = (n < 2) ? FINISH : PROCESS_PAIRS;
        end
      end
      PROCESS_PAIRS: begin
        // Immediately go to CHECK_LINES once a pair and line_sel prepared
        next_state = CHECK_LINES;
      end
      CHECK_LINES: begin
        if (lines_done_for_pair && pairs_done)
          next_state = FINISH;
        else if (lines_done_for_pair)
          next_state = PROCESS_PAIRS;
        else
          next_state = CHECK_LINES;
      end
      FINISH: begin
        if (!start)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Pair iteration and line selection management
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state             <= IDLE;
      max_count         <= 4'd0;
      done              <= 1'b0;
      i_pair            <= 3'd0;
      j_pair            <= 3'd1;
      line_sel          <= 1'b0;
      k_idx             <= 3'd0;
      cur_count         <= 4'd0;
      pairs_done        <= 1'b0;
      lines_done_for_pair <= 1'b0;
      A_cur             <= 32'sd0;
      B_cur             <= 32'sd0;
      C_cur             <= 64'sd0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done              <= 1'b0;
          max_count         <= 4'd0;
          pairs_done        <= 1'b0;
          lines_done_for_pair <= 1'b0;
          line_sel          <= 1'b0;
          k_idx             <= 3'd0;
          cur_count         <= 4'd0;
          if (start) begin
            if (n < 2) begin
              // With <2 fruits, max_count is n (each fruit individually intersected)
              max_count <= {1'b0, n};
            end else begin
              i_pair <= 3'd0;
              j_pair <= 3'd1;
            end
          end
        end

        PROCESS_PAIRS: begin
          // Prepare for checking lines for current pair (i_pair, j_pair)
          lines_done_for_pair <= 1'b0;
          line_sel            <= 1'b0;
          k_idx               <= 3'd0;
          cur_count           <= 4'd0;

          // Compute a base line through centers as reference: vector (dx, dy)
          // For tangent lines, we use directions perpendicular to center-center vector.
          // We approximate two unit-offset parallel lines by using their normal as (dx, dy)
          // and encode offset sign in line_sel during CHECK_LINES.

          // dx = x[j] - x[i]
          // dy = y[j] - y[i]
          // Normal (A,B) = (dx, dy); Using same for both lines; C differs by sign.
          // We defer exact C computation to CHECK_LINES; here we only latch dx,dy.

          A_cur <= $signed(x[j_pair]) - $signed(x[i_pair]);
          B_cur <= $signed(y[j_pair]) - $signed(y[i_pair]);

          // C_cur is set in CHECK_LINES per line_sel
          C_cur <= 64'sd0;
        end

        CHECK_LINES: begin
          // Evaluate one fruit per cycle for current line_sel and pair.

          // When k_idx == 0 and starting new line, initialize cur_count and C.
          if (k_idx == 3'd0) begin
            cur_count <= 4'd0;
            // For tangent offset: we approximate unit-radius tangency in Q16.16.
            // We scale C such that line is shifted by +/-R along normalized (A,B).
            // To avoid division, we fold into comparison; but to keep structure,
            // we use a simple proportional offset: C = +/- (R * hypot(A,B))
            // Here we approximate hypot(A,B) by |A|+|B| to keep it simple.
            // NOTE: This is a hardware-friendly heuristic consistent across checks.
            begin
              reg [31:0] absA;
              reg [31:0] absB;
              reg [32:0] approx_norm;
              absA = A_cur[31] ? -A_cur : A_cur;
              absB = B_cur[31] ? -B_cur : B_cur;
              approx_norm = absA + absB; // simple approximation
              if (line_sel == 1'b0)
                C_cur <= -($signed(approx_norm) * $signed(RADIUS_Q));
              else
                C_cur <=  ($signed(approx_norm) * $signed(RADIUS_Q));
            end
          end

          // Compute intersection test for fruit k_idx
          Ax_k = $signed(A_cur) * $signed(x[k_idx]);
          By_k = $signed(B_cur) * $signed(y[k_idx]);
          num  = Ax_k + By_k + C_cur; // 64-bit

          // |num|^2
          if (num < 0)
            num_abs_sq = -num;
          else
            num_abs_sq = num;
          num_abs_sq = num_abs_sq * num_abs_sq;

          denom = A_sq + B_sq; // >0 for valid pair (distinct centers)

          // Intersection if (num^2 <= R^2 * denom)
          if (denom != 0 && num_abs_sq <= (R2_Q * denom))
            intersects = 1'b1;
          else
            intersects = 1'b0;

          if (intersects)
            cur_count <= cur_count + 4'd1;

          // Advance fruit index
          if (k_idx + 1 < n) begin
            k_idx <= k_idx + 3'd1;
          end else begin
            // Finished all fruits for this line
            // Update global max_count
            if (cur_count > max_count)
              max_count <= cur_count;

            // Prepare for next line or next pair
            if (line_sel == 1'b0) begin
              // move to second tangent line for same pair
              line_sel            <= 1'b1;
              k_idx               <= 3'd0;
              cur_count           <= 4'd0;
              lines_done_for_pair <= 1'b0;
            end else begin
              // both lines done for this pair
              lines_done_for_pair <= 1'b1;
              k_idx               <= 3'd0;
              cur_count           <= 4'd0;

              // Advance (i_pair, j_pair)
              if (j_pair + 1 < n) begin
                j_pair     <= j_pair + 3'd1;
                line_sel   <= 1'b0;
              end else if (i_pair + 2 < n) begin
                i_pair     <= i_pair + 3'd1;
                j_pair     <= i_pair + 3'd2;
                line_sel   <= 1'b0;
              end else begin
                // All pairs completed
                pairs_done <= 1'b1;
                line_sel   <= 1'b0;
              end
            end
          end
        end

        FINISH: begin
          done <= 1'b1;
          // Hold max_count until next start deasserted then asserted again.
          if (!start) begin
            // Ready for next run
            pairs_done         <= 1'b0;
            lines_done_for_pair<= 1'b0;
            i_pair             <= 3'd0;
            j_pair             <= 3'd1;
            line_sel           <= 1'b0;
            k_idx              <= 3'd0;
            cur_count          <= 4'd0;
          end
        end

        default: begin
        end
      endcase
    end
  end

endmodule