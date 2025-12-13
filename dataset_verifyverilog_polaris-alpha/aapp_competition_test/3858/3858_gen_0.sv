module convex_score_sum(
  input        clk,
  input        rst_n,
  input        start,
  input  [3:0] x [0:7],
  input  [3:0] y [0:7],
  output reg [29:0] sum,
  output reg        done
);

  // Parameters
  localparam MOD       = 30'd998244353;
  localparam BASE      = 30'd219;        // 2^8 - 1 - 8 - 28
  localparam TOTAL_CYC = 6'd20;

  // State
  reg        running;
  reg [5:0]  cycle_cnt;
  reg [15:0] total_lines;                // count of lines (i<j) processed
  reg [29:0] sum_reg;

  // Track collinearity groups
  // For each unordered pair (i,j), select minimal k>j collinear (i,j,k)
  // and then count all points on that same line (i,j,*) using that anchor.

  // Index expansion for (i,j,k)
  function automatic [5:0] idx_cnt_pairs;
    input [2:0] i;
    input [2:0] j;
    integer t;
    begin
      idx_cnt_pairs = 0;
      for (t = 0; t < 8; t = t + 1) begin
        if (t < i)
          idx_cnt_pairs = idx_cnt_pairs + (7 - t);
      end
      idx_cnt_pairs = idx_cnt_pairs + (j - i - 1);
    end
  endfunction

  // Combinational: compute c (number of points on line defined by chosen anchor pair),
  // valid flag (whether we should subtract for this line), and penalty.
  reg        line_valid;
  reg [4:0]  c_points;
  reg [29:0] penalty;

  // Helper: modular add/sub
  function automatic [29:0] addmod;
    input [29:0] a, b;
    reg   [30:0] tmp;
    begin
      tmp = a + b;
      if (tmp >= MOD)
        addmod = tmp - MOD;
      else
        addmod = tmp[29:0];
    end
  endfunction

  function automatic [29:0] submod;
    input [29:0] a, b;
    reg   [30:0] tmp;
    begin
      tmp = {1'b0,a} + {1'b1,~b} + 1'b1; // a - b in 2's complement width 31
      if (tmp[30])
        submod = tmp[29:0] + MOD;
      else if (tmp[29:0] >= MOD)
        submod = tmp[29:0] - MOD;
      else
        submod = tmp[29:0];
    end
  endfunction

  // Compute gcd of two signed 8-bit values (magnitude up to 15*7=105, safe in 8 bits signed range)
  function automatic [7:0] gcd8;
    input signed [7:0] a_in;
    input signed [7:0] b_in;
    reg   signed [7:0] a, b, t;
    begin
      a = (a_in < 0) ? -a_in : a_in;
      b = (b_in < 0) ? -b_in : b_in;
      if (a == 0) begin
        gcd8 = (b == 0) ? 8'd1 : b[7:0];
      end else if (b == 0) begin
        gcd8 = a[7:0];
      end else begin
        while (b != 0) begin
          t = a % b;
          a = b;
          b = t;
        end
        gcd8 = (a == 0) ? 8'd1 : a[7:0];
      end
    end
  endfunction

  // Normalize direction (dx,dy) to a canonical reduced form
  function automatic [15:0] norm_dir;
    input signed [7:0] dx_in;
    input signed [7:0] dy_in;
    reg   signed [7:0] dx, dy;
    reg   [7:0] g;
    begin
      dx = dx_in;
      dy = dy_in;
      if (dx == 0 && dy == 0) begin
        norm_dir = 16'h0000;
      end else begin
        if (dx == 0) begin
          dy = (dy < 0) ? -dy : dy;
        end else if (dy == 0) {
          // ensure dx positive
          if (dx < 0) dx = -dx;
        end else begin
          // make dx positive; if dx negative, flip both
          if (dx < 0) begin
            dx = -dx;
            dy = -dy;
          end
        end
        g = gcd8(dx, dy);
        if (g != 0) begin
          dx = dx / g;
          dy = dy / g;
        end
        norm_dir = {dx[7:0], dy[7:0]};
      end
    end
  endfunction

  // Popcount for up to 8 bits
  function automatic [3:0] popcount8;
    input [7:0] v;
    reg [3:0] s;
    integer ii;
    begin
      s = 0;
      for (ii = 0; ii < 8; ii = ii + 1)
        s = s + v[ii];
      popcount8 = s;
    end
  endfunction

  // Compute penalty (2^c - c - 1) for 2 <= c <= 8
  function automatic [29:0] compute_penalty;
    input [4:0] c;
    reg [29:0] val;
    begin
      case (c)
        5'd2: val = 30'd1;   // 4 - 2 - 1
        5'd3: val = 30'd4;   // 8 - 3 - 1
        5'd4: val = 30'd11;  // 16 - 4 - 1
        5'd5: val = 30'd26;  // 32 - 5 - 1
        5'd6: val = 30'd57;  // 64 - 6 - 1
        5'd7: val = 30'd120; // 128 - 7 - 1
        5'd8: val = 30'd247; // 256 - 8 - 1
        default: val = 30'd0;
      endcase
      compute_penalty = val;
    end
  endfunction

  // Combinational block: given current total_lines, build (i,j) and compute penalty for that line
  integer i_idx, j_idx, k_idx, t;
  reg [2:0] i_cur, j_cur;
  reg [7:0] anchor_mask;
  reg [7:0] line_mask;
  reg [15:0] dir_ij;
  reg [15:0] dir_ik;

  always @* begin
    // Default outputs
    line_valid = 1'b0;
    c_points   = 5'd0;
    penalty    = 30'd0;

    if (running && (cycle_cnt > 0) && (cycle_cnt <= 6'd19)) begin
      // total_lines in [1..28]
      // Decode (i,j) from total_lines-1
      // There are 28 lines: for i=0..6, j=i+1..7
      // We walk i until remaining < (7-i)
      integer rem;
      rem = total_lines - 1;
      i_idx = 0;
      while (i_idx < 7 && rem >= (7 - i_idx)) begin
        rem = rem - (7 - i_idx);
        i_idx = i_idx + 1;
      end
      j_idx = i_idx + 1 + rem;
      i_cur = i_idx[2:0];
      j_cur = j_idx[2:0];

      // Build anchor_mask: for k>j_cur that are collinear with (i_cur,j_cur)
      anchor_mask = 8'b0;

      // Direction for (i,j)
      dir_ij = norm_dir(
                 $signed({1'b0, x[j_cur]}) - $signed({1'b0, x[i_cur]}),
                 $signed({1'b0, y[j_cur]}) - $signed({1'b0, y[i_cur]})
               );

      for (k_idx = 0; k_idx < 8; k_idx = k_idx + 1) begin
        if (k_idx > j_cur) begin
          dir_ik = norm_dir(
                     $signed({1'b0, x[k_idx[2:0]]}) - $signed({1'b0, x[i_cur]}),
                     $signed({1'b0, y[k_idx[2:0]]}) - $signed({1'b0, y[i_cur]})
                   );
          if (dir_ik == dir_ij)
            anchor_mask[k_idx] = 1'b1;
        end
      end

      // Find minimal k>j with collinearity; if none, no penalty for this (i,j)
      k_idx = -1;
      for (t = j_cur + 1; t < 8; t = t + 1) begin
        if (anchor_mask[t]) begin
          if (k_idx < 0)
            k_idx = t;
        end
      end

      if (k_idx >= 0) begin
        // We use (i_cur,k_idx) as representative for this line.
        // Count all points on line through i_cur and k_idx.
        line_mask = 8'b0;
        line_mask[i_cur] = 1'b1;
        line_mask[k_idx] = 1'b1;

        dir_ik = norm_dir(
                   $signed({1'b0, x[k_idx[2:0]]}) - $signed({1'b0, x[i_cur]}),
                   $signed({1'b0, y[k_idx[2:0]]}) - $signed({1'b0, y[i_cur]})
                 );

        for (t = 0; t < 8; t = t + 1) begin
          if ((t != i_cur) && (t != k_idx)) begin
            if (norm_dir(
                  $signed({1'b0, x[t[2:0]]}) - $signed({1'b0, x[i_cur]}),
                  $signed({1'b0, y[t[2:0]]}) - $signed({1'b0, y[i_cur]})
                ) == dir_ik)
              line_mask[t] = 1'b1;
          end
        end

        c_points = popcount8(line_mask);
        if (c_points >= 5'd2) begin
          line_valid = 1'b1;
          penalty    = compute_penalty(c_points);
        end
      end
    end
  end

  // Sequential control & accumulation
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      running     <= 1'b0;
      cycle_cnt   <= 6'd0;
      total_lines <= 16'd0;
      sum_reg     <= 30'd0;
      sum         <= 30'd0;
      done        <= 1'b0;
    end else begin
      if (!running) begin
        done <= 1'b0;
        if (start) begin
          running     <= 1'b1;
          cycle_cnt   <= 6'd0;
          total_lines <= 16'd0;
          sum_reg     <= BASE; // initialize with base value
        end
      end else begin
        // running
        cycle_cnt <= cycle_cnt + 6'd1;

        // From cycle 1 to 19, process lines sequentially
        if ((cycle_cnt > 0) && (cycle_cnt <= 6'd19)) begin
          if (line_valid) begin
            if (sum_reg >= penalty)
              sum_reg <= sum_reg - penalty;
            else
              sum_reg <= sum_reg + MOD - penalty;
          end
          total_lines <= total_lines + 16'd1;
        end

        if (cycle_cnt == (TOTAL_CYC - 1)) begin
          // At cycle 19 (0-based), finalize
          sum    <= sum_reg % MOD;
          done   <= 1'b1;
          running<= 1'b0;
        end
      end
    end
  end

endmodule