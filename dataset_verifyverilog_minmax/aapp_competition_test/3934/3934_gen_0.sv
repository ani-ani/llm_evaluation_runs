module tree_edge_operation_check(
  input [2:0] node_id [7:0], // Not used in this design
  input [7:0] adj_matrix [7:0],
  output reg result
);
  
  // Internal signals
  reg [7:0] failure;
  integer i;
  
  always @(*) begin
    // Initialize failure flags
    failure = 0;
    
    // For each node, calculate degree and check for degree-2
    for (i = 0; i < 8; i++) begin
      // Calculate degree using parallel adders
      reg [1:0] p0, p1, p2, p3;
      reg [2:0] p01, p23;
      reg [3:0] sum;
      
      // Parallel counting of ones in each 2-bit group
      p0 = adj_matrix[i][0] + adj_matrix[i][1];
      p1 = adj_matrix[i][2] + adj_matrix[i][3];
      p2 = adj_matrix[i][4] + adj_matrix[i][5];
      p3 = adj_matrix[i][6] + adj_matrix[i][7];
      
      // Combine 2-bit groups to get 3-bit partial sums
      p01 = {1'b0, p0} + {1'b0, p1};
      p23 = {1'b0, p2} + {1'b0, p3};
      
      // Final addition to get degree (0-7, 3 bits)
      sum = {1'b0, p01} + {1'b0, p23};
      
      // Check if degree equals 2
      if (sum[2:0] == 3'b010) begin
        failure[i] = 1;
      end
    end
    
    // OR all failure flags to generate result
    // 1 = YES (no degree-2 nodes), 0 = NO (has degree-2 node)
    result = ~(|failure);
  end
  
endmodule