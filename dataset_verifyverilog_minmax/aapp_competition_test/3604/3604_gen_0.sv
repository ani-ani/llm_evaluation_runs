module sensor_clique_finder(
  input clk, // Clock (unused in combinational implementation)
  input rst_n, // Active-low reset (connect to 1 if unused)
  input [2:0] n, // Number of sensors (3 bits, max 8)
  input [15:0] d, // Max distance (unsigned)
  input [7:0][15:0] x_pos, // Array of 8 x-coordinates (16-bit signed)
  input [7:0][15:0] y_pos, // Array of 8 y-coordinates (16-bit signed)
  output reg [3:0] subset_size, // Size of largest clique (0-8)
  output reg [7:0] subset_mask // One-hot mask of selected sensors (bit 0 = sensor 1)
);

// Precompute squared distance for input d
wire [31:0] d_sq = d * d;

// Precompute adjacency matrix
reg [7:0][7:0] adj;
integer i, j;
always @(*) begin
  for (i = 0; i < 8; i = i + 1) begin
    for (j = i + 1; j < 8; j = j + 1) begin
      reg [31:0] dx = $signed(x_pos[i]) - $signed(x_pos[j]);
      reg [31:0] dy = $signed(y_pos[i]) - $signed(y_pos[j]);
      reg [31:0] dist_sq = dx*dx + dy*dy;
      adj[i][j] = (dist_sq <= d_sq) ? 1 : 0;
      adj[j][i] = adj[i][j];
    end
    adj[i][i] = 1;
  end
end

// Precompute mask for first n sensors
wire [7:0] mask_n = (1 << n) - 1;

// Main loop to find largest clique
reg [3:0] best_size = 0;
reg [7:0] best_mask = 0;
integer s;
always @(*) begin
  best_size = 0;
  best_mask = 0;
  for (s = 0; s < 256; s = s + 1) begin
    if ((s & ~mask_n) != 0) continue; // Exclude sensors beyond n
    
    reg cond = 1;
    for (i = 0; i < 7; i = i + 1) begin
      for (j = i + 1; j < 8; j = j + 1) begin
        if (s[i] && s[j]) begin
          cond = cond & adj[i][j];
        end
      end
    end
    
    if (cond) begin
      reg [3:0] pop = $countones(s);
      if (pop > best_size) begin
        best_size = pop;
        best_mask = s[7:0];
      end
    end
  end
end

assign subset_size = best_size;
assign subset_mask = best_mask;

endmodule