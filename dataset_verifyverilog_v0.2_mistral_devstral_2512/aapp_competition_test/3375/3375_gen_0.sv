module count_unicyclic (
  input clk,
  input rst_n,
  input start,
  input [2:0] num_vertices,
  input [2:0] num_edges,
  input [5:0] edge_addr,
  input [2:0] edge_v1,
  input [2:0] edge_v2,
  output reg [31:0] result,
  output reg done,
  output reg busy
);

  // Constants
  localparam MODULUS = 32'h3B9ACA01;
  localparam MAX_VERTICES = 8;
  localparam MAX_EDGES = 28;

  // States
  typedef enum logic [3:0] {
    IDLE,
    LOAD_EDGES,
    PREPARE_ENUM,
    ENUMERATE,
    VERIFY_SUBSET,
    UPDATE_RESULT,
    DONE
  } state_t;

  // State machine
  state_t current_state, next_state;

  // Edge memory (28 edges, each with v1 and v2)
  reg [2:0] edge_mem_v1 [0:MAX_EDGES-1];
  reg [2:0] edge_mem_v2 [0:MAX_EDGES-1];
  reg [5:0] edge_count;

  // Enumeration variables
  reg [5:0] combo_index;
  reg [5:0] combo_count;
  reg [5:0] edge_subset [0:MAX_VERTICES-1];
  reg [7:0] subset_mask [0:MAX_EDGES-1];

  // Connectivity check variables
  reg [7:0] visited;
  reg [2:0] queue [0:MAX_VERTICES-1];
  reg [2:0] queue_head, queue_tail;
  reg [2:0] current_vertex;
  reg [2:0] neighbor;
  reg [2:0] edge_idx;

  // Cycle count variables
  reg [2:0] cycle_count;
  reg [2:0] temp_cycle_count;

  // Temporary variables
  reg [31:0] temp_result;
  reg [5:0] i, j, k;
  reg [2:0] v1, v2;
  reg valid_edge;

  // Initialize outputs
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 0;
      done <= 0;
      busy <= 0;
      current_state <= IDLE;
      edge_count <= 0;
      combo_index <= 0;
      combo_count <= 0;
      queue_head <= 0;
      queue_tail <= 0;
      visited <= 0;
      temp_result <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // State machine logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = LOAD_EDGES;
          busy = 1;
        end
      end

      LOAD_EDGES: begin
        if (edge_addr == edge_count && edge_v1 != 0 && edge_v2 != 0) begin
          edge_mem_v1[edge_count] = edge_v1;
          edge_mem_v2[edge_count] = edge_v2;
          edge_count = edge_count + 1;
        end
        if (edge_count == num_edges) begin
          next_state = PREPARE_ENUM;
        end
      end

      PREPARE_ENUM: begin
        // Calculate total combinations C(num_edges, num_vertices)
        combo_count = 1;
        for (i = 0; i < num_vertices; i = i + 1) begin
          combo_count = combo_count * (num_edges - i) / (i + 1);
        end
        combo_index = 0;
        next_state = ENUMERATE;
      end

      ENUMERATE: begin
        // Generate next combination
        // This is a simplified version - in practice you'd need a proper combination generator
        if (combo_index < combo_count) begin
          // Initialize subset mask
          for (i = 0; i < MAX_EDGES; i = i + 1) begin
            subset_mask[i] = 0;
          end
          // Set the edges in this combination
          for (i = 0; i < num_vertices; i = i + 1) begin
            edge_subset[i] = combo_index % num_edges;
            subset_mask[edge_subset[i]] = 1;
            combo_index = combo_index / num_edges;
          end
          next_state = VERIFY_SUBSET;
        end else begin
          next_state = DONE;
        end
      end

      VERIFY_SUBSET: begin
        // Check connectivity using BFS
        visited = 0;
        queue_head = 0;
        queue_tail = 0;
        queue[queue_tail] = 1; // Start from vertex 1
        queue_tail = queue_tail + 1;
        visited[1] = 1;

        // BFS loop
        while (queue_head < queue_tail) begin
          current_vertex = queue[queue_head];
          queue_head = queue_head + 1;

          // Check all edges in this subset
          for (i = 0; i < num_vertices; i = i + 1) begin
            edge_idx = edge_subset[i];
            v1 = edge_mem_v1[edge_idx];
            v2 = edge_mem_v2[edge_idx];

            if (v1 == current_vertex && !visited[v2]) begin
              queue[queue_tail] = v2;
              queue_tail = queue_tail + 1;
              visited[v2] = 1;
            end
            if (v2 == current_vertex && !visited[v1]) begin
              queue[queue_tail] = v1;
              queue_tail = queue_tail + 1;
              visited[v1] = 1;
            end
          end
        end

        // Check if all vertices are visited
        if (visited == (1 << num_vertices) - 1) begin
          // Check cycle count (edges - vertices + 1)
          cycle_count = num_vertices - num_vertices + 1;
          if (cycle_count == 1) begin
            next_state = UPDATE_RESULT;
          end else begin
            next_state = ENUMERATE;
          end
        end else begin
          next_state = ENUMERATE;
        end
      end

      UPDATE_RESULT: begin
        temp_result = (temp_result + 1) % MODULUS;
        next_state = ENUMERATE;
      end

      DONE: begin
        result = temp_result;
        done = 1;
        busy = 0;
        next_state = IDLE;
      end

      default: next_state = IDLE;
    endcase
  end

endmodule