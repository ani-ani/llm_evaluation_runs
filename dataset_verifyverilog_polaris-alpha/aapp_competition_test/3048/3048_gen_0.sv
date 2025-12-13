module path_counter(
  input  [3:0]   N,
  input  [255:0] adjacency_matrix_flat,
  output [7:0]   count
);

  integer u, v, w;
  reg [7:0] count_reg;
  reg direct_uv;
  reg has_two_hop;

  always @* begin
    count_reg = 8'd0;

    // Iterate over ordered pairs (u, v)
    for (u = 0; u < 16; u = u + 1) begin
      for (v = 0; v < 16; v = v + 1) begin
        if (u < N && v < N && u != v) begin
          // Check no direct edge u->v
          direct_uv = adjacency_matrix_flat[16*u + v];
          if (!direct_uv) begin
            has_two_hop = 1'b0;
            // Search for an intermediate w providing a 2-hop path
            for (w = 0; w < 16; w = w + 1) begin
              if (!has_two_hop && (w < N)) begin
                if (adjacency_matrix_flat[16*u + w] && adjacency_matrix_flat[16*w + v]) begin
                  has_two_hop = 1'b1;
                end
              end
            end
            if (has_two_hop) begin
              count_reg = count_reg + 8'd1;
            end
          end
        end
      end
    end
  end

  assign count = count_reg;

endmodule