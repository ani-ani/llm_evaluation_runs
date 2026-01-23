module good_nodes_finder(input clk, input rst_n, input start, input [3:0] node_count, input [23:0] edge_data, input [2:0] edge_index, output reg [7:0] good_nodes, output reg done); 
  reg [2:0] state; 
  reg [3:0] expected_edge_idx; 
  reg [7:0] good_nodes_reg; 
  reg done_reg; 
  
  // Edge data extraction 
  wire [3:0] color = edge_data[11:8]; 
  wire [3:0] node_b = edge_data[7:4]; 
  wire [3:0] node_a = edge_data[3:0]; 
  
  // Parameters 
  parameter IDLE = 3'd0; 
  parameter LOAD_EDGES = 3'd1; 
  parameter CHECK_NODES = 3'd2; 
  parameter DONE = 3'd3; 
  
  // Adjacency list storage (simplified for example) 
  reg [3:0] adj_color_storage [8][7]; 
  reg [3:0] adj_node_storage [8][7]; 
  reg [2:0] adj_count [8]; 
  
  always @(posedge clk) begin 
    if (!rst_n) begin 
      state <= IDLE; 
      expected_edge_idx <= 4'd0; 
      good_nodes_reg <= 8'd0; 
      done_reg <= 1'b0; 
      adj_count[0] <= 3'd0; 
      adj_count[1] <= 3'd0; 
      adj_count[2] <= 3'd0; 
      adj_count[3] <= 3'd0; 
      adj_count[4] <= 3'd0; 
      adj_count[5] <= 3'd0; 
      adj_count[6] <= 3'd0; 
      adj_count[7] <= 3'd0; 
    end else begin 
      state <= state; 
      case(state) 
        IDLE: if (start) state <= LOAD_EDGES; 
        LOAD_EDGES: if (edge_index == expected_edge_idx) begin 
          expected_edge_idx <= expected_edge_idx + 1; 
          if (node_a < 8 && node_b < 8) begin 
            adj_count[node_a] <= adj_count[node_a] + 1; 
            adj_color_storage[node_a][adj_count[node_a]-1] <= color; 
            adj_node_storage[node_a][adj_count[node_a]-1] <= node_b; 
            adj_count[node_b] <= adj_count[node_b] + 1; 
            adj_color_storage[node_b][adj_count[node_b]-1] <= color; 
            adj_node_storage[node_b][adj_count[node_b]-1] <= node_a; 
          end 
          if (expected_edge_idx == node_count) state <= CHECK_NODES; 
        end; 
        CHECK_NODES: begin 
          // Simplified check (placeholder) 
          good_nodes_reg <= 8'd0; 
          if (node_count == 1) good_nodes_reg[0] <= 1'b1; 
          state <= DONE; 
        end; 
        DONE: ; 
      endcase 
    end 
  end 
  
  assign good_nodes = good_nodes_reg; 
  assign done = done_reg; 
endmodule