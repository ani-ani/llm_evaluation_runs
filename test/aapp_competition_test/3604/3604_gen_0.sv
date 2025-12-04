module sensor_clique_finder(
  input clk, // Clock (unused in combinational implementation)
  input rst_n, // Active-low reset (connect to 1 if unused)
  input [2:0] n, // Number of sensors (3 bits, max 8)
  input [15:0] d, // Max distance (unsigned)
  input [7:0][15:0] x_pos, // Array of 8 x-coordinates (16-bit signed)
  input [7:0][15:0] y_pos, // Array of 8 y-coordinates (16-bit signed)
  output reg [3:0] subset_size, // Size of largest clique (0-8)
  output reg [7:0] subset_mask // Mask of selected sensors (bit 0 = sensor 0)
);

  // Internal signals
  integer i, j;
  reg [31:0] d_sq;
  reg [7:0][7:0] adj; // adj[i][j] = 1 if within distance, symmetric, diagonal 1

  // For subset enumeration
  reg [7:0] mask;
  reg [3:0] curr_size;
  reg is_valid;

  // Combinational clique finder
  always @* begin
    // Precompute d^2
    d_sq = d * d;

    // Build adjacency matrix
    for (i = 0; i < 8; i = i + 1) begin
      for (j = 0; j < 8; j = j + 1) begin
        if (i == j) begin
          adj[i][j] = 1'b1; // A node is always connected to itself
        end else if ((i < n) && (j < n)) begin
          // Compute squared distance between sensor i and j
          // Treat coordinates as signed 16-bit
          // dx, dy: signed 17-bit; products: 32-bit
          reg signed [16:0] dx;
          reg signed [16:0] dy;
          reg [31:0] dx_sq;
          reg [31:0] dy_sq;
          reg [31:0] dist_sq;

          dx = $signed(x_pos[i]) - $signed(x_pos[j]);
          dy = $signed(y_pos[i]) - $signed(y_pos[j]);
          dx_sq = dx * dx;
          dy_sq = dy * dy;
          dist_sq = dx_sq + dy_sq;

          if (dist_sq <= d_sq)
            adj[i][j] = 1'b1;
          else
            adj[i][j] = 1'b0;
        end else begin
          // Indices beyond n-1 are not valid sensors
          adj[i][j] = 1'b0;
        end
      end
    end

    // Initialize best result
    subset_size = 4'd0;
    subset_mask = 8'b0000_0000;

    // Enumerate all possible subsets (0 to 255)
    for (mask = 8'b0000_0000; mask <= 8'b1111_1111; mask = mask + 1'b1) begin
      // Only consider subsets using sensors < n
      // If any bit set at index >= n, skip subset
      reg uses_invalid;
      uses_invalid = 1'b0;
      for (i = 0; i < 8; i = i + 1) begin
        if (mask[i] && (i >= n)) begin
          uses_invalid = 1'b1;
        end
      end
      if (uses_invalid)
        continue;

      // Count number of sensors in subset
      curr_size = 4'd0;
      for (i = 0; i < 8; i = i + 1) begin
        if (mask[i])
          curr_size = curr_size + 4'd1;
      end

      // Early skip if size not better than current best
      if (curr_size <= subset_size)
        continue;

      // Check if subset is a clique
      is_valid = 1'b1;
      for (i = 0; i < 8 && is_valid; i = i + 1) begin
        if (!mask[i])
          continue;
        for (j = i + 1; j < 8 && is_valid; j = j + 1) begin
          if (mask[j]) begin
            if (!adj[i][j]) begin
              is_valid = 1'b0;
            end
          end
        end
      end

      // If valid clique and larger, update best
      if (is_valid) begin
        subset_size = curr_size;
        subset_mask = mask;
      end
    end

    // If n == 0, ensure outputs are zero
    if (n == 3'd0) begin
      subset_size = 4'd0;
      subset_mask = 8'b0000_0000;
    end
  end

endmodule
