module sensor_clique_finder(
  input clk,
  input rst_n,
  input [2:0] n,
  input [15:0] d,
  input [7:0][15:0] x_pos,
  input [7:0][15:0] y_pos,
  output reg [3:0] subset_size,
  output reg [7:0] subset_mask
);

  wire [7:0][7:0] adj_matrix;

  genvar i, j;
  generate
    for (i = 0; i < 8; i = i + 1) begin : gen_row
      for (j = 0; j < 8; j = j + 1) begin : gen_col
        wire signed [15:0] dx = x_pos[i] - x_pos[j];
        wire signed [15:0] dy = y_pos[i] - y_pos[j];
        wire [31:0] dx_sq = dx * dx;
        wire [31:0] dy_sq = dy * dy;
        wire [31:0] dist_sq = dx_sq + dy_sq;
        wire [31:0] d_sq = d * d;
        assign adj_matrix[i][j] = (dist_sq <= d_sq);
      end
    end
  endgenerate

  always_comb begin
    automatic reg [3:0] best_size = 0;
    automatic reg [7:0] best_mask = 0;

    for (int m = 0; m < 256; m++) begin
      automatic reg [7:0] mask = m;
      automatic reg [7:0] vmask = (8'b1 << n) - 1;
      automatic reg invalid = |(mask & ~vmask);
      automatic reg [3:0] size = $countones(mask);
      automatic reg valid_clique = 1'b1;

      if (!invalid) begin
        for (int i = 0; i < 8; i++) begin
          for (int j = i+1; j < 8; j++) begin
            if (mask[i] && mask[j])
              valid_clique = valid_clique && adj_matrix[i][j];
          end
        end

        if (valid_clique) begin
          if ((size > best_size) || ((size == best_size) && (mask < best_mask))) begin
            best_size = size;
            best_mask = mask;
          end
        end
      end
    end

    subset_size = best_size;
    subset_mask = best_mask;
  end

endmodule