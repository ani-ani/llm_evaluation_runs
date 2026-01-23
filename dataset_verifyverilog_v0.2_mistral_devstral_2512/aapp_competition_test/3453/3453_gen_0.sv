module danger_level_calculator (
  input clk,
  input rst_n,
  input start,
  input [2:0] node_idx,
  input [2:0] neighbor_idx,
  input [7:0] edge_weight,
  input edge_valid,
  output reg [2:0] current_node,
  output reg [31:0] danger_level,
  output reg result_valid,
  output reg done
);

  // Constants
  localparam IDLE = 3'b000;
  localparam LOAD_GRAPH = 3'b001;
  localparam COMPUTE_SHORTEST_PATHS = 3'b010;
  localparam CALCULATE_SUMS = 3'b011;
  localparam OUTPUT_RESULTS = 3'b100;
  localparam DONE = 3'b101;
  
  localparam MOD = 32'd1000000007;
  localparam INF = 32'd1000000000;
  localparam NUM_NODES = 8;

  // State machine
  reg [2:0] state = IDLE;
  reg [2:0] next_state = IDLE;

  // Graph storage (8x8 adjacency matrix)
  reg [31:0] graph [0:NUM_NODES-1][0:NUM_NODES-1];
  integer i, j, k;

  // Distance matrix
  reg [31:0] dist [0:NUM_NODES-1][0:NUM_NODES-1];

  // Danger level sums
  reg [31:0] danger_sums [0:NUM_NODES-1];

  // Counters
  reg [2:0] load_counter = 0;
  reg [5:0] compute_counter = 0;
  reg [2:0] output_counter = 0;

  // Edge loading
  reg [2:0] expected_node = 0;
  reg [2:0] expected_neighbor = 0;

  // Output control
  reg [2:0] output_node = 0;

  // Initialize graph with INF (no edges)
  initial begin
    for (i = 0; i < NUM_NODES; i = i + 1) begin
      for (j = 0; j < NUM_NODES; j = j + 1) begin
        graph[i][j] = INF;
      end
    end
  end

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      load_counter <= 0;
      compute_counter <= 0;
      output_counter <= 0;
      expected_node <= 0;
      expected_neighbor <= 0;
      output_node <= 0;
      current_node <= 0;
      danger_level <= 0;
      result_valid <= 0;
      done <= 0;
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = LOAD_GRAPH;
      end
      LOAD_GRAPH: begin
        if (load_counter == NUM_NODES*NUM_NODES - 1) begin
          next_state = COMPUTE_SHORTEST_PATHS;
        end
      end
      COMPUTE_SHORTEST_PATHS: begin
        if (compute_counter == NUM_NODES*NUM_NODES*NUM_NODES - 1) begin
          next_state = CALCULATE_SUMS;
        end
      end
      CALCULATE_SUMS: begin
        if (output_counter == NUM_NODES - 1) begin
          next_state = OUTPUT_RESULTS;
        end
      end
      OUTPUT_RESULTS: begin
        if (output_counter == NUM_NODES - 1) begin
          next_state = DONE;
        end
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Load graph state
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      load_counter <= 0;
      expected_node <= 0;
      expected_neighbor <= 0;
    end else if (state == LOAD_GRAPH) begin
      if (edge_valid && node_idx == expected_node && neighbor_idx == expected_neighbor) begin
        graph[node_idx][neighbor_idx] = edge_weight;
        if (load_counter == NUM_NODES*NUM_NODES - 1) begin
          // Initialize distance matrix
          for (i = 0; i < NUM_NODES; i = i + 1) begin
            for (j = 0; j < NUM_NODES; j = j + 1) begin
              dist[i][j] = graph[i][j];
            end
          end
        end
        // Update counters
        if (expected_neighbor == NUM_NODES - 1) begin
          expected_node <= expected_node + 1;
          expected_neighbor <= 0;
        end else begin
          expected_neighbor <= expected_neighbor + 1;
        end
        load_counter <= load_counter + 1;
      end
    end
  end

  // Compute shortest paths (Floyd-Warshall)
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      compute_counter <= 0;
    end else if (state == COMPUTE_SHORTEST_PATHS) begin
      i = compute_counter / (NUM_NODES*NUM_NODES);
      j = (compute_counter / NUM_NODES) % NUM_NODES;
      k = compute_counter % NUM_NODES;
      
      if (dist[i][k] + dist[k][j] < dist[i][j]) begin
        dist[i][j] = dist[i][k] + dist[k][j];
      end
      
      compute_counter <= compute_counter + 1;
    end
  end

  // Calculate danger sums
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      output_counter <= 0;
      output_node <= 0;
    end else if (state == CALCULATE_SUMS) begin
      if (output_counter < NUM_NODES) begin
        danger_sums[output_counter] = 0;
        for (i = 0; i < NUM_NODES; i = i + 1) begin
          if (i != output_counter) begin
            danger_sums[output_counter] = danger_sums[output_counter] + dist[output_counter][i];
          end
        end
        danger_sums[output_counter] = danger_sums[output_counter] % MOD;
        output_counter <= output_counter + 1;
      end
    end
  end

  // Output results
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_node <= 0;
      danger_level <= 0;
      result_valid <= 0;
      done <= 0;
    end else begin
      case (state)
        OUTPUT_RESULTS: begin
          current_node <= output_node;
          danger_level <= danger_sums[output_node];
          result_valid <= 1;
          done <= 0;
          if (output_counter < NUM_NODES - 1) begin
            output_node <= output_node + 1;
            output_counter <= output_counter + 1;
          end
        end
        DONE: begin
          current_node <= 0;
          danger_level <= 0;
          result_valid <= 0;
          done <= 1;
        end
        default: begin
          current_node <= 0;
          danger_level <= 0;
          result_valid <= 0;
          done <= 0;
        end
      endcase
    end
  end

endmodule