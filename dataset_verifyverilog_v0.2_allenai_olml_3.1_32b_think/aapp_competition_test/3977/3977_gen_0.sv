module stable_graph_max_edges(input [7:0] gov_mask, input [7:0][7:0] adj_matrix, output reg [15:0] max_edges);
assign existing_edges = adj_matrix[0][1] + adj_matrix[0][2] + adj_matrix[0][3] + adj_matrix[0][4] + adj_matrix[0][5] + adj_matrix[0][6] + adj_matrix[0][7] + adj_matrix[1][2] + adj_matrix[1][3] + adj_matrix[1][4] + adj_matrix[1][5] + adj_matrix[1][6] + adj_matrix[1][7] + adj_matrix[2][3] + adj_matrix[2][4] + adj_matrix[2][5] + adj_matrix[2][6] + adj_matrix[2][7] + adj_matrix[3][4] + adj_matrix[3][5] + adj_matrix[3][6] + adj_matrix[3][7] + adj_matrix[4][5] + adj_matrix[4][6] + adj_matrix[4][7] + adj_matrix[5][6] + adj_matrix[5][7] + adj_matrix[6][7];
localparam max_total_edges = 8*7/2;
assign max_edges = max_total_edges - existing_edges;
endmodule