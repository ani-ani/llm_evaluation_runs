module largest_committee (
  input clk,
  input rst_n,
  input start,
  input [5:0] N,
  input [3:0] K,
  input [5:0] current_vertex,
  input [4:0] num_neighbors,
  input [5:0] neighbor_addr,
  input neighbor_valid,
  input [5:0] neighbor_id,
  output reg [5:0] max_clique_size,
  output reg done,
  output reg busy
);

  // Parameters
  localparam IDLE = 3'b000;
  localparam LOAD_GRAPH = 3'b001;
  localparam BUILD_CLIQUE = 3'b010;
  localparam BACKTRACK = 3'b011;
  localparam UPDATE_MAX = 3'b100;
  localparam DONE = 3'b101;

  // State register
  reg [2:0] state, next_state;

  // Adjacency matrix (50x50 bits)
  reg [49:0] adjacency_matrix [0:49];

  // Stack for backtracking (depth <= K)
  reg [5:0] stack [0:9];
  reg [4:0] stack_ptr;

  // Current clique state
  reg [5:0] current_clique [0:9];
  reg [4:0] clique_size;
  reg [5:0] current_max;

  // Graph loading state
  reg [5:0] load_vertex;
  reg [4:0] load_neighbor_count;
  reg [5:0] load_neighbor_index;

  // Algorithm state
  reg [5:0] candidate_vertex;
  reg [5:0] candidate_index;
  reg [5:0] start_vertex;

  // Initialize registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      max_clique_size <= 0;
      done <= 0;
      busy <= 0;
      stack_ptr <= 0;
      clique_size <= 0;
      current_max <= 0;
      load_vertex <= 0;
      load_neighbor_count <= 0;
      load_neighbor_index <= 0;
      candidate_vertex <= 0;
      candidate_index <= 0;
      start_vertex <= 0;
      for (int i = 0; i < 50; i = i + 1) begin
        adjacency_matrix[i] <= 0;
      end
      for (int i = 0; i < 10; i = i + 1) begin
        stack[i] <= 0;
        current_clique[i] <= 0;
      end
    end else begin
      state <= next_state;
    end
  end

  // State machine logic
  always @(*) begin
    next_state = state;
    busy = (state != IDLE && state != DONE);
    done = (state == DONE);

    case (state)
      IDLE: begin
        if (start) begin
          next_state = LOAD_GRAPH;
          load_vertex = 0;
          load_neighbor_count = 0;
          load_neighbor_index = 0;
          current_max = 0;
        end
      end

      LOAD_GRAPH: begin
        if (current_vertex == load_vertex) begin
          if (neighbor_valid) begin
            adjacency_matrix[load_vertex][neighbor_id] = 1;
            adjacency_matrix[neighbor_id][load_vertex] = 1;
            load_neighbor_index = load_neighbor_index + 1;
          end
          if (load_neighbor_index == num_neighbors) begin
            load_vertex = load_vertex + 1;
            load_neighbor_index = 0;
          end
        end
        if (load_vertex == N) begin
          next_state = BUILD_CLIQUE;
          start_vertex = 0;
          stack_ptr = 0;
          clique_size = 0;
        end
      end

      BUILD_CLIQUE: begin
        if (stack_ptr == 0) begin
          // Start new clique with start_vertex
          current_clique[0] = start_vertex;
          stack[stack_ptr] = start_vertex;
          stack_ptr = stack_ptr + 1;
          clique_size = 1;
          candidate_index = 0;
        end

        // Find next candidate vertex
        if (candidate_index < N) begin
          candidate_vertex = candidate_index;
          // Check if candidate is adjacent to all in current clique
          reg is_candidate = 1;
          for (int i = 0; i < clique_size; i = i + 1) begin
            if (!adjacency_matrix[current_clique[i]][candidate_vertex]) begin
              is_candidate = 0;
            end
          end

          if (is_candidate && candidate_vertex > stack[stack_ptr-1]) begin
            // Add to clique
            current_clique[clique_size] = candidate_vertex;
            stack[stack_ptr] = candidate_vertex;
            stack_ptr = stack_ptr + 1;
            clique_size = clique_size + 1;
            candidate_index = 0;
            next_state = BUILD_CLIQUE;
          end else begin
            candidate_index = candidate_index + 1;
          end
        end else begin
          // No more candidates, backtrack
          next_state = BACKTRACK;
        end
      end

      BACKTRACK: begin
        if (clique_size > current_max) begin
          current_max = clique_size;
          next_state = UPDATE_MAX;
        end else begin
          // Pop from stack
          if (stack_ptr > 0) begin
            stack_ptr = stack_ptr - 1;
            clique_size = clique_size - 1;
            candidate_index = stack[stack_ptr] + 1;
            next_state = BUILD_CLIQUE;
          end else begin
            // Move to next start vertex
            start_vertex = start_vertex + 1;
            if (start_vertex < N) begin
              next_state = BUILD_CLIQUE;
            end else begin
              next_state = DONE;
              max_clique_size = current_max;
            end
          end
        end
      end

      UPDATE_MAX: begin
        next_state = BACKTRACK;
      end

      DONE: begin
        if (start) begin
          next_state = LOAD_GRAPH;
          done = 0;
        end
      end

      default: next_state = IDLE;
    endcase
  end

endmodule