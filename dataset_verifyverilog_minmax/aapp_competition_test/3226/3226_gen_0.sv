module escape_calculator (
  input [1:0] n,
  input [1:0] e,
  input [3:0][3:0][6:0] roads,
  input [3:0] exits,
  input [1:0] b_start,
  input [1:0] p_start,
  output [31:0] min_speed
);

  // Internal parameterization
  localparam integer NMAX = 4;
  localparam integer BITS = 7;
  localparam integer INF_INT = (1 << (BITS - 1)); // Use 64 as "infinity" for path lengths
  localparam integer QSHIFT = 16;                // Q16.16 fractional bits
  localparam integer POLICE_SPEED_SCALE = 160 << QSHIFT; // 160.0 in Q16.16

  // Pairwise shortest paths (hm), signed to hold -1 for impossible
  integer d [0:NMAX-1][0:NMAX-1];

  // Distances (hm) to exits for both parties
  integer bdist [0:NMAX-1];
  integer pdist [0:NMAX-1];
  integer i_exit [0:NMAX-1];
  integer idx_exit;
  integer j;

  integer k, ii, jj;
  integer tmp;
  integer min_calc;
  logic valid_exit, any_valid;
  logic [31:0] speed_i, min_speed_i;
  logic [31:0] full_num;
  logic [31:0] scaled_bdist;

  // Initialize distances
  always_comb begin
    for (ii = 0; ii < NMAX; ii++) begin
      for (jj = 0; jj < NMAX; jj++) begin
        if (ii == jj) d[ii][jj] = 0;
        else d[ii][jj] = INF_INT;
      end
    end
    // Inject roads within active range (n)
    for (ii = 0; ii < NMAX; ii++) begin
      for (jj = 0; jj < NMAX; jj++) begin
        if (ii < n && jj < n) begin
          if (roads[ii][jj] !== 0) d[ii][jj] = roads[ii][jj];
        end
      end
    end
    // Floyd-Warshall for n <= 4
    for (k = 0; k < NMAX; k++) begin
      for (ii = 0; ii < NMAX; ii++) begin
        for (jj = 0; jj < NMAX; jj++) begin
          if (d[ii][k] < INF_INT && d[k][jj] < INF_INT) begin
            tmp = d[ii][k] + d[k][jj];
            if (tmp < d[ii][jj]) d[ii][jj] = tmp;
          end
        end
      end
    end
  end

  // Collect exits and compute distances to them
  always_comb begin
    // Defaults
    for (idx_exit = 0; idx_exit < NMAX; idx_exit++) i_exit[idx_exit] = -1;
    idx_exit = 0;
    for (j = 0; j < NMAX; j++) begin
      if (exits[j]) begin
        i_exit[idx_exit] = j;
        idx_exit = idx_exit + 1;
      end
    end
    // Distances to each active exit; -1 => impossible
    for (idx_exit = 0; idx_exit < NMAX; idx_exit++) begin
      if (i_exit[idx_exit] >= 0) begin
        bdist[idx_exit] = (d[b_start][i_exit[idx_exit]] < INF_INT) ? d[b_start][i_exit[idx_exit]] : -1;
        pdist[idx_exit] = (d[p_start][i_exit[idx_exit]] < INF_INT) ? d[p_start][i_exit[idx_exit]] : -1;
      end else begin
        bdist[idx_exit] = -1;
        pdist[idx_exit] = -1;
      end
    end
  end

  // Compute minimal required speed (Q16.16)
  always_comb begin
    any_valid = 1'b0;
    min_calc = 32'h7fffffff; // large positive int to start
    speed_i = 32'h00000000;

    for (idx_exit = 0; idx_exit < NMAX; idx_exit++) begin
      valid_exit = (bdist[idx_exit] > 0) && (pdist[idx_exit] > 0);
      if (valid_exit) begin
        // scaled_bdist = bdist << 16 (Q16.16); safe: bdist <= 127, product <= 127*65536 = 8,320,512 < 2^31
        scaled_bdist = {bdist[idx_exit], {QSHIFT{1'b0}}};
        // full numerator: bdist * 160.0 in Q16.16 = bdist * (160 << 16) = scaled_bdist * 160
        full_num = scaled_bdist * 8'd160;
        // ceil(full_num / pdist) in Q16.16, but reported as integer part Q16.16 (frac=0)
        // Equivalent to ((full_num + pdist - 1) / pdist) << 16
        speed_i = ((full_num + pdist - 1) / pdist) << QSHIFT;
        if (!any_valid) begin
          min_calc = $signed(speed_i);
          any_valid = 1'b1;
        end else if ($signed(speed_i) < min_calc) begin
          min_calc = $signed(speed_i);
        end
      end
    end
  end

  // Output selection: 0xFFFFFFFF if no valid exit, else minimal speed
  assign min_speed = any_valid ? 32'(min_calc) : 32'hffffffff;

endmodule
