module hexagon_coloring (
  input clk,
  input rst_n,
  input start,
  input [7:0] a1_1, a1_2, a1_3,
  input [7:0] a2_1, a2_2,
  input [7:0] a3_1, a3_2, a3_3,
  output reg [15:0] result,
  output reg done
);

  // State definitions
  localparam [2:0] IDLE = 3'b000;
  localparam [2:0] RESET_GRID = 3'b001;
  localparam [2:0] SEARCH_ITERATE = 3'b010;
  localparam [2:0] CHECK_CONSTRAINTS = 3'b011;
  localparam [2:0] UPDATE_COUNT = 3'b100;
  localparam [2:0] DONE = 3'b101;

  reg [2:0] state = IDLE;
  reg [17:0] edge_mask = 0; // 18 edges for n=3
  reg [15:0] count = 0;
  reg [17:0] max_edge_mask = 18'h3FFFF; // 2^18 - 1

  // Hexagon edge mappings (6 edges per hexagon)
  // Each hexagon's edges are represented as bit positions in edge_mask
  // Row 1 (odd): 3 hexagons
  localparam [5:0] hex1_1_edges = 6'b111111; // bits 0-5
  localparam [5:0] hex1_2_edges = 6'b111111; // bits 6-11
  localparam [5:0] hex1_3_edges = 6'b111111; // bits 12-17

  // Row 2 (even): 2 hexagons
  localparam [5:0] hex2_1_edges = 6'b111111; // bits 0-5 (shared with row1)
  localparam [5:0] hex2_2_edges = 6'b111111; // bits 6-11 (shared with row1)

  // Row 3 (odd): 3 hexagons
  localparam [5:0] hex3_1_edges = 6'b111111; // bits 0-5 (shared with row2)
  localparam [5:0] hex3_2_edges = 6'b111111; // bits 6-11 (shared with row2)
  localparam [5:0] hex3_3_edges = 6'b111111; // bits 12-17

  // Vertex constraints: each vertex must have 0 or 2 colored edges
  // For n=3, we have 12 vertices (simplified representation)
  // Each vertex is connected to 2 edges (simplified for this implementation)
  localparam [1:0] vertex_edges [0:11] = '
    '{
      2'b00, // vertex 0: edges 0,1
      2'b01, // vertex 1: edges 1,2
      2'b10, // vertex 2: edges 2,3
      2'b11, // vertex 3: edges 3,4
      2'b00, // vertex 4: edges 4,5
      2'b01, // vertex 5: edges 5,6
      2'b10, // vertex 6: edges 6,7
      2'b11, // vertex 7: edges 7,8
      2'b00, // vertex 8: edges 8,9
      2'b01, // vertex 9: edges 9,10
      2'b10, // vertex 10: edges 10,11
      2'b11  // vertex 11: edges 11,12
    };

  // Helper function to count bits in a 6-bit vector
  function [2:0] count_bits;
    input [5:0] bits;
    begin
      count_bits = 0;
      for (int i = 0; i < 6; i = i + 1) begin
        if (bits[i]) count_bits = count_bits + 1;
      end
    end
  endfunction

  // Helper function to check vertex constraints
  function [0:0] check_vertices;
    input [17:0] edges;
    begin
      for (int v = 0; v < 12; v = v + 1) begin
        reg [1:0] edge_pair = vertex_edges[v];
        reg [1:0] edge_bits = {edges[edge_pair[1]], edges[edge_pair[0]]};
        if (edge_bits != 2'b00 && edge_bits != 2'b11) begin
          check_vertices = 1'b0;
          return;
        end
      end
      check_vertices = 1'b1;
    end
  endfunction

  // Helper function to check hexagon constraints
  function [0:0] check_hexagon_constraints;
    input [17:0] edges;
    input [7:0] a1_1, a1_2, a1_3;
    input [7:0] a2_1, a2_2;
    input [7:0] a3_1, a3_2, a3_3;
    begin
      // Row 1
      if (a1_1[7] == 0) begin // not -1
        if (count_bits(edges[5:0]) != a1_1[2:0]) begin
          check_hexagon_constraints = 1'b0;
          return;
        end
      end
      if (a1_2[7] == 0) begin
        if (count_bits(edges[11:6]) != a1_2[2:0]) begin
          check_hexagon_constraints = 1'b0;
          return;
        end
      end
      if (a1_3[7] == 0) begin
        if (count_bits(edges[17:12]) != a1_3[2:0]) begin
          check_hexagon_constraints = 1'b0;
          return;
        end
      end

      // Row 2
      if (a2_1[7] == 0) begin
        if (count_bits(edges[5:0]) != a2_1[2:0]) begin
          check_hexagon_constraints = 1'b0;
          return;
        end
      end
      if (a2_2[7] == 0) begin
        if (count_bits(edges[11:6]) != a2_2[2:0]) begin
          check_hexagon_constraints = 1'b0;
          return;
        end
      end

      // Row 3
      if (a3_1[7] == 0) begin
        if (count_bits(edges[5:0]) != a3_1[2:0]) begin
          check_hexagon_constraints = 1'b0;
          return;
        end
      end
      if (a3_2[7] == 0) begin
        if (count_bits(edges[11:6]) != a3_2[2:0]) begin
          check_hexagon_constraints = 1'b0;
          return;
        end
      end
      if (a3_3[7] == 0) begin
        if (count_bits(edges[17:12]) != a3_3[2:0]) begin
          check_hexagon_constraints = 1'b0;
          return;
        end
      end

      check_hexagon_constraints = 1'b1;
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      edge_mask <= 0;
      count <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= RESET_GRID;
          end
        end

        RESET_GRID: begin
          edge_mask <= 0;
          count <= 0;
          state <= SEARCH_ITERATE;
        end

        SEARCH_ITERATE: begin
          if (edge_mask == max_edge_mask) begin
            state <= DONE;
          end else begin
            state <= CHECK_CONSTRAINTS;
          end
        end

        CHECK_CONSTRAINTS: begin
          if (check_hexagon_constraints(edge_mask, a1_1, a1_2, a1_3, a2_1, a2_2, a3_1, a3_2, a3_3) &&
              check_vertices(edge_mask)) begin
            state <= UPDATE_COUNT;
          end else begin
            state <= SEARCH_ITERATE;
          end
        end

        UPDATE_COUNT: begin
          count <= count + 1;
          state <= SEARCH_ITERATE;
        end

        DONE: begin
          result <= count;
          done <= 1;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase

      // Increment edge_mask in SEARCH_ITERATE state
      if (state == SEARCH_ITERATE && edge_mask != max_edge_mask) begin
        edge_mask <= edge_mask + 1;
      end
    end
  end

endmodule