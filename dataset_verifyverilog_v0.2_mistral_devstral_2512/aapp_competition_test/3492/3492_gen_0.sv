module max_matching (
  input clk,
  input rst_n,
  input start,
  input load_en,
  input [3:0] load_idx,
  input [9:0] load_data,
  output reg [3:0] max_match,
  output reg done,
  output reg valid
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    LOAD_DATA,
    BUILD_GRAPH,
    FIND_MATCHING,
    UPDATE_MATCHING,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal storage
  reg [3:0] suppliers [0:3];           // Supplier states
  reg [3:0] factories [0:3];           // Factory states
  reg [3:0] transport_count [0:3];     // Number of states per transport firm
  reg [7:0] transport_states [0:3][0:7]; // Transport firm states (max 8 states each)

  // Adjacency matrix: supplier -> factory
  reg [3:0] adjacency [0:3][0:3];

  // Matching tracking
  reg [3:0] factory_to_supplier [0:3]; // -1 if unmatched
  reg [3:0] supplier_to_factory [0:3]; // -1 if unmatched

  // Counters and temporary variables
  reg [3:0] current_factory;
  reg [3:0] current_supplier;
  reg [3:0] path_counter;
  reg [3:0] temp_path [0:3];
  reg [3:0] visited_suppliers [0:3];
  reg [3:0] visited_factories [0:3];

  // Initialize all state
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      max_match <= 4'b0;
      done <= 1'b0;
      valid <= 1'b0;
      current_factory <= 4'b0;
      current_supplier <= 4'b0;
      path_counter <= 4'b0;

      // Initialize storage
      for (int i = 0; i < 4; i++) begin
        suppliers[i] <= 4'b0;
        factories[i] <= 4'b0;
        transport_count[i] <= 4'b0;
        factory_to_supplier[i] <= 4'b0;
        supplier_to_factory[i] <= 4'b0;
        visited_suppliers[i] <= 4'b0;
        visited_factories[i] <= 4'b0;
        for (int j = 0; j < 4; j++) begin
          adjacency[i][j] <= 4'b0;
        end
        for (int j = 0; j < 8; j++) begin
          transport_states[i][j] <= 8'b0;
        end
      end
    end else begin
      current_state <= next_state;
    end
  end

  // State machine logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      next_state <= IDLE;
    end else begin
      case (current_state)
        IDLE: begin
          if (load_en) begin
            next_state <= LOAD_DATA;
          end else if (start) begin
            next_state <= BUILD_GRAPH;
          end else begin
            next_state <= IDLE;
          end
        end

        LOAD_DATA: begin
          if (!load_en) begin
            next_state <= IDLE;
          end else begin
            next_state <= LOAD_DATA;
          end
        end

        BUILD_GRAPH: begin
          next_state <= FIND_MATCHING;
        end

        FIND_MATCHING: begin
          if (path_counter == 4'd15) begin
            next_state <= UPDATE_MATCHING;
          end else begin
            next_state <= FIND_MATCHING;
          end
        end

        UPDATE_MATCHING: begin
          if (current_factory == 4'd3) begin
            next_state <= DONE;
          end else begin
            next_state <= FIND_MATCHING;
          end
        end

        DONE: begin
          next_state <= IDLE;
        end

        default: begin
          next_state <= IDLE;
        end
      endcase
    end
  end

  // Load data logic
  always @(posedge clk) begin
    if (current_state == LOAD_DATA && load_en) begin
      if (load_idx < 4) begin
        suppliers[load_idx] <= load_data[3:0];
      end else if (load_idx < 8) begin
        factories[load_idx - 4] <= load_data[3:0];
      end else if (load_idx < 12) begin
        transport_count[load_idx - 8] <= load_data[7:0];
      end else begin
        integer firm_idx = load_data[9:8];
        integer state_idx = load_data[7:4];
        if (firm_idx < 4 && state_idx < 8) begin
          transport_states[firm_idx][state_idx] <= {
            load_data[3],  // isSupplier
            load_data[2],  // isFactory
            load_data[1:0],// padding
            load_data[3:0] // state data
          };
        end
      end
    end
  end

  // Build graph logic
  always @(posedge clk) begin
    if (current_state == BUILD_GRAPH) begin
      // Initialize adjacency matrix
      for (int i = 0; i < 4; i++) begin
        for (int j = 0; j < 4; j++) begin
          adjacency[i][j] <= 4'b0;
        end
      end

      // Build connections through transport firms
      for (int firm = 0; firm < 4; firm++) begin
        for (int state = 0; state < transport_count[firm]; state++) begin
          reg [7:0] t_state = transport_states[firm][state];
          reg is_supplier = t_state[7];
          reg is_factory = t_state[6];
          reg [3:0] state_data = t_state[3:0];

          if (is_supplier) begin
            for (int s = 0; s < 4; s++) begin
              if (suppliers[s] == state_data) begin
                // Mark this supplier as connected through this firm
                for (int f = 0; f < 4; f++) begin
                  if (factories[f] == state_data) begin
                    adjacency[s][f] <= 1'b1;
                  end
                end
              end
            end
          end
        end
      end

      // Initialize matching
      for (int i = 0; i < 4; i++) begin
        factory_to_supplier[i] <= 4'b0;
        supplier_to_factory[i] <= 4'b0;
      end

      current_factory <= 4'b0;
      max_match <= 4'b0;
    end
  end

  // Find matching logic
  always @(posedge clk) begin
    if (current_state == FIND_MATCHING) begin
      // Simple DFS-style search for augmenting path
      if (path_counter == 0) begin
        // Initialize visited arrays
        for (int i = 0; i < 4; i++) begin
          visited_suppliers[i] <= 4'b0;
          visited_factories[i] <= 4'b0;
        end
        temp_path[0] <= current_factory;
        path_counter <= 1;
      end else begin
        // Try to find augmenting path
        reg [3:0] current_node = temp_path[path_counter - 1];
        reg is_factory = (current_node < 4) ? 1'b0 : 1'b1;
        reg [3:0] node_idx = is_factory ? current_node - 4 : current_node;

        if (is_factory) begin
          // At factory, try to find connected supplier
          for (int s = 0; s < 4; s++) begin
            if (adjacency[s][node_idx] && !visited_suppliers[s]) begin
              visited_suppliers[s] <= 1'b1;
              temp_path[path_counter] <= s;
              path_counter <= path_counter + 1;
              break;
            end
          end
        end else begin
          // At supplier, try to find connected factory
          for (int f = 0; f < 4; f++) begin
            if (adjacency[node_idx][f] && !visited_factories[f]) begin
              visited_factories[f] <= 1'b1;
              temp_path[path_counter] <= f + 4;
              path_counter <= path_counter + 1;
              break;
            end
          end
        end

        // Check if we found a path or need to backtrack
        if (path_counter > 1 && temp_path[path_counter - 1] == current_factory) begin
          // Found augmenting path
          next_state <= UPDATE_MATCHING;
        end else if (path_counter == 4'd15) begin
          // No path found
          next_state <= UPDATE_MATCHING;
        end
      end
    end
  end

  // Update matching logic
  always @(posedge clk) begin
    if (current_state == UPDATE_MATCHING) begin
      // Update matching based on found path
      if (path_counter > 1) begin
        // Alternate path found, update matching
        for (int i = 0; i < path_counter - 1; i += 2) begin
          reg [3:0] supplier = temp_path[i];
          reg [3:0] factory = temp_path[i + 1] - 4;
          factory_to_supplier[factory] <= supplier;
          supplier_to_factory[supplier] <= factory;
        end
        max_match <= max_match + 1;
      end

      // Move to next factory
      current_factory <= current_factory + 1;
      path_counter <= 4'b0;

      if (current_factory == 4'd4) begin
        done <= 1'b1;
        valid <= 1'b1;
      end
    end
  end

  // Reset done and valid when starting new computation
  always @(posedge clk) begin
    if (start && current_state == IDLE) begin
      done <= 1'b0;
      valid <= 1'b0;
    end
  end

endmodule