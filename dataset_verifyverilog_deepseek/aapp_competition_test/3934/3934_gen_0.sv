module tree_edge_operation_check(
  input [2:0] node_id [7:0],
  input [7:0] adj_matrix [7:0],
  output reg result
);
  
  wire [2:0] degrees [0:7];
  wire [7:0] failure;
  
  genvar i;
  generate
    for (i = 0; i < 8; i = i + 1) begin : calc_degree
      assign degrees[i] = (
        adj_matrix[i][0] + adj_matrix[i][1] + adj_matrix[i][2] + adj_matrix[i][3] +
        adj_matrix[i][4] + adj_matrix[i][5] + adj_matrix[i][6] + adj_matrix[i][7]
      );
      assign failure[i] = (degrees[i] == 3'd2);
    end
  endgenerate
  
  wire any_failure = |failure;
  
  always @(*) begin
    result = ~any_failure;
  end

endmodule