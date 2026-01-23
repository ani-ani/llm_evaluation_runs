module tree_checker(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [7:0] c0, c1, c2, c3, c4, c5, c6, c7,
  output reg done,
  output reg yes
);

  // State declarations
  localparam [2:0] IDLE = 3'd0;
  localparam [2:0] INIT = 3'd1;
  localparam [2:0] ASSIGN_PARENT = 3'd2;
  localparam [2:0] VALIDATE = 3'd3;
  localparam [2:0] BACKTRACK = 3'd4;
  localparam [2:0] DONE_STATE = 3'd5;

  // Internal registers
  reg [2:0] state;
  reg [2:0] current_node;
  reg [2:0] parent [0:7];
  reg [2:0] children_count [0:7];
  reg [7:0] c_array [0:7];
  reg found_valid;
  reg [7:0] cycle_count;
  localparam [7:0] MAX_CYCLES = 8'd200;

  // Helper function to check tree validity
  function valid_tree;
    integer i, j, child_count;
    reg [7:0] computed_size [0:7];
    begin
      valid_tree = 1'b1;

      // Initialize computed sizes
      for (i = 0; i < 8; i = i + 1) begin
        computed_size[i] = 8'd0;
      end

      // Compute subtree sizes (simplified approach)
      // This is a placeholder - actual implementation would need proper tree traversal
      for (i = 0; i < n; i = i + 1) begin
        if (children_count[i] == 0) begin
          computed_size[i] = 8'd1;  // Leaf node
        end else begin
          computed_size[i] = 8'd1;  // Start with self
          for (j = 0; j < 8; j = j + 1) begin
            if (parent[j] == i) begin
              computed_size[i] = computed_size[i] + computed_size[j];
            end
          end
        end
      end

      // Check root has correct size
      if (computed_size[0] != n) begin
        valid_tree = 1'b0;
      end

      // Check no node has size 2
      for (i = 0; i < n; i = i + 1) begin
        if (c_array[i] == 8'd2) begin
          valid_tree = 1'b0;
        end
      end

      // Check parent-child relationships
      for (i = 1; i < n; i = i + 1) begin
        if (parent[i] >= n) begin
          valid_tree = 1'b0;
        end
        if (parent[i] == i) begin
          valid_tree = 1'b0;
        end
      end

      // Check internal nodes have ≥2 children
      for (i = 0; i < n; i = i + 1) begin
        child_count = 0;
        for (j = 0; j < 8; j = j + 1) begin
          if (parent[j] == i) begin
            child_count = child_count + 1;
          end
        end
        if (child_count > 0 && child_count < 2) begin
          valid_tree = 1'b0;
        end
      end

      // Check computed subtree sizes match input
      for (i = 0; i < n; i = i + 1) begin
        if (computed_size[i] != c_array[i]) begin
          valid_tree = 1'b0;
        end
      end
    end
  endfunction

  // Main state machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 1'b0;
      yes <= 1'b0;
      found_valid <= 1'b0;
      cycle_count <= 8'd0;

      // Initialize all registers
      current_node <= 3'd0;
      for (integer i = 0; i < 8; i = i + 1) begin
        parent[i] <= 3'd0;
        children_count[i] <= 3'd0;
        c_array[i] <= 8'd0;
      end
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          yes <= 1'b0;
          found_valid <= 1'b0;
          cycle_count <= 8'd0;
          if (start) begin
            state <= INIT;
          end
        end

        INIT: begin
          // Store input values
          c_array[0] <= c0;
          c_array[1] <= c1;
          c_array[2] <= c2;
          c_array[3] <= c3;
          c_array[4] <= c4;
          c_array[5] <= c5;
          c_array[6] <= c6;
          c_array[7] <= c7;

          // Initialize tree structure
          parent[0] <= 3'd0;  // Root is its own parent
          for (integer i = 1; i < 8; i = i + 1) begin
            parent[i] <= 3'd7;  // Invalid parent
            children_count[i] <= 3'd0;
          end
          children_count[0] <= 3'd0;

          current_node <= 3'd1;
          state <= ASSIGN_PARENT;
        end

        ASSIGN_PARENT: begin
          cycle_count <= cycle_count + 8'd1;

          // Try to assign a valid parent to current_node
          if (parent[current_node] < n - 1) begin
            parent[current_node] <= parent[current_node] + 3'd1;

            // Update children counts
            if (parent[current_node] < n) begin
              children_count[parent[current_node]] <= children_count[parent[current_node]] + 3'd1;
            end

            // Check if this parent assignment is valid
            if (parent[current_node] < n && parent[current_node] != current_node) begin
              state <= VALIDATE;
            end
          end else begin
            // No more parents to try, backtrack
            state <= BACKTRACK;
          end
        end

        VALIDATE: begin
          cycle_count <= cycle_count + 8'd1;

          // Check if we've assigned all nodes
          if (current_node == n - 1) begin
            // All nodes assigned, check validity
            if (valid_tree()) begin
              found_valid <= 1'b1;
              state <= DONE_STATE;
            end else begin
              state <= ASSIGN_PARENT;
            end
          end else begin
            // Move to next node
            current_node <= current_node + 3'd1;
            parent[current_node] <= 3'd0;
            state <= ASSIGN_PARENT;
          end
        end

        BACKTRACK: begin
          cycle_count <= cycle_count + 8'd1;

          // Check if we've exceeded maximum cycles
          if (cycle_count >= MAX_CYCLES) begin
            state <= DONE_STATE;
          end else if (current_node > 1) begin
            // Reset current node's parent
            if (parent[current_node] < n) begin
              children_count[parent[current_node]] <= children_count[parent[current_node]] - 3'd1;
            end
            parent[current_node] <= 3'd7;

            // Move to previous node
            current_node <= current_node - 3'd1;
            state <= ASSIGN_PARENT;
          end else begin
            // Cannot backtrack further
            state <= DONE_STATE;
          end
        end

        DONE_STATE: begin
          done <= 1'b1;
          yes <= found_valid;
          if (!start) begin
            state <= IDLE;
          end
        end

        default: begin
          state <= IDLE;
          done <= 1'b0;
          yes <= 1'b0;
        end
      endcase
    end
  end

endmodule