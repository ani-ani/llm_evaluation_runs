module laser_target_checker(
  input clk,
  input rst_n,
  input start,
  input [4:0] x_coords [0:5],
  input [4:0] y_coords [0:5],
  output reg done,
  output reg success
);

  // State encoding
  localparam IDLE              = 2'd0;
  localparam CHECK_SINGLE_LINE = 2'd1;
  localparam CHECK_DUAL_LINES  = 2'd2;
  localparam COMPLETE          = 2'd3;

  reg [1:0] state, next_state;

  // Latched coordinates for processing after start
  reg signed [4:0] x_latch [0:5];
  reg signed [4:0] y_latch [0:5];

  // Indices and control
  reg [2:0] idx;               // up to 6
  reg [1:0] combo_idx;         // 0..2 for up to 3 combinations
  reg       single_ok;
  reg       dual_ok;

  // For dual line checking
  reg [2:0] i1, i2;            // indices defining candidate line1

  // Products for colinearity (sized to avoid overflow)
  reg signed [5:0] dx1, dy1, dx2, dy2;
  reg signed [11:0] lhs, rhs;
  reg colinear;

  // Helper: compute colinearity of three points (p1, p2, p3)
  // Uses currently set (dx1,dy1,dx2,dy2) and outputs in 'colinear'.
  // Combinational block driven by source indices.
  always @* begin
    // default
    colinear = 1'b0;

    dx1 = 0;
    dy1 = 0;
    dx2 = 0;
    dy2 = 0;
    lhs = 0;
    rhs = 0;
  end

  // Dedicated combinational function-like block for arbitrary indices
  function automatic is_colinear_idx;
    input [2:0] a;
    input [2:0] b;
    input [2:0] c;
    reg signed [5:0] fdx1, fdy1, fdx2, fdy2;
    reg signed [11:0] flhs, frhs;
    begin
      fdx1 = x_latch[b] - x_latch[a];
      fdy1 = y_latch[b] - y_latch[a];
      fdx2 = x_latch[c] - x_latch[a];
      fdy2 = y_latch[c] - y_latch[a];
      flhs = fdy1 * fdx2;
      frhs = fdy2 * fdx1;
      is_colinear_idx = (flhs == frhs);
    end
  endfunction

  // Next-state logic
  always @* begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = CHECK_SINGLE_LINE;
      end

      CHECK_SINGLE_LINE: begin
        // After checking all needed pairs, move to next phase
        if (idx == 3'd5)
          next_state = dual_ok ? COMPLETE : CHECK_DUAL_LINES; // dual_ok reused later; single_ok evaluated separately
      end

      CHECK_DUAL_LINES: begin
        if (dual_ok || combo_idx == 2'd3)
          next_state = COMPLETE;
      end

      COMPLETE: begin
        if (!start)
          next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

  // Sequential logic
  integer j;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= IDLE;
      done    <= 1'b0;
      success <= 1'b0;
      idx     <= 3'd0;
      combo_idx <= 2'd0;
      single_ok <= 1'b0;
      dual_ok   <= 1'b0;
      for (j = 0; j < 6; j = j + 1) begin
        x_latch[j] <= 5'sd0;
        y_latch[j] <= 5'sd0;
      end
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done    <= 1'b0;
          success <= 1'b0;
          single_ok <= 1'b0;
          dual_ok   <= 1'b0;
          idx       <= 3'd0;
          combo_idx <= 2'd0;

          if (start) begin
            for (j = 0; j < 6; j = j + 1) begin
              x_latch[j] <= x_coords[j];
              y_latch[j] <= y_coords[j];
            end
          end
        end

        CHECK_SINGLE_LINE: begin
          // Reference line: points 0 and 1
          // Check points 2..5 one per cycle
          if (idx < 3'd2)
            idx <= 3'd2; // ensure starting from point 2
          else if (idx <= 3'd5) begin
            if (!is_colinear_idx(3'd0, 3'd1, idx)) begin
              single_ok <= 1'b0;
              // force finish of loop quickly
              idx <= 3'd5;
            end else begin
              // still colinear for this point
              if (idx == 3'd2)
                single_ok <= 1'b1; // initialize once we've started checks
              idx <= idx + 3'd1;
            end
          end

          // Prepare flag to indicate if single-line succeeded
          if (idx == 3'd5) begin
            if (single_ok || (is_colinear_idx(3'd0,3'd1,3'd2) && is_colinear_idx(3'd0,3'd1,3'd3) && is_colinear_idx(3'd0,3'd1,3'd4) && is_colinear_idx(3'd0,3'd1,3'd5))) begin
              success <= 1'b1;
              dual_ok <= 1'b1; // reuse as immediate success indicator for next_state
            end else begin
              dual_ok <= 1'b0;
            end
            combo_idx <= 2'd0;
          end
        end

        CHECK_DUAL_LINES: begin
          // Try up to 3 combinations defining first line
          // combo_idx: 0 -> (0,1), 1 -> (0,2), 2 -> (1,2)

          if (!dual_ok && combo_idx < 2'd3) begin
            // Select indices for line1 based on combo_idx
            case (combo_idx)
              2'd0: begin i1 <= 3'd0; i2 <= 3'd1; end
              2'd1: begin i1 <= 3'd0; i2 <= 3'd2; end
              2'd2: begin i1 <= 3'd1; i2 <= 3'd2; end
              default: begin i1 <= 3'd0; i2 <= 3'd1; end
            endcase

            // Determine which points are on line1
            reg [5:0] on_line1;
            reg [2:0] rem_idx[0:5];
            integer k;
            integer rem_count;
            on_line1 = 6'b0;
            rem_count = 0;

            for (k = 0; k < 6; k = k + 1) begin
              if (k == i1 || k == i2) begin
                on_line1[k] = 1'b1;
              end else if (is_colinear_idx(i1, i2, k[2:0])) begin
                on_line1[k] = 1'b1;
              end else begin
                on_line1[k] = 1'b0;
                rem_idx[rem_count] = k[2:0];
                rem_count = rem_count + 1;
              end
            end

            // If no remaining points, success
            if (rem_count == 0) begin
              dual_ok <= 1'b1;
              success <= 1'b1;
            end else if (rem_count == 1) begin
              // Single point always lies on some line; two-shot possible
              dual_ok <= 1'b1;
              success <= 1'b1;
            end else begin
              // Check remaining points colinearity
              integer m;
              reg rem_colinear;
              rem_colinear = 1'b1;
              for (m = 2; m < rem_count; m = m + 1) begin
                if (!is_colinear_idx(rem_idx[0], rem_idx[1], rem_idx[m])) begin
                  rem_colinear = 1'b0;
                end
              end
              if (rem_colinear) begin
                dual_ok <= 1'b1;
                success <= 1'b1;
              end else begin
                // Try next combo
                combo_idx <= combo_idx + 2'd1;
              end
            end
          end
        end

        COMPLETE: begin
          done <= 1'b1;
          // success already set
          if (!start) begin
            // Will return to IDLE via next_state
          end
        end

        default: ;
      endcase
    end
  end

endmodule