module escape_calculator(
  input  [1:0] n,          // number of nodes (2-4) (unused for logic limit, but kept for interface)
  input  [1:0] e,          // num exits (1-4) (unused for logic limit, but kept for interface)
  input  [3:0][3:0][6:0] roads, // adjacency matrix: 7-bit length (hm), 0 = no road
  input  [3:0] exits,      // bitmask of exit nodes
  input  [1:0] b_start,    // brothers' start node
  input  [1:0] p_start,    // police start node
  output [31:0] min_speed  // Q16.16 (0xFFFF_FFFF = impossible)
);

  // Constants
  localparam [15:0] SCALE_160 = 16'd160;  // numerator factor for speed: 160.0
  localparam [31:0] IMPOSSIBLE = 32'hFFFF_FFFF;

  // Internal wires for per-node best distance from brothers and police
  // We implement a small combinational Dijkstra for 4 nodes, using roads as 7-bit (max 127) weights.

  // Extract road weights: w[i][j]
  wire [6:0] w[3:0][3:0];
  genvar gi, gj;
  generate
    for (gi = 0; gi < 4; gi = gi + 1) begin : GEN_W_I
      for (gj = 0; gj < 4; gj = gj + 1) begin : GEN_W_J
        assign w[gi][gj] = roads[gi][gj];
      end
    end
  endgenerate

  // Large value representing INF for 7-bit edge sums (max path < 4*127=508)
  localparam [9:0] INF10 = 10'd1023;

  // ----------------------
  // Shortest paths for Brothers (b_dist[0..3])
  // ----------------------

  // Initial distances (dist0)
  wire [9:0] b_d0_0 = (b_start == 2'd0) ? 10'd0 : INF10;
  wire [9:0] b_d0_1 = (b_start == 2'd1) ? 10'd0 : INF10;
  wire [9:0] b_d0_2 = (b_start == 2'd2) ? 10'd0 : INF10;
  wire [9:0] b_d0_3 = (b_start == 2'd3) ? 10'd0 : INF10;

  // Step 1: relax via each single edge from known start
  function automatic [9:0] add_w10;
    input [9:0] a;
    input [6:0] b;
    begin
      add_w10 = (a == INF10) ? INF10 : (a + b);
    end
  endfunction

  // Relax from each possible start to neighbors
  wire [9:0] b_s1_0 = b_d0_0; // if start is 0 already 0, else INF
  wire [9:0] b_s1_1 = b_d0_1;
  wire [9:0] b_s1_2 = b_d0_2;
  wire [9:0] b_s1_3 = b_d0_3;

  // Allow one relaxation step from the actual start node to others
  // We compute candidate via each possible start index, but only the actual start is 0.
  wire [9:0] b_c1_0 = (b_start == 2'd1) ? add_w10(10'd0, w[1][0]) :
                     (b_start == 2'd2) ? add_w10(10'd0, w[2][0]) :
                     (b_start == 2'd3) ? add_w10(10'd0, w[3][0]) : b_s1_0;
  wire [9:0] b_c1_1 = (b_start == 2'd0) ? add_w10(10'd0, w[0][1]) :
                     (b_start == 2'd2) ? add_w10(10'd0, w[2][1]) :
                     (b_start == 2'd3) ? add_w10(10'd0, w[3][1]) : b_s1_1;
  wire [9:0] b_c1_2 = (b_start == 2'd0) ? add_w10(10'd0, w[0][2]) :
                     (b_start == 2'd1) ? add_w10(10'd0, w[1][2]) :
                     (b_start == 2'd3) ? add_w10(10'd0, w[3][2]) : b_s1_2;
  wire [9:0] b_c1_3 = (b_start == 2'd0) ? add_w10(10'd0, w[0][3]) :
                     (b_start == 2'd1) ? add_w10(10'd0, w[1][3]) :
                     (b_start == 2'd2) ? add_w10(10'd0, w[2][3]) : b_s1_3;

  // First relaxed distances (take min between keep and new via one hop)
  function automatic [9:0] min10;
    input [9:0] a, b;
    begin
      min10 = (a <= b) ? a : b;
    end
  endfunction

  wire [9:0] b_d1_0 = min10(b_s1_0, b_c1_0);
  wire [9:0] b_d1_1 = min10(b_s1_1, b_c1_1);
  wire [9:0] b_d1_2 = min10(b_s1_2, b_c1_2);
  wire [9:0] b_d1_3 = min10(b_s1_3, b_c1_3);

  // Step 2 and 3: fully unrolled multi-source relaxations for 4 nodes
  // We iteratively relax through every intermediate node (Floyd-Warshall style) combinationally.

  function automatic [9:0] relax2;
    input [9:0] d_i;
    input [9:0] d_k;
    input [6:0] w_k_i;
    reg   [9:0] via;
    begin
      via = add_w10(d_k, w_k_i);
      relax2 = min10(d_i, via);
    end
  endfunction

  // k = 0
  wire [9:0] b_k0_0 = b_d1_0;
  wire [9:0] b_k0_1 = relax2(b_d1_1, b_d1_0, w[0][1]);
  wire [9:0] b_k0_2 = relax2(b_d1_2, b_d1_0, w[0][2]);
  wire [9:0] b_k0_3 = relax2(b_d1_3, b_d1_0, w[0][3]);

  // k = 1
  wire [9:0] b_k1_0 = relax2(b_k0_0, b_k0_1, w[1][0]);
  wire [9:0] b_k1_1 = b_k0_1;
  wire [9:0] b_k1_2 = relax2(b_k0_2, b_k0_1, w[1][2]);
  wire [9:0] b_k1_3 = relax2(b_k0_3, b_k0_1, w[1][3]);

  // k = 2
  wire [9:0] b_k2_0 = relax2(b_k1_0, b_k1_2, w[2][0]);
  wire [9:0] b_k2_1 = relax2(b_k1_1, b_k1_2, w[2][1]);
  wire [9:0] b_k2_2 = b_k1_2;
  wire [9:0] b_k2_3 = relax2(b_k1_3, b_k1_2, w[2][3]);

  // k = 3
  wire [9:0] b_k3_0 = relax2(b_k2_0, b_k2_3, w[3][0]);
  wire [9:0] b_k3_1 = relax2(b_k2_1, b_k2_3, w[3][1]);
  wire [9:0] b_k3_2 = relax2(b_k2_2, b_k2_3, w[3][2]);
  wire [9:0] b_k3_3 = b_k2_3;

  // Final brothers distances
  wire [9:0] b_dist0 = b_k3_0;
  wire [9:0] b_dist1 = b_k3_1;
  wire [9:0] b_dist2 = b_k3_2;
  wire [9:0] b_dist3 = b_k3_3;

  // ----------------------
  // Shortest paths for Police (p_dist[0..3]) (same structure)
  // ----------------------

  wire [9:0] p_d0_0 = (p_start == 2'd0) ? 10'd0 : INF10;
  wire [9:0] p_d0_1 = (p_start == 2'd1) ? 10'd0 : INF10;
  wire [9:0] p_d0_2 = (p_start == 2'd2) ? 10'd0 : INF10;
  wire [9:0] p_d0_3 = (p_start == 2'd3) ? 10'd0 : INF10;

  wire [9:0] p_s1_0 = p_d0_0;
  wire [9:0] p_s1_1 = p_d0_1;
  wire [9:0] p_s1_2 = p_d0_2;
  wire [9:0] p_s1_3 = p_d0_3;

  wire [9:0] p_c1_0 = (p_start == 2'd1) ? add_w10(10'd0, w[1][0]) :
                     (p_start == 2'd2) ? add_w10(10'd0, w[2][0]) :
                     (p_start == 2'd3) ? add_w10(10'd0, w[3][0]) : p_s1_0;
  wire [9:0] p_c1_1 = (p_start == 2'd0) ? add_w10(10'd0, w[0][1]) :
                     (p_start == 2'd2) ? add_w10(10'd0, w[2][1]) :
                     (p_start == 2'd3) ? add_w10(10'd0, w[3][1]) : p_s1_1;
  wire [9:0] p_c1_2 = (p_start == 2'd0) ? add_w10(10'd0, w[0][2]) :
                     (p_start == 2'd1) ? add_w10(10'd0, w[1][2]) :
                     (p_start == 2'd3) ? add_w10(10'd0, w[3][2]) : p_s1_2;
  wire [9:0] p_c1_3 = (p_start == 2'd0) ? add_w10(10'd0, w[0][3]) :
                     (p_start == 2'd1) ? add_w10(10'd0, w[1][3]) :
                     (p_start == 2'd2) ? add_w10(10'd0, w[2][3]) : p_s1_3;

  wire [9:0] p_d1_0 = min10(p_s1_0, p_c1_0);
  wire [9:0] p_d1_1 = min10(p_s1_1, p_c1_1);
  wire [9:0] p_d1_2 = min10(p_s1_2, p_c1_2);
  wire [9:0] p_d1_3 = min10(p_s1_3, p_c1_3);

  // k = 0
  wire [9:0] p_k0_0 = p_d1_0;
  wire [9:0] p_k0_1 = relax2(p_d1_1, p_d1_0, w[0][1]);
  wire [9:0] p_k0_2 = relax2(p_d1_2, p_d1_0, w[0][2]);
  wire [9:0] p_k0_3 = relax2(p_d1_3, p_d1_0, w[0][3]);

  // k = 1
  wire [9:0] p_k1_0 = relax2(p_k0_0, p_k0_1, w[1][0]);
  wire [9:0] p_k1_1 = p_k0_1;
  wire [9:0] p_k1_2 = relax2(p_k0_2, p_k0_1, w[1][2]);
  wire [9:0] p_k1_3 = relax2(p_k0_3, p_k0_1, w[1][3]);

  // k = 2
  wire [9:0] p_k2_0 = relax2(p_k1_0, p_k1_2, w[2][0]);
  wire [9:0] p_k2_1 = relax2(p_k1_1, p_k1_2, w[2][1]);
  wire [9:0] p_k2_2 = p_k1_2;
  wire [9:0] p_k2_3 = relax2(p_k1_3, p_k1_2, w[2][3]);

  // k = 3
  wire [9:0] p_k3_0 = relax2(p_k2_0, p_k2_3, w[3][0]);
  wire [9:0] p_k3_1 = relax2(p_k2_1, p_k2_3, w[3][1]);
  wire [9:0] p_k3_2 = relax2(p_k2_2, p_k2_3, w[3][2]);
  wire [9:0] p_k3_3 = p_k2_3;

  // Final police distances
  wire [9:0] p_dist0 = p_k3_0;
  wire [9:0] p_dist1 = p_k3_1;
  wire [9:0] p_dist2 = p_k3_2;
  wire [9:0] p_dist3 = p_k3_3;

  // ----------------------
  // Compute required speed per exit
  // speed_req = ceil((b_dist * 160.0) / p_dist) in Q16.16
  // Implemented as: (b_dist * 160 * 2^16 + p_dist - 1) / p_dist
  // If either distance is INF or zero/invalid, that exit is ignored.
  // If no valid exit -> IMPOSSIBLE
  // ----------------------

  function automatic [31:0] req_speed_one;
    input [9:0] b_d;
    input [9:0] p_d;
    input       is_exit;
    reg   [31:0] num;
    reg   [31:0] div;
    begin
      if (!is_exit) begin
        req_speed_one = IMPOSSIBLE;
      end else if (b_d == INF10 || p_d == INF10 || p_d == 10'd0 || b_d == 10'd0) begin
        // Invalid if either unreachable or zero distance (no positive time)
        req_speed_one = IMPOSSIBLE;
      end else begin
        // num = b_d * 160 * 2^16
        num = (b_d * SCALE_160) << 16;
        // ceil division by p_d
        div = (num + p_d - 1) / p_d;
        req_speed_one = div;
      end
    end
  endfunction

  wire [31:0] s0 = req_speed_one(b_dist0, p_dist0, exits[0]);
  wire [31:0] s1 = req_speed_one(b_dist1, p_dist1, exits[1]);
  wire [31:0] s2 = req_speed_one(b_dist2, p_dist2, exits[2]);
  wire [31:0] s3 = req_speed_one(b_dist3, p_dist3, exits[3]);

  // Take minimum over valid speeds; if all IMPOSSIBLE -> IMPOSSIBLE
  function automatic [31:0] min32_valid;
    input [31:0] a, b;
    reg   [31:0] r;
    begin
      if (a == IMPOSSIBLE) r = b;
      else if (b == IMPOSSIBLE) r = a;
      else r = (a <= b) ? a : b;
      min32_valid = r;
    end
  endfunction

  wire [31:0] m0 = min32_valid(s0, s1);
  wire [31:0] m1 = min32_valid(s2, s3);
  wire [31:0] m2 = min32_valid(m0, m1);

  assign min_speed = (m2 == IMPOSSIBLE) ? IMPOSSIBLE : m2;

endmodule