module club_fencing_cost(
  input clk,
  input rst_n,
  input start,
  input [3:0] B,
  input [2:0] H,
  input [2:0] R,
  input [2:0] C,
  input [15:0] grid,
  output reg [10:0] total_cost,
  output reg done
);

  // State encoding
  localparam IDLE         = 3'd0;
  localparam CALC_LIGHTS  = 3'd1;
  localparam FIND_DARK    = 3'd2;
  localparam CALC_FENCES  = 3'd3;
  localparam DONE         = 3'd4;

  reg [2:0] state, next_state;

  // Grid intensity storage: 4x4 cells, each 4 bits
  // grid is row-major: [ (r*4 + c)*1 +:1 ] but each cell is 4 bits -> [ (r*4 + c)*4 +:4 ]

  // Light sum per cell (Q16.16)
  reg [31:0] light_sum [0:3][0:3];

  // Cell lit flag (1 if meets B), only internal cells considered; borders forced lit later
  reg lit [0:3][0:3];

  // Loop indices
  reg [1:0] i, j;      // target cell indices
  reg [1:0] r_idx, c_idx; // source cell indices

  // Control flags
  reg calc_done;

  // Working registers for CALC_LIGHTS
  reg [31:0] acc;            // accumulator for one cell light
  reg [5:0] denom;           // denominator <= 3^2 + 3^2 + 5^2 = 43, fits in 6 bits
  reg [5:0] dx, dy;
  reg [5:0] dx2, dy2;
  reg [5:0] h2;
  reg [3:0] src_intensity;
  reg [31:0] term;

  // For division: simple sequential divider (32-bit / 6-bit)
  reg [31:0] div_numerator;
  reg [5:0]  div_denominator;
  reg [31:0] div_quotient;
  reg [31:0] div_remainder;
  reg [5:0]  div_bit;
  reg        div_busy;
  reg        div_start;
  reg        div_done;

  // Fence calculation
  reg [10:0] cost_acc;
  reg [1:0] fi, fj;

  // Helpers to get intensity from flat grid
  function [3:0] get_grid_intensity;
    input [15:0] g;
    input [1:0] rr;
    input [1:0] cc;
    reg [5:0] idx;
  begin
    idx = (rr*4 + cc) << 2;
    get_grid_intensity = g[idx +: 4];
  end
  endfunction

  // Divider: restoring division, one bit per cycle
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      div_busy      <= 1'b0;
      div_done      <= 1'b0;
      div_quotient  <= 32'd0;
      div_remainder <= 32'd0;
      div_bit       <= 6'd0;
    end else begin
      if (div_start) begin
        div_busy      <= 1'b1;
        div_done      <= 1'b0;
        div_quotient  <= 32'd0;
        div_remainder <= 32'd0;
        div_bit       <= 6'd31;
      end else if (div_busy) begin
        // Shift remainder left, bring in next numerator bit
        div_remainder <= {div_remainder[30:0], div_numerator[div_bit]};
        if ({div_remainder[30:0], div_numerator[div_bit]} >= div_denominator) begin
          div_remainder <= ({div_remainder[30:0], div_numerator[div_bit]} - div_denominator);
          div_quotient[div_bit] <= 1'b1;
        end else begin
          div_quotient[div_bit] <= div_quotient[div_bit];
        end
        if (div_bit == 0) begin
          div_busy <= 1'b0;
          div_done <= 1'b1;
        end else begin
          div_bit <= div_bit - 1'b1;
        end
      end else begin
        div_done <= 1'b0;
      end
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start)
          next_state = CALC_LIGHTS;
      end
      CALC_LIGHTS: begin
        if (calc_done)
          next_state = FIND_DARK;
      end
      FIND_DARK: begin
        next_state = CALC_FENCES;
      end
      CALC_FENCES: begin
        // finish when fi, fj loops done
        if (fi == 2'd3 && fj == 2'd3)
          next_state = DONE;
      end
      DONE: begin
        if (!start)
          next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Sequential state, counters, and main operations
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state       <= IDLE;
      done        <= 1'b0;
      total_cost  <= 11'd0;
      i           <= 2'd0;
      j           <= 2'd0;
      r_idx       <= 2'd0;
      c_idx       <= 2'd0;
      acc         <= 32'd0;
      calc_done   <= 1'b0;
      cost_acc    <= 11'd0;
      fi          <= 2'd0;
      fj          <= 2'd0;
      div_start   <= 1'b0;
    end else begin
      state <= next_state;

      case (state)
        IDLE: begin
          done       <= 1'b0;
          total_cost <= 11'd0;
          cost_acc   <= 11'd0;
          calc_done  <= 1'b0;
          i          <= 2'd0;
          j          <= 2'd0;
          r_idx      <= 2'd0;
          c_idx      <= 2'd0;
          acc        <= 32'd0;
          fi         <= 2'd0;
          fj         <= 2'd0;
          div_start  <= 1'b0;
        end

        CALC_LIGHTS: begin
          // Compute light for each cell (i,j) within R x C, others 0.
          // Iterate over all source cells (r_idx,c_idx) and accumulate.
          div_start <= 1'b0;

          if (!calc_done) begin
            if (i < R && j < C) begin
              // For each target cell (i,j), scan all sources
              if (!div_busy && !div_done && r_idx < R && c_idx < C) begin
                // Prepare division for term = src_intensity * 65536 / denom
                dx  = (i > r_idx) ? (i - r_idx) : (r_idx - i);
                dy  = (j > c_idx) ? (j - c_idx) : (c_idx - j);
                dx2 = dx * dx;
                dy2 = dy * dy;
                h2  = H * H;
                denom = dx2 + dy2 + h2;
                src_intensity = get_grid_intensity(grid, r_idx, c_idx);
                if (denom != 0 && src_intensity != 0) begin
                  div_numerator   <= src_intensity * 32'd65536;
                  div_denominator <= denom;
                  div_start       <= 1'b1;
                end else begin
                  // No contribution
                  if (c_idx == C-1) begin
                    c_idx <= 2'd0;
                    if (r_idx == R-1) begin
                      r_idx <= 2'd0;
                      // Move to next target cell
                      light_sum[i][j] <= acc;
                      acc <= 32'd0;
                      if (j == C-1) begin
                        j <= 2'd0;
                        if (i == R-1) begin
                          i <= 2'd0;
                          calc_done <= 1'b1;
                        end else begin
                          i <= i + 2'd1;
                        end
                      end else begin
                        j <= j + 2'd1;
                      end
                    end else begin
                      r_idx <= r_idx + 2'd1;
                    end
                  end else begin
                    c_idx <= c_idx + 2'd1;
                  end
                end
              end else if (div_done) begin
                // Add computed term
                acc <= acc + div_quotient;
                div_start <= 1'b0;
                // Advance source indices
                if (c_idx == C-1) begin
                  c_idx <= 2'd0;
                  if (r_idx == R-1) begin
                    r_idx <= 2'd0;
                    // Finish this target cell
                    light_sum[i][j] <= acc + div_quotient;
                    acc <= 32'd0;
                    if (j == C-1) begin
                      j <= 2'd0;
                      if (i == R-1) begin
                        i <= 2'd0;
                        calc_done <= 1'b1;
                      end else begin
                        i <= i + 2'd1;
                      end
                    end else begin
                      j <= j + 2'd1;
                    end
                  end else begin
                    r_idx <= r_idx + 2'd1;
                  end
                end else begin
                  c_idx <= c_idx + 2'd1;
                end
              end
            end else begin
              // For cells outside R x C, force zero and mark calc_done when indices finish
              light_sum[i][j] <= 32'd0;
              if (j == 2'd3) begin
                j <= 2'd0;
                if (i == 2'd3) begin
                  i <= 2'd0;
                  calc_done <= 1'b1;
                end else begin
                  i <= i + 2'd1;
                end
              end else begin
                j <= j + 2'd1;
              end
            end
          end
        end

        FIND_DARK: begin
          // Determine lit flags: border cells forced lit, internal compare with B (Q16.16)
          integer x, y;
          for (x = 0; x < 4; x = x + 1) begin
            for (y = 0; y < 4; y = y + 1) begin
              if (x >= R || y >= C) begin
                lit[x][y] <= 1'b0; // outside active grid
              end else if (x == 0 || x == R-1 || y == 0 || y == C-1) begin
                lit[x][y] <= 1'b1; // borders guaranteed lit
              end else begin
                // Compare light_sum[x][y] with B in Q16.16 (B << 16)
                if (light_sum[x][y] >= {B,16'd0})
                  lit[x][y] <= 1'b1;
                else
                  lit[x][y] <= 1'b0;
              end
            end
          end
          // Initialize for fence calc
          fi <= 2'd1; // start from internal cell region (edges between 0..R-1 / 0..C-1)
          fj <= 2'd1;
          cost_acc <= 11'd0;
        end

        CALC_FENCES: begin
          // Evaluate internal edges only: horizontal and vertical edges not on border.
          // We'll iterate over potential internal edges using fi,fj as positions and
          // handle both orientations.

          // Horizontal internal edges at (row=fi, between col=fj-1 and fj)
          if (fi < R && fj < C && fi > 0 && fi < R && fj > 0 && fj < C) begin
            // horizontal edge is internal if not touching left/right border
            if (fj > 0 && fj < C) begin
              if (lit[fi][fj-1] ^ lit[fi][fj]) begin
                cost_acc <= cost_acc + 11'd11;
              end else if (lit[fi][fj-1] && lit[fi][fj]) begin
                cost_acc <= cost_acc + 11'd43;
              end
            end
            // Vertical internal edges at (col=fj, between row=fi-1 and fi)
            if (fi > 0 && fi < R) begin
              if (lit[fi-1][fj] ^ lit[fi][fj]) begin
                cost_acc <= cost_acc + 11'd11;
              end else if (lit[fi-1][fj] && lit[fi][fj]) begin
                cost_acc <= cost_acc + 11'd43;
              end
            end
          end

          // Advance scan
          if (fj == 2'd3) begin
            fj <= 2'd1;
            if (fi == 2'd3) begin
              fi <= 2'd3; // will trigger transition to DONE in next_state
            end else begin
              fi <= fi + 2'd1;
            end
          end else begin
            fj <= fj + 2'd1;
          end
        end

        DONE: begin
          done       <= 1'b1;
          total_cost <= cost_acc;
        end

      endcase
    end
  end

endmodule