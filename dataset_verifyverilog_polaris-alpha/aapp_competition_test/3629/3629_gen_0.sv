module boar_charge_probability(
  input clk,
  input rst_n,
  input start,
  input [2:0] tree_count,
  input [15:0] b,
  input [15:0] d,
  input [15:0] tree_x [0:7],
  input [15:0] tree_y [0:7],
  input [15:0] tree_r [0:7],
  output reg [31:0] prob_q16,
  output reg done
);

  // Constants
  localparam [31:0] PI_Q16 = 32'h0003243F;      // Given (truncated as provided)
  localparam [31:0] RAD2DEG_Q16 = 32'h0000921F; // Approx 57.2958 in Q16.16
  localparam [31:0] DEG360_Q16 = 32'h01680000;  // 360.0 in Q16.16

  // FSM states
  typedef enum logic [4:0] {
    S_IDLE      = 5'd0,
    S_START     = 5'd1,
    S_TREE0     = 5'd2,
    S_TREE1     = 5'd3,
    S_TREE2     = 5'd4,
    S_TREE3     = 5'd5,
    S_TREE4     = 5'd6,
    S_TREE5     = 5'd7,
    S_TREE6     = 5'd8,
    S_TREE7     = 5'd9,
    S_MERGE0    = 5'd10,
    S_MERGE1    = 5'd11,
    S_MERGE2    = 5'd12,
    S_MERGE3    = 5'd13,
    S_MERGE4    = 5'd14,
    S_MERGE5    = 5'd15,
    S_MERGE6    = 5'd16,
    S_MERGE7    = 5'd17,
    S_PROB      = 5'd18,
    S_DONE      = 5'd19
  } state_t;

  state_t state, next_state;

  // Interval storage: up to 8 intervals (start/end in degrees Q16.16)
  reg [31:0] int_start[0:7];
  reg [31:0] int_end  [0:7];
  reg [2:0]  int_valid; // bitmask for 0..7 intervals

  // Latched inputs for stability during computation
  reg [2:0]  tree_count_l;
  reg [15:0] b_l;
  reg [15:0] d_l;
  reg [15:0] tree_x_l[0:7];
  reg [15:0] tree_y_l[0:7];
  reg [15:0] tree_r_l[0:7];

  // Intermediate signals for per-tree processing
  reg [2:0] tree_idx;

  // Fixed point helpers
  function automatic [31:0] to_q16_16(input signed [31:0] v);
    to_q16_16 = v <<< 16;
  endfunction

  // Unsigned 16-bit square -> 32-bit
  function automatic [31:0] sq16u(input [15:0] v);
    sq16u = v * v;
  endfunction

  // Signed 16-bit square -> 32-bit
  function automatic [31:0] sq16s(input signed [15:0] v);
    sq16s = v * v;
  endfunction

  // Saturating add 32-bit unsigned
  function automatic [31:0] add_sat32(input [31:0] a, input [31:0] b);
    reg [32:0] sum;
    begin
      sum = a + b;
      if (sum[32]) add_sat32 = 32'hFFFF_FFFF;
      else add_sat32 = sum[31:0];
    end
  endfunction

  // Minimum / Maximum for 32-bit
  function automatic [31:0] umin32(input [31:0] a, input [31:0] b);
    umin32 = (a < b) ? a : b;
  endfunction

  function automatic [31:0] umax32(input [31:0] a, input [31:0] b);
    umax32 = (a > b) ? a : b;
  endfunction

  // Simple unsigned divide 64/32 -> 32 (trunc)
  function automatic [31:0] div64_32(input [63:0] num, input [31:0] den);
    reg [63:0] q;
    reg [63:0] r;
    integer i;
    begin
      q = 0;
      r = 0;
      if (den == 0) begin
        div64_32 = 32'hFFFFFFFF;
      end else begin
        for (i = 63; i >= 0; i = i - 1) begin
          r = {r[62:0], num[i]};
          if (r >= den) begin
            r = r - den;
            q[i] = 1'b1;
          end
        end
        div64_32 = q[31:0];
      end
    end
  endfunction

  // Approximate atan2 in radians(Q16.16), using a simple piecewise-linear method
  function automatic [31:0] atan2_q16(input signed [31:0] y, input signed [31:0] x);
    // Returns angle in radians, range [-pi, pi]
    // Based on a small-angle approximation for hardware-friendliness.
    reg [31:0] abs_y, r, angle;
    reg sign_y;
    begin
      sign_y = (y[31] == 1'b1);
      abs_y = sign_y ? (~y + 1'b1) : y;

      if (x[31] == 1'b0 && x != 0) begin
        // x > 0
        // angle = y/x approximation
        r = div64_32({32'b0, abs_y}, x[31:0]);
        angle = r * PI_Q16 >> 1; // crude scale
      end else if (x[31] == 1'b1) begin
        // x < 0
        r = div64_32({32'b0, abs_y}, (~x + 1'b1));
        angle = (PI_Q16 - (r * PI_Q16 >> 1));
      end else begin
        // x == 0
        angle = (y[31]) ? (~(PI_Q16>>1) + 1'b1) : (PI_Q16>>1);
      end

      if (sign_y) begin
        atan2_q16 = (~angle) + 1'b1;
      end else begin
        atan2_q16 = angle;
      end
    end
  endfunction

  // Approximate arccos in radians(Q16.16), for |x|<=1 in Q16.16
  function automatic [31:0] acos_q16(input [31:0] x_q16);
    // Use linear approximation: acos(x) ~ (pi/2) - x
    reg [31:0] half_pi;
    begin
      half_pi = (PI_Q16 >> 1);
      acos_q16 = (half_pi > x_q16) ? (half_pi - x_q16) : 32'd0;
    end
  endfunction

  // Compute blocked angular interval for one tree
  task automatic compute_interval(
    input  [15:0] x_in,
    input  [15:0] y_in,
    input  [15:0] r_in,
    output [31:0] o_start_deg,
    output [31:0] o_end_deg,
    output        o_valid
  );
    // Integer math, approximate geometry.
    // 1) distance^2
    // 2) if out of (d + b + r)^2 range, invalid
    // 3) center angle = atan2(y, x)
    // 4) half-angle = acos((dist^2 + (d)^2 - (r+b)^2)/(2*d*dist)) approx
    // 5) convert to degrees and clamp to [0,360)

    reg signed [15:0] xs, ys;
    reg [31:0] dist2;
    reg [31:0] sum_r;
    reg [31:0] reach;
    reg [31:0] reach2;
    reg        valid;

    reg signed [31:0] xs32, ys32;
    reg [31:0] dist;
    reg [63:0] num64;
    reg [31:0] den32;
    reg [31:0] cos_q16;
    reg [31:0] halfang_rad;
    reg [31:0] center_rad;
    reg [31:0] center_deg;
    reg [31:0] halfang_deg;
    reg [31:0] start_deg;
    reg [31:0] end_deg;

    begin
      xs = x_in;
      ys = y_in;
      xs32 = xs;
      ys32 = ys;
      dist2 = sq16s(xs) + sq16s(ys);
      sum_r = b + r_in;
      reach = d + sum_r[15:0];
      reach2 = reach * reach;

      if (dist2 > reach2 || dist2 == 0) begin
        valid = 1'b0;
      end else begin
        // dist ~ sqrt(dist2), simple shift-based approx: take upper 16 bits of dist2
        dist = {dist2[31:16], 16'b0};
        if (dist == 0) begin
          valid = 1'b0;
        end else begin
          // cos(theta) term in Q16.16
          // cos = (dist2 + d^2 - (sum_r)^2) / (2*d*sqrt(dist2))
          num64 = {32'b0, dist2} + {32'b0, (d * d)} - {32'b0, (sum_r * sum_r)};
          den32 = (d != 0) ? (2 * d) : 32'd1;
          den32 = den32 * (dist[31:16] != 0 ? dist[31:16] : 16'd1);
          if (den32 == 0) begin
            valid = 1'b0;
          end else begin
            if ($signed(num64[63:32]) < 0) cos_q16 = 32'd0;
            else cos_q16 = div64_32(num64, den32);

            halfang_rad = acos_q16(cos_q16);
            center_rad  = atan2_q16(ys32, xs32);

            // to degrees: rad * RAD2DEG_Q16 >>16
            center_deg   = (center_rad * RAD2DEG_Q16) >> 16;
            halfang_deg  = (halfang_rad * RAD2DEG_Q16) >> 16;

            // form interval
            if (center_deg[31]) center_deg = 32'd0; // clamp negative
            start_deg = (center_deg > halfang_deg) ? (center_deg - halfang_deg) : 32'd0;
            end_deg   = center_deg + halfang_deg;
            if (end_deg > DEG360_Q16) end_deg = DEG360_Q16;

            if (end_deg <= start_deg) valid = 1'b0;
            else valid = 1'b1;
          end
        end
      end

      o_start_deg = start_deg;
      o_end_deg   = end_deg;
      o_valid     = valid;
    end
  endtask

  // Merge helper: merge all valid intervals into total blocked degrees
  function automatic [31:0] merge_intervals_and_sum(
    input [31:0] s0, input [31:0] e0, input bit v0,
    input [31:0] s1, input [31:0] e1, input bit v1,
    input [31:0] s2, input [31:0] e2, input bit v2,
    input [31:0] s3, input [31:0] e3, input bit v3,
    input [31:0] s4, input [31:0] e4, input bit v4,
    input [31:0] s5, input [31:0] e5, input bit v5,
    input [31:0] s6, input [31:0] e6, input bit v6,
    input [31:0] s7, input [31:0] e7, input bit v7
  );
    // Simple O(N^2) selection sort + merge for N<=8
    reg [31:0] ss[0:7];
    reg [31:0] ee[0:7];
    reg        vv[0:7];
    integer i, j, min_idx;
    reg [31:0] tmp_s, tmp_e;
    reg        tmp_v;
    reg [31:0] cur_s, cur_e;
    reg [31:0] total;

    begin
      ss[0]=s0; ee[0]=e0; vv[0]=v0;
      ss[1]=s1; ee[1]=e1; vv[1]=v1;
      ss[2]=s2; ee[2]=e2; vv[2]=v2;
      ss[3]=s3; ee[3]=e3; vv[3]=v3;
      ss[4]=s4; ee[4]=e4; vv[4]=v4;
      ss[5]=s5; ee[5]=e5; vv[5]=v5;
      ss[6]=s6; ee[6]=e6; vv[6]=v6;
      ss[7]=s7; ee[7]=e7; vv[7]=v7;

      // Selection sort by start
      for (i = 0; i < 7; i = i + 1) begin
        min_idx = i;
        for (j = i+1; j < 8; j = j + 1) begin
          if (vv[j] && (!vv[min_idx] || ss[j] < ss[min_idx])) begin
            min_idx = j;
          end
        end
        if (min_idx != i) begin
          tmp_s = ss[i]; ss[i] = ss[min_idx]; ss[min_idx] = tmp_s;
          tmp_e = ee[i]; ee[i] = ee[min_idx]; ee[min_idx] = tmp_e;
          tmp_v = vv[i]; vv[i] = vv[min_idx]; vv[min_idx] = tmp_v;
        end
      end

      // Merge
      total = 0;
      cur_s = 0;
      cur_e = 0;

      for (i = 0; i < 8; i = i + 1) begin
        if (vv[i]) begin
          if (total == 0 && cur_e == 0) begin
            // first interval
            cur_s = ss[i];
            cur_e = ee[i];
          end else begin
            if (ss[i] <= cur_e) begin
              // overlap
              if (ee[i] > cur_e) cur_e = ee[i];
            end else begin
              // disjoint, accumulate and start new
              total = total + (cur_e - cur_s);
              cur_s = ss[i];
              cur_e = ee[i];
            end
          end
        end
      end

      if (cur_e > cur_s) total = total + (cur_e - cur_s);

      // Clamp to 0..360
      if (total > DEG360_Q16) total = DEG360_Q16;
      merge_intervals_and_sum = total;
    end
  endfunction

  // FSM: state register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state      <= S_IDLE;
      done       <= 1'b0;
      prob_q16   <= 32'd0;
      tree_count_l <= 3'd0;
      b_l <= 16'd0;
      d_l <= 16'd0;
      int_valid <= 3'd0;
      tree_idx <= 3'd0;
    end else begin
      state <= next_state;
    end
  end

  // FSM: next-state and outputs
  integer k;
  reg [31:0] s_deg, e_deg;
  reg v_int;
  reg [31:0] blocked_deg;
  reg [63:0] num_prob;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done     <= 1'b0;
      prob_q16 <= 32'd0;
    end else begin
      case (state)
        S_IDLE: begin
          done     <= 1'b0;
          prob_q16 <= 32'd0;
          if (start) begin
            // Latch inputs
            tree_count_l <= tree_count;
            b_l          <= b;
            d_l          <= d;
            for (k = 0; k < 8; k = k + 1) begin
              tree_x_l[k] <= tree_x[k];
              tree_y_l[k] <= tree_y[k];
              tree_r_l[k] <= tree_r[k];
              int_start[k] <= 32'd0;
              int_end[k]   <= 32'd0;
            end
            int_valid <= 3'd0;
            tree_idx  <= 3'd0;
          end
        end

        S_START: begin
          done <= 1'b0;
        end

        // Per-tree states: compute interval for each tree index
        S_TREE0, S_TREE1, S_TREE2, S_TREE3,
        S_TREE4, S_TREE5, S_TREE6, S_TREE7: begin
          done <= 1'b0;
          // Map state to tree_idx
          case (state)
            S_TREE0: tree_idx <= 3'd0;
            S_TREE1: tree_idx <= 3'd1;
            S_TREE2: tree_idx <= 3'd2;
            S_TREE3: tree_idx <= 3'd3;
            S_TREE4: tree_idx <= 3'd4;
            S_TREE5: tree_idx <= 3'd5;
            S_TREE6: tree_idx <= 3'd6;
            S_TREE7: tree_idx <= 3'd7;
            default: tree_idx <= 3'd0;
          endcase

          if (tree_idx < tree_count_l) begin
            compute_interval(
              tree_x_l[tree_idx],
              tree_y_l[tree_idx],
              tree_r_l[tree_idx],
              s_deg,
              e_deg,
              v_int
            );
            int_start[tree_idx] <= s_deg;
            int_end[tree_idx]   <= e_deg;
          end else begin
            v_int               <= 1'b0;
            int_start[tree_idx] <= 32'd0;
            int_end[tree_idx]   <= 32'd0;
          end
        end

        // Merge steps spread over cycles to match latency (MERGE0..MERGE7)
        S_MERGE0, S_MERGE1, S_MERGE2, S_MERGE3,
        S_MERGE4, S_MERGE5, S_MERGE6, S_MERGE7: begin
          done <= 1'b0;
        end

        S_PROB: begin
          done <= 1'b0;
          blocked_deg = merge_intervals_and_sum(
            int_start[0], int_end[0], (0 < tree_count_l),
            int_start[1], int_end[1], (1 < tree_count_l),
            int_start[2], int_end[2], (2 < tree_count_l),
            int_start[3], int_end[3], (3 < tree_count_l),
            int_start[4], int_end[4], (4 < tree_count_l),
            int_start[5], int_end[5], (5 < tree_count_l),
            int_start[6], int_end[6], (6 < tree_count_l),
            int_start[7], int_end[7], (7 < tree_count_l)
          );

          // safe = (360 - blocked)/360 in Q16.16
          if (blocked_deg >= DEG360_Q16) begin
            prob_q16 <= 32'd0;
          end else begin
            num_prob = {16'd0, (DEG360_Q16 - blocked_deg)} << 16;
            prob_q16 <= div64_32(num_prob, DEG360_Q16);
          end
        end

        S_DONE: begin
          done <= 1'b1;
        end

        default: begin
          done <= 1'b0;
        end
      endcase
    end
  end

  // Next state logic (cycle scheduling): target overall 25 cycles
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE:    next_state = start ? S_START : S_IDLE;
      S_START:   next_state = S_TREE0;
      S_TREE0:   next_state = S_TREE1;
      S_TREE1:   next_state = S_TREE2;
      S_TREE2:   next_state = S_TREE3;
      S_TREE3:   next_state = S_TREE4;
      S_TREE4:   next_state = S_TREE5;
      S_TREE5:   next_state = S_TREE6;
      S_TREE6:   next_state = S_TREE7;
      S_TREE7:   next_state = S_MERGE0;
      S_MERGE0:  next_state = S_MERGE1;
      S_MERGE1:  next_state = S_MERGE2;
      S_MERGE2:  next_state = S_MERGE3;
      S_MERGE3:  next_state = S_MERGE4;
      S_MERGE4:  next_state = S_MERGE5;
      S_MERGE5:  next_state = S_MERGE6;
      S_MERGE6:  next_state = S_MERGE7;
      S_MERGE7:  next_state = S_PROB;
      S_PROB:    next_state = S_DONE;
      S_DONE:    next_state = start ? S_DONE : S_IDLE; // wait for start deassert
      default:   next_state = S_IDLE;
    endcase
  end

endmodule