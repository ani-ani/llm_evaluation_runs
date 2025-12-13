module galactic_path_optimizer(
  input              clk,
  input              rst_n,
  input              start,
  input      [8:0]   x1, y1, z1,
  input      [8:0]   x2, y2, z2,
  input      [8:0]   x3, y3, z3,
  input      [8:0]   x4, y4, z4,
  output reg [31:0]  min_distance,
  output reg         done
);

  // Internal signals
  typedef enum logic [5:0] {
    S_IDLE          = 6'd0,
    // Compute squared deltas for all pairs
    S_D12_DX        = 6'd1,
    S_D12_DY        = 6'd2,
    S_D12_DZ        = 6'd3,
    S_D12_SQ        = 6'd4,
    S_D13_DX        = 6'd5,
    S_D13_DY        = 6'd6,
    S_D13_DZ        = 6'd7,
    S_D13_SQ        = 6'd8,
    S_D14_DX        = 6'd9,
    S_D14_DY        = 6'd10,
    S_D14_DZ        = 6'd11,
    S_D14_SQ        = 6'd12,
    S_D23_DX        = 6'd13,
    S_D23_DY        = 6'd14,
    S_D23_DZ        = 6'd15,
    S_D23_SQ        = 6'd16,
    S_D24_DX        = 6'd17,
    S_D24_DY        = 6'd18,
    S_D24_DZ        = 6'd19,
    S_D24_SQ        = 6'd20,
    S_D34_DX        = 6'd21,
    S_D34_DY        = 6'd22,
    S_D34_DZ        = 6'd23,
    S_D34_SQ        = 6'd24,
    // Compute sqrt and scale to Q16.16 for each pair
    S_SQRT_12       = 6'd25,
    S_SQRT_13       = 6'd26,
    S_SQRT_14       = 6'd27,
    S_SQRT_23       = 6'd28,
    S_SQRT_24       = 6'd29,
    S_SQRT_34       = 6'd30,
    // Evaluate patterns and permutations
    S_INIT_EVAL     = 6'd31,
    S_EVAL          = 6'd32,
    S_DONE          = 6'd33
  } state_t;

  state_t state, next_state;

  // Pairwise squared distances (up to ~3*511^2 < 27 bits)
  reg [31:0] d12_sq, d13_sq, d14_sq, d23_sq, d24_sq, d34_sq;

  // Pairwise distances in Q16.16 (16 int,16 frac)
  reg [31:0] d12_q, d13_q, d14_q, d23_q, d24_q, d34_q;

  // Working registers for squared distance calculation
  reg signed [9:0] dx, dy, dz;           // -511..511
  reg [19:0] dx2, dy2, dz2;              // up to 511^2 = 261121 < 2^18 -> use some margin
  reg [21:0] sum_tmp;                    // fits sum of three 20b

  // For generic sqrt integer (of 32-bit sq) to get 16.16 format:
  // We compute integer distance = floor(sqrt(d_sq)), then scale by <<16.

  // Inputs latched at start
  reg [8:0] x1_r, y1_r, z1_r;
  reg [8:0] x2_r, y2_r, z2_r;
  reg [8:0] x3_r, y3_r, z3_r;
  reg [8:0] x4_r, y4_r, z4_r;

  // sqrt engine
  reg [31:0] sqrt_in;
  reg [15:0] sqrt_res;

  // Evaluation indices
  reg [4:0] pattern_idx;    // 0..5 patterns: portal pairs among 4 nodes
  reg [2:0] perm_idx;       // 0..5 permutations of visiting order for planets 2,3,4

  reg [31:0] current_min;
  reg [31:0] current_total;

  // Predecoded pairwise distances lookup function
  function automatic [31:0] get_dist_q;
    input [1:0] a;
    input [1:0] b;
    begin
      case ({a,b})
        4'b0001,4'b0100: get_dist_q = d12_q; // 1-2
        4'b0010,4'b1000: get_dist_q = d13_q; // 1-3
        4'b0011,4'b1100: get_dist_q = d14_q; // 1-4
        4'b0110,4'b1001: get_dist_q = d23_q; // 2-3
        4'b0111,4'b1101: get_dist_q = d24_q; // 2-4
        4'b1011,4'b1110: get_dist_q = d34_q; // 3-4
        default: get_dist_q = 32'd0;
      endcase
    end
  endfunction

  // Encode nodes: 0: planet1 (home), 1: planet2, 2: planet3, 3: planet4

  // sqrt: non-restoring / binary method (integer sqrt of 32-bit input)
  function automatic [15:0] isqrt16;
    input [31:0] x;
    reg [31:0] rem;
    reg [17:0] root;
    reg [17:0] trial;
    integer i;
    begin
      rem  = 0;
      root = 0;
      for (i = 15; i >= 0; i = i - 1) begin
        rem   = {rem[29:0], x[2*i +: 2]};
        trial = (root << 1) + 1;
        if (rem >= trial) begin
          rem  = rem - trial;
          root = trial;
        end else begin
          root = root - 1'b1 + 1'b1; // keep even to align next trial; no-op structurally
        end
      end
      isqrt16 = root[15:0];
    end
  endfunction

  // Permutation generator for planets {1,2,3} represented as nodes {1,2,3}
  function automatic [5:0][1:0] get_perm;
    input [2:0] idx;
    reg [5:0][1:0] dummy;
    begin
      // We'll only use [0], [1], [2] entries (each 2 bits)
      case (idx)
        3'd0: begin dummy[0]=2'd1; dummy[1]=2'd2; dummy[2]=2'd3; end // 2,3,4
        3'd1: begin dummy[0]=2'd1; dummy[1]=2'd3; dummy[2]=2'd2; end // 2,4,3
        3'd2: begin dummy[0]=2'd2; dummy[1]=2'd1; dummy[2]=2'd3; end // 3,2,4
        3'd3: begin dummy[0]=2'd2; dummy[1]=2'd3; dummy[2]=2'd1; end // 3,4,2
        3'd4: begin dummy[0]=2'd3; dummy[1]=2'd1; dummy[2]=2'd2; end // 4,2,3
        default: begin dummy[0]=2'd3; dummy[1]=2'd2; dummy[2]=2'd1; end // 4,3,2
      endcase
      get_perm = dummy;
    end
  endfunction

  // Portal pattern: 6 possibilities for a single-use zero-cost edge between two planets
  // We encode as pair (p_a, p_b) each 2 bits in [3:0]
  function automatic [3:0] get_pattern_pair;
    input [4:0] idx;
    begin
      case (idx[2:0])
        3'd0: get_pattern_pair = {2'd0,2'd1}; // 1-2
        3'd1: get_pattern_pair = {2'd0,2'd2}; // 1-3
        3'd2: get_pattern_pair = {2'd0,2'd3}; // 1-4
        3'd3: get_pattern_pair = {2'd1,2'd2}; // 2-3
        3'd4: get_pattern_pair = {2'd1,2'd3}; // 2-4
        default: get_pattern_pair = {2'd2,2'd3}; // 3-4
      endcase
    end
  endfunction

  // Compute cost of a path with given portal pair
  function automatic [31:0] path_cost;
    input [1:0] n0; // start (home=0)
    input [1:0] n1;
    input [1:0] n2;
    input [1:0] n3;
    input [1:0] portal_a;
    input [1:0] portal_b;
    reg used_portal;
    reg [31:0] cost;
    reg [1:0] c_from, c_to;
    reg [31:0] seg;
    integer i2;
    begin
      cost = 32'd0;
      used_portal = 1'b0;
      c_from = n0;
      for (i2 = 0; i2 < 4; i2 = i2 + 1) begin
        case (i2)
          0: c_to = n1;
          1: c_to = n2;
          2: c_to = n3;
          default: c_to = n0; // return to home
        endcase
        if (!used_portal && ((c_from == portal_a && c_to == portal_b) || (c_from == portal_b && c_to == portal_a))) begin
          seg = 32'd0; // zero-cost via portal
          used_portal = 1'b1;
        end else begin
          seg = get_dist_q(c_from, c_to);
        end
        cost = cost + seg;
      end
      path_cost = cost;
    end
  endfunction

  // State register
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state        <= S_IDLE;
      d12_sq       <= 32'd0;
      d13_sq       <= 32'd0;
      d14_sq       <= 32'd0;
      d23_sq       <= 32'd0;
      d24_sq       <= 32'd0;
      d34_sq       <= 32'd0;
      d12_q        <= 32'd0;
      d13_q        <= 32'd0;
      d14_q        <= 32'd0;
      d23_q        <= 32'd0;
      d24_q        <= 32'd0;
      d34_q        <= 32'd0;
      dx           <= 10'sd0;
      dy           <= 10'sd0;
      dz           <= 10'sd0;
      dx2          <= 20'd0;
      dy2          <= 20'd0;
      dz2          <= 20'd0;
      sum_tmp      <= 22'd0;
      sqrt_in      <= 32'd0;
      sqrt_res     <= 16'd0;
      pattern_idx  <= 5'd0;
      perm_idx     <= 3'd0;
      current_min  <= 32'hFFFFFFFF;
      current_total<= 32'd0;
      min_distance <= 32'd0;
      done         <= 1'b0;
      x1_r <= 9'd0; y1_r <= 9'd0; z1_r <= 9'd0;
      x2_r <= 9'd0; y2_r <= 9'd0; z2_r <= 9'd0;
      x3_r <= 9'd0; y3_r <= 9'd0; z3_r <= 9'd0;
      x4_r <= 9'd0; y4_r <= 9'd0; z4_r <= 9'd0;
    end else begin
      state <= next_state;
      case (state)
        S_IDLE: begin
          done <= 1'b0;
          if (start) begin
            // Latch inputs at start
            x1_r <= x1; y1_r <= y1; z1_r <= z1;
            x2_r <= x2; y2_r <= y2; z2_r <= z2;
            x3_r <= x3; y3_r <= y3; z3_r <= z3;
            x4_r <= x4; y4_r <= y4; z4_r <= z4;
            current_min <= 32'hFFFFFFFF;
            pattern_idx <= 5'd0;
            perm_idx    <= 3'd0;
          end
        end

        // ----- Pairwise squared distance: 1-2 -----
        S_D12_DX: begin
          dx <= $signed({1'b0,x1_r}) - $signed({1'b0,x2_r});
        end
        S_D12_DY: begin
          dy <= $signed({1'b0,y1_r}) - $signed({1'b0,y2_r});
        end
        S_D12_DZ: begin
          dz <= $signed({1'b0,z1_r}) - $signed({1'b0,z2_r});
        end
        S_D12_SQ: begin
          dx2    <= dx*dx;
          dy2    <= dy*dy;
          dz2    <= dz*dz;
          sum_tmp<= dx2 + dy2 + dz2;
          d12_sq <= {10'd0,sum_tmp};
        end

        // ----- 1-3 -----
        S_D13_DX: dx <= $signed({1'b0,x1_r}) - $signed({1'b0,x3_r});
        S_D13_DY: dy <= $signed({1'b0,y1_r}) - $signed({1'b0,y3_r});
        S_D13_DZ: dz <= $signed({1'b0,z1_r}) - $signed({1'b0,z3_r});
        S_D13_SQ: begin
          dx2    <= dx*dx;
          dy2    <= dy*dy;
          dz2    <= dz*dz;
          sum_tmp<= dx2 + dy2 + dz2;
          d13_sq <= {10'd0,sum_tmp};
        end

        // ----- 1-4 -----
        S_D14_DX: dx <= $signed({1'b0,x1_r}) - $signed({1'b0,x4_r});
        S_D14_DY: dy <= $signed({1'b0,y1_r}) - $signed({1'b0,y4_r});
        S_D14_DZ: dz <= $signed({1'b0,z1_r}) - $signed({1'b0,z4_r});
        S_D14_SQ: begin
          dx2    <= dx*dx;
          dy2    <= dy*dy;
          dz2    <= dz*dz;
          sum_tmp<= dx2 + dy2 + dz2;
          d14_sq <= {10'd0,sum_tmp};
        end

        // ----- 2-3 -----
        S_D23_DX: dx <= $signed({1'b0,x2_r}) - $signed({1'b0,x3_r});
        S_D23_DY: dy <= $signed({1'b0,y2_r}) - $signed({1'b0,y3_r});
        S_D23_DZ: dz <= $signed({1'b0,z2_r}) - $signed({1'b0,z3_r});
        S_D23_SQ: begin
          dx2    <= dx*dx;
          dy2    <= dy*dy;
          dz2    <= dz*dz;
          sum_tmp<= dx2 + dy2 + dz2;
          d23_sq <= {10'd0,sum_tmp};
        end

        // ----- 2-4 -----
        S_D24_DX: dx <= $signed({1'b0,x2_r}) - $signed({1'b0,x4_r});
        S_D24_DY: dy <= $signed({1'b0,y2_r}) - $signed({1'b0,y4_r});
        S_D24_DZ: dz <= $signed({1'b0,z2_r}) - $signed({1'b0,z4_r});
        S_D24_SQ: begin
          dx2    <= dx*dx;
          dy2    <= dy*dy;
          dz2    <= dz*dz;
          sum_tmp<= dx2 + dy2 + dz2;
          d24_sq <= {10'd0,sum_tmp};
        end

        // ----- 3-4 -----
        S_D34_DX: dx <= $signed({1'b0,x3_r}) - $signed({1'b0,x4_r});
        S_D34_DY: dy <= $signed({1'b0,y3_r}) - $signed({1'b0,y4_r});
        S_D34_DZ: dz <= $signed({1'b0,z3_r}) - $signed({1'b0,z4_r});
        S_D34_SQ: begin
          dx2    <= dx*dx;
          dy2    <= dy*dy;
          dz2    <= dz*dz;
          sum_tmp<= dx2 + dy2 + dz2;
          d34_sq <= {10'd0,sum_tmp};
        end

        // Compute sqrt and convert to Q16.16
        S_SQRT_12: begin
          sqrt_in  <= d12_sq;
          sqrt_res <= isqrt16(d12_sq);
          d12_q    <= {sqrt_res,16'd0};
        end
        S_SQRT_13: begin
          sqrt_in  <= d13_sq;
          sqrt_res <= isqrt16(d13_sq);
          d13_q    <= {sqrt_res,16'd0};
        end
        S_SQRT_14: begin
          sqrt_in  <= d14_sq;
          sqrt_res <= isqrt16(d14_sq);
          d14_q    <= {sqrt_res,16'd0};
        end
        S_SQRT_23: begin
          sqrt_in  <= d23_sq;
          sqrt_res <= isqrt16(d23_sq);
          d23_q    <= {sqrt_res,16'd0};
        end
        S_SQRT_24: begin
          sqrt_in  <= d24_sq;
          sqrt_res <= isqrt16(d24_sq);
          d24_q    <= {sqrt_res,16'd0};
        end
        S_SQRT_34: begin
          sqrt_in  <= d34_sq;
          sqrt_res <= isqrt16(d34_sq);
          d34_q    <= {sqrt_res,16'd0};
        end

        S_INIT_EVAL: begin
          current_min <= 32'hFFFFFFFF;
          pattern_idx <= 5'd0;
          perm_idx    <= 3'd0;
        end

        S_EVAL: begin
          // Evaluate one (pattern, permutation) per cycle
          // Decode portal pair
          automatic [3:0] pp;
          automatic [1:0] pa, pb;
          automatic [5:0][1:0] perm_nodes;
          automatic [31:0] cost;
          pp = get_pattern_pair(pattern_idx);
          pa = pp[3:2];
          pb = pp[1:0];
          perm_nodes = get_perm(perm_idx);
          cost = path_cost(2'd0, perm_nodes[0], perm_nodes[1], perm_nodes[2], pa, pb);
          current_total <= cost;
          if (cost < current_min)
            current_min <= cost;

          // Increment permutation and pattern indices
          if (perm_idx == 3'd5) begin
            perm_idx <= 3'd0;
            if (pattern_idx == 5'd5) begin
              pattern_idx <= pattern_idx; // stay; will move to DONE via next_state
            end else begin
              pattern_idx <= pattern_idx + 5'd1;
            end
          end else begin
            perm_idx <= perm_idx + 3'd1;
          end
        end

        S_DONE: begin
          min_distance <= current_min;
          done         <= 1'b1;
        end

        default: ;
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      S_IDLE: begin
        if (start)
          next_state = S_D12_DX;
      end

      S_D12_DX:  next_state = S_D12_DY;
      S_D12_DY:  next_state = S_D12_DZ;
      S_D12_DZ:  next_state = S_D12_SQ;
      S_D12_SQ:  next_state = S_D13_DX;

      S_D13_DX:  next_state = S_D13_DY;
      S_D13_DY:  next_state = S_D13_DZ;
      S_D13_DZ:  next_state = S_D13_SQ;
      S_D13_SQ:  next_state = S_D14_DX;

      S_D14_DX:  next_state = S_D14_DY;
      S_D14_DY:  next_state = S_D14_DZ;
      S_D14_DZ:  next_state = S_D14_SQ;
      S_D14_SQ:  next_state = S_D23_DX;

      S_D23_DX:  next_state = S_D23_DY;
      S_D23_DY:  next_state = S_D23_DZ;
      S_D23_DZ:  next_state = S_D23_SQ;
      S_D23_SQ:  next_state = S_D24_DX;

      S_D24_DX:  next_state = S_D24_DY;
      S_D24_DY:  next_state = S_D24_DZ;
      S_D24_DZ:  next_state = S_D24_SQ;
      S_D24_SQ:  next_state = S_D34_DX;

      S_D34_DX:  next_state = S_D34_DY;
      S_D34_DY:  next_state = S_D34_DZ;
      S_D34_DZ:  next_state = S_D34_SQ;
      S_D34_SQ:  next_state = S_SQRT_12;

      S_SQRT_12: next_state = S_SQRT_13;
      S_SQRT_13: next_state = S_SQRT_14;
      S_SQRT_14: next_state = S_SQRT_23;
      S_SQRT_23: next_state = S_SQRT_24;
      S_SQRT_24: next_state = S_SQRT_34;
      S_SQRT_34: next_state = S_INIT_EVAL;

      S_INIT_EVAL: next_state = S_EVAL;

      S_EVAL: begin
        if (pattern_idx == 5'd5 && perm_idx == 3'd5)
          next_state = S_DONE;
        else
          next_state = S_EVAL;
      end

      S_DONE: begin
        // Stay done until next start deasserted and asserted again
        if (!start)
          next_state = S_IDLE;
        else
          next_state = S_DONE;
      end

      default: next_state = S_IDLE;
    endcase
  end

endmodule