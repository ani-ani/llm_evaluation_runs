module optimal_paths_length2 (
  input [15:0] adj_matrix [0:15],
  input [3:0] num_nodes,
  output reg [15:0] result
);

  integer i, j;
  reg [15:0] degree;
  reg [15:0] temp_sum;

  always @* begin
    temp_sum = 16'b0;
    for (i = 0; i < num_nodes; i = i + 1) begin
      degree = 16'b0;
      for (j = 0; j < num_nodes; j = j + 1) begin
        degree = degree + adj_matrix[i][j];
      end
      temp_sum = temp_sum + (degree * (degree - 1));
    end
    result = temp_sum;
  end

endmodule