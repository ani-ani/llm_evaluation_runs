module galactic_path_optimizer (
  input clk,
  input rst_n,
  input start,
  input [8:0] x1, y1, z1,
  input [8:0] x2, y2, z2,
  input [8:0] x3, y3, z3,
  input [8:0] x4, y4, z4,
  output reg [31:0] min_distance,
  output reg done
);
  // 4 planets, 6 pairwise edges
  localparam N = 4;
  localparam EDGES = 6;
  // State machine states
  localparam S_IDLE = 3'd0;
  localparam S_COMPUTE_DIST = 3'd1;
  localparam S_TAKE_SQRT = 3'd2;
  localparam S_EVAL = 3'd3;
  localparam S_DONE = 3'd4;
  // Euclidean distances stored as Q16.16 fixed-point (16 int, 16 frac)
  reg [31:0] d [0:EDGES-1];
  reg [31:0] d_sq [0:EDGES-1]; // store squared distances in 32-bit int for sqrt stage
  // Distance and sum accumulators (squared)
  reg [31:0] sum_sq;
  reg [31:0] dx, dy, dz;
  // Indices
  reg [2:0] state, next_state;
  reg [3:0] edge_idx;
  reg [2:0] perm_idx;
  reg [2:0] portal_idx;
  reg busy;
  // Edge mapping helper
  function [3:0] edge_a (input [2:0] k);
    case (k)
      3'd0: edge_a = 4'd0; // 0-1
      3'd1: edge_a = 4'd0; // 0-2
      3'd2: edge_a = 4'd0; // 0-3
      3'd3: edge_a = 4'd1; // 1-2
      3'd4: edge_a = 4'd1; // 1-3
      default: edge_a = 4'd2; // 2-3
    endcase
  endfunction
  function [3:0] edge_b (input [2:0] k);
    case (k)
      3'd0: edge_b = 4'd1;
      3'd1: edge_b = 4'd2;
      3'd2: edge_b = 4'd3;
      3'd3: edge_b = 4'd2;
      3'd4: edge_b = 4'd3;
      default: edge_b = 4'd3;
    endcase
  endfunction
  // Planet coordinate access
  function [8:0] get_x (input [3:0] i);
    case (i)
      4'd0: get_x = x1;
      4'd1: get_x = x2;
      4'd2: get_x = x3;
      default: get_x = x4;
    endcase
  endfunction
  function [8:0] get_y (input [3:0] i);
    case (i)
      4'd0: get_y = y1;
      4'd1: get_y = y2;
      4'd2: get_y = y3;
      default: get_y = y4;
    endcase
  endfunction
  function [8:0] get_z (input [3:0] i);
    case (i)
      4'd0: get_z = z1;
      4'd1: get_z = z2;
      4'd2: get_z = z3;
      default: get_z = z4;
    endcase
  endfunction
  // Q16.16 sqrt: inputs are 32-bit unsigned integer (squared distance), outputs 32-bit Q16.16
  function [31:0] q16_16_sqrt (input [31:0] x_in);
    integer i;
    reg [31:0] temp;
    reg [31:0] root;
    reg [31:0] bitp;
    reg [63:0] remainder;
    reg [63:0] testdiv;
    begin
      if (x_in == 32'd0) begin
        q16_16_sqrt = 32'd0;
      end else begin
        root = 32'd0;
        remainder = {32'd0, x_in};
        bitp = 32'h4000_0000; // highest bit in 32-bit result (scaled to Q16.16)
        for (i = 0; i < 32; i = i + 1) begin
          testdiv = {root, 31'd0} + bitp;
          if (remainder >= testdiv) begin
            remainder = remainder - testdiv;
            root = root + bitp;
          end
          bitp = bitp >> 1;
        end
        // Round to nearest, tie to even
        if (remainder > root) begin
          // remainder > root -> candidate was too small, bump root
          temp = root + 1;
        end else begin
          temp = root;
        end
        // To keep Q format, we shift 16 fractional bits (already handled by initial bitp)
        // but result is already Q16.16 because we built root at 32-bit depth with shifted bits.
        q16_16_sqrt = temp;
      end
    end
  endfunction
  // Distance from squared to fixed-point (Q16.16)
  function [31:0] dist_fp_from_sq (input [31:0] sq);
    reg [31:0] approx;
    begin
      approx = q16_16_sqrt(sq);
      dist_fp_from_sq = approx;
    end
  endfunction
  // Get a fixed-point distance for edge k
  function [31:0] get_dist (input [2:0] k);
    get_dist = d[k];
  endfunction
  // Compute fixed-point distance for edge k (squared to sqrt)
  task compute_dist_for_edge;
    input [2:0] k;
    reg [3:0] ai, bi;
    reg [31:0] tmp_sq;
    begin
      ai = edge_a(k);
      bi = edge_b(k);
      dx = $unsigned($signed(get_x(bi)) - $signed(get_x(ai)));
      dy = $unsigned($signed(get_y(bi)) - $signed(get_y(ai)));
      dz = $unsigned($signed(get_z(bi)) - $signed(get_z(ai)));
      sum_sq = (dx*dx) + (dy*dy) + (dz*dz);
      d_sq[k] = sum_sq;
      d[k] = dist_fp_from_sq(sum_sq);
    end
  endtask
  // Permutation selector: returns planet index in a sequence relative to home(0)
  function [3:0] get_perm_node (input [1:0] j, input [2:0] perm);
    // j in {0,1,2} is position after home; maps to target planet
    case (perm)
      3'd0: begin // 1,2,3
        case (j)
          2'd0: get_perm_node = 4'd1;
          2'd1: get_perm_node = 4'd2;
          default: get_perm_node = 4'd3;
        endcase
      end
      3'd1: begin // 1,3,2
        case (j)
          2'd0: get_perm_node = 4'd1;
          2'd1: get_perm_node = 4'd3;
          default: get_perm_node = 4'd2;
        endcase
      end
      default: begin // 2,1,3
        case (j)
          2'd0: get_perm_node = 4'd2;
          2'd1: get_perm_node = 4'd1;
          default: get_perm_node = 4'd3;
        endcase
      end
    endcase
  endfunction
  // Edge index between two nodes (0..5)
  function [2:0] edge_index_for_nodes (input [3:0] a, input [3:0] b);
    reg [2:0] lo, hi;
    begin
      if (a < b) begin lo = a; hi = b; end else begin lo = b; hi = a; end
      case ({lo,hi})
        {4'd0,4'd1}: edge_index_for_nodes = 3'd0;
        {4'd0,4'd2}: edge_index_for_nodes = 3'd1;
        {4'd0,4'd3}: edge_index_for_nodes = 3'd2;
        {4'd1,4'd2}: edge_index_for_nodes = 3'd3;
        {4'd1,4'd3}: edge_index_for_nodes = 3'd4;
        default: edge_index_for_nodes = 3'd5; // {2,3}
      endcase
    endfunction
  // Compute total tour cost for given perm and portal usage
  task eval_perm_with_portal;
    input [2:0] perm;
    input [2:0] portal; // 0..5 represent free edges; 3'd6 means no portal
    output [31:0] total;
    reg [3:0] seg0_a, seg0_b, seg1_a, seg1_b, seg2_a, seg2_b, seg3_a, seg3_b;
    reg [2:0] e0, e1, e2, e3;
    reg [31:0] t;
    begin
      // path: home(0) -> p0 -> p1 -> p2 -> home(0)
      seg0_a = 4'd0; seg0_b = get_perm_node(2'd0, perm);
      seg1_a = seg0_b; seg1_b = get_perm_node(2'd1, perm);
      seg2_a = seg1_b; seg2_b = get_perm_node(2'd2, perm);
      seg3_a = seg2_b; seg3_b = 4'd0;
      e0 = edge_index_for_nodes(seg0_a, seg0_b);
      e1 = edge_index_for_nodes(seg1_a, seg1_b);
      e2 = edge_index_for_nodes(seg2_a, seg2_b);
      e3 = edge_index_for_nodes(seg3_a, seg3_b);
      t = 0;
      if (e0 == portal) t = t + 0; else t = t + get_dist(e0);
      if (e1 == portal) t = t + 0; else t = t + get_dist(e1);
      if (e2 == portal) t = t + 0; else t = t + get_dist(e2);
      if (e3 == portal) t = t + 0; else t = t + get_dist(e3);
      total = t;
    end
  endtask
  // Sequential logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= S_IDLE;
      busy <= 1'b0;
      done <= 1'b0;
      min_distance <= 32'hFFFF_FFFF;
      edge_idx <= 4'd0;
      perm_idx <= 3'd0;
      portal_idx <= 3'd0;
      sum_sq <= 32'd0;
      dx <= 32'd0; dy <= 32'd0; dz <= 32'd0;
    end else begin
      case (state)
        S_IDLE: begin
          done <= 1'b0;
          min_distance <= 32'hFFFF_FFFF;
          if (start) begin
            state <= S_COMPUTE_DIST;
            edge_idx <= 4'd0;
            perm_idx <= 3'd0;
            portal_idx <= 3'd0;
            busy <= 1'b1;
          end else begin
            busy <= 1'b0;
          end
        end
        S_COMPUTE_DIST: begin
          if (edge_idx < EDGES) begin
            compute_dist_for_edge(edge_idx[2:0]);
            edge_idx <= edge_idx + 1;
            state <= S_TAKE_SQRT;
          end else begin
            state <= S_EVAL;
            perm_idx <= 3'd0;
            portal_idx <= 3'd0;
          end
        end
        S_TAKE_SQRT: begin
          // Nothing extra: d[edge_idx-1] already computed
          state <= (edge_idx < EDGES) ? S_COMPUTE_DIST : S_EVAL;
        end
        S_EVAL: begin
          // Evaluate all 3 permutations with all 7 portal patterns (0..5 + 6(no portal))
          if (perm_idx < 3) begin
            if (portal_idx < 7) begin
              eval_perm_with_portal(perm_idx, portal_idx, sum_sq);
              if (sum_sq < min_distance) begin
                min_distance <= sum_sq;
              end
              portal_idx <= portal_idx + 1;
            end else begin
              perm_idx <= perm_idx + 1;
              portal_idx <= 3'd0;
            end
          end else begin
            state <= S_DONE;
          end
        end
        S_DONE: begin
          done <= 1'b1;
          busy <= 1'b0;
          state <= S_IDLE;
        end
        default: state <= S_IDLE;
      endcase
    end
  end
endmodule
