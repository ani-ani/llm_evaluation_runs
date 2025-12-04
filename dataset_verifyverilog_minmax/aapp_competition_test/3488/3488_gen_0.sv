module minimal_convex_hull_vertices(
  input clk,
  input rst_n,
  input start,
  input [15:0] vx[0:7],
  input [15:0] vy[0:7],
  input [2:0] vertex_count,
  input [15:0] px[0:3],
  input [15:0] py[0:3],
  input [1:0] point_count,
  output reg [2:0] min_vertices,
  output reg done
);
  // State encoding
  localparam IDLE      = 3'b000;
  localparam SETUP     = 3'b001;
  localparam TEST      = 3'b010;
  localparam EVAL      = 3'b011;
  localparam NEXT_COMB = 3'b100;
  localparam DONE      = 3'b101;

  logic [2:0] state, next_state;
  logic [2:0] s;
  logic [7:0] mask;
  logic [7:0] comb_cnt;
  logic [7:0] total_comb;
  logic subset_valid;

  // Compute n choose k
  function automatic int comb(int n, int k);
    int result = 1;
    if (k > n) return 0;
    if (k > n - k) k = n - k;
    for (int i = 0; i < k; i++) begin
      result = result * (n - i) / (i + 1);
    end
    return result;
  endfunction

  // Gosper's hack: next mask with same popcount
  function [7:0] next_combination(input [7:0] mask, input int s);
    logic [7:0] x, ripple, ones;
    x = mask & (~(mask - 1));
    ripple = mask + x;
    ones = mask ^ ripple;
    ones = (ones >> 2) / x;
    return ripple | ones;
  endfunction

  // Test if current mask forms convex polygon containing all internal points
  function automatic bit subset_is_valid(
    input [7:0] mask,
    input int s,
    input int point_cnt,
    input logic [15:0] vx[0:7],
    input logic [15:0] vy[0:7],
    input logic [15:0] px[0:3],
    input logic [15:0] py[0:3]
  );
    int idx[8];
    int cnt;
    longint area;
    int sign;
    // Extract selected vertex indices
    cnt = 0;
    for (int i = 0; i < 8; i++) begin
      if (mask[i]) begin
        idx[cnt] = i;
        cnt++;
        if (cnt == s) break;
      end
    end
    // Signed area to determine orientation
    area = 0;
    for (int i = 0; i < s; i++) begin
      int j = (i + 1) % s;
      area += (longint)vx[idx[i]] * vy[idx[j]] - (longint)vx[idx[j]] * vy[idx[i]];
    end
    if (area > 0) sign = 1;
    else if (area < 0) sign = -1;
    else return 0; // degenerate polygon
    // Point‑in‑polygon test (edge orientation test)
    for (int p = 0; p < point_cnt; p++) begin
      bit inside = 1;
      for (int e = 0; e < s; e++) begin
        int i = idx[e];
        int j = idx[(e + 1) % s];
        longint cross = (longint)(vx[j] - vx[i]) * (py[p] - vy[i]) -
                        (longint)(vy[j] - vy[i]) * (px[p] - vx[i]);
        if (sign == 1) begin
          if (cross < 0) begin inside = 0; break; end
        end else begin
          if (cross > 0) begin inside = 0; break; end
        end
      end
      if (!inside) return 0;
    end
    return 1;
  endfunction

  // Number of combinations for current size
  always_comb begin
    total_comb = comb(int'(vertex_count), s);
  end

  // Validity of the current subset
  assign subset_valid = subset_is_valid(mask, s, int'(point_count), vx, vy, px, py);

  // FSM: state transition logic
  always_comb begin
    next_state = state;
    case (state)
      IDLE:      if (start) next_state = SETUP;
      SETUP:                     next_state = TEST;
      TEST:                      next_state = EVAL;
      EVAL:      if (subset_valid) next_state = DONE;
                 else                next_state = NEXT_COMB;
      NEXT_COMB:                 next_state = TEST;
      DONE:      if (!start) next_state = IDLE;
                 else        next_state = DONE;
    endcase
  end

  // FSM: registers update
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      s <= 0;
      mask <= 0;
      comb_cnt <= 0;
      min_vertices <= 0;
      done <= 0;
    end else begin
      state <= next_state;
      case (state)
        IDLE: begin
          s <= 0;
          mask <= 0;
          comb_cnt <= 0;
          min_vertices <= 0;
          done <= 0;
        end
        SETUP: begin
          s <= 3;
          mask <= (1 << 3) - 1; // 0b00000111
          comb_cnt <= 0;
          min_vertices <= 0;
          done <= 0;
        end
        EVAL: begin
          if (subset_valid) begin
            min_vertices <= s;
            done <= 1;
          end
        end
        NEXT_COMB: begin
          int new_cnt;
          new_cnt = comb_cnt + 1;
          if (new_cnt < total_comb) begin
            comb_cnt <= new_cnt;
            mask <= next_combination(mask, s);
          end else begin
            // all combinations for this size processed
            if (s < vertex_count) begin
              s <= s + 1;
              comb_cnt <= 0;
              mask <= (1 << s) - 1;
            end else begin
              // No valid subset found, use full set
              min_vertices <= vertex_count;
              done <= 1;
            end
          end
        end
        DONE: begin
          // hold outputs
        end
        // TEST does not change any registers
      endcase
    end
  end

endmodule