module max_kahn_sources (
  input clk,
  input rst_n,
  input start,
  input [2:0] node_count,
  input [2:0] src_node,
  input [2:0] dst_node,
  input edge_valid,
  input edge_complete,
  output reg [2:0] max_sources,
  output reg done
);

  // Parameters
  localparam IDLE = 2'b00;
  localparam COMPUTING = 2'b01;
  localparam DONE = 2'b10;

  // State registers
  reg [1:0] state;
  reg [2:0] current_max;
  reg [2:0] nodes_remaining;
  reg [7:0] in_degree [0:7];
  reg [7:0] adj_matrix [0:7];
  reg [2:0] current_layer_size;
  reg [2:0] next_layer_size;
  reg [7:0] current_layer;
  reg [7:0] next_layer;
  reg [2:0] node_idx;
  reg [2:0] neighbor_idx;
  reg [2:0] edge_count;
  reg [2:0] max_layer_size;

  // Initialize state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_max <= 0;
      nodes_remaining <= 0;
      for (int i = 0; i < 8; i = i + 1) begin
        in_degree[i] <= 0;
        adj_matrix[i] <= 0;
      end
      current_layer_size <= 0;
      next_layer_size <= 0;
      current_layer <= 0;
      next_layer <= 0;
      node_idx <= 0;
      neighbor_idx <= 0;
      edge_count <= 0;
      max_layer_size <= 0;
      max_sources <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= COMPUTING;
            nodes_remaining <= node_count;
            edge_count <= 0;
            max_layer_size <= 0;
          end
        end
        COMPUTING: begin
          if (edge_complete) begin
            // Initialize in-degrees and adjacency matrix
            for (int i = 0; i < 8; i = i + 1) begin
              in_degree[i] <= 0;
              adj_matrix[i] <= 0;
            end
            state <= COMPUTING;
          end else if (edge_valid) begin
            // Store edge in adjacency matrix
            adj_matrix[src_node] <= adj_matrix[src_node] | (1 << dst_node);
            in_degree[dst_node] <= in_degree[dst_node] + 1;
            edge_count <= edge_count + 1;
          end
          // After all edges are stored, start computation
          if (edge_complete && edge_count == (node_count * (node_count - 1) / 2)) begin
            // Initialize current layer with nodes having zero in-degree
            current_layer <= 0;
            for (int i = 0; i < 8; i = i + 1) begin
              if (i < node_count && in_degree[i] == 0) begin
                current_layer <= current_layer | (1 << i);
              end
            end
            current_layer_size <= $clog2(current_layer) + 1;
            max_layer_size <= current_layer_size;
            state <= COMPUTING;
          end
          // Process current layer
          if (current_layer_size > 0) begin
            next_layer <= 0;
            next_layer_size <= 0;
            for (int i = 0; i < 8; i = i + 1) begin
              if (current_layer[i]) begin
                for (int j = 0; j < 8; j = j + 1) begin
                  if (adj_matrix[i][j]) begin
                    in_degree[j] <= in_degree[j] - 1;
                    if (in_degree[j] == 0) begin
                      next_layer <= next_layer | (1 << j);
                    end
                  end
                end
              end
            end
            next_layer_size <= $clog2(next_layer) + 1;
            if (next_layer_size > max_layer_size) begin
              max_layer_size <= next_layer_size;
            end
            current_layer <= next_layer;
            current_layer_size <= next_layer_size;
            nodes_remaining <= nodes_remaining - current_layer_size;
            if (nodes_remaining == 0) begin
              state <= DONE;
              max_sources <= max_layer_size;
              done <= 1;
            end
          end
        end
        DONE: begin
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule