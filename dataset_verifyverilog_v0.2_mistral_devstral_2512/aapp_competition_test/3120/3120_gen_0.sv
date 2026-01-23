module balloon_eq(
  input clk,
  input rst_n,
  input start,
  input [7:0] program_id,
  input [7:0] node_type,
  input [31:0] node_value,
  input [7:0] child1_idx,
  input [7:0] child2_idx,
  input [7:0] num_nodes,
  input node_valid,
  output reg [1:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    LOAD_A,
    LOAD_B,
    COMPUTE_A,
    COMPUTE_B,
    COMPARE,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Node storage for program A and B
  logic [7:0] node_type_mem_A [0:7];
  logic [31:0] node_value_mem_A [0:7];
  logic [7:0] child1_idx_mem_A [0:7];
  logic [7:0] child2_idx_mem_A [0:7];
  logic [7:0] node_type_mem_B [0:7];
  logic [31:0] node_value_mem_B [0:7];
  logic [7:0] child1_idx_mem_B [0:7];
  logic [7:0] child2_idx_mem_B [0:7];

  // Counters and control signals
  logic [7:0] node_counter;
  logic [7:0] compute_counter;
  logic [7:0] compare_counter;
  logic [7:0] multiset_size_A;
  logic [7:0] multiset_size_B;

  // Multiset storage (max 8 elements per program)
  logic [31:0] multiset_A [0:7];
  logic [31:0] multiset_B [0:7];

  // Temporary storage for computation
  logic [31:0] temp_multiset [0:7];
  logic [7:0] temp_size;

  // State machine
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      node_counter <= 0;
      compute_counter <= 0;
      compare_counter <= 0;
      multiset_size_A <= 0;
      multiset_size_B <= 0;
      result <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
    end
  end

  // Next state logic
  always_comb begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) next_state = LOAD_A;
      end
      LOAD_A: begin
        if (node_counter == num_nodes - 1) next_state = LOAD_B;
      end
      LOAD_B: begin
        if (node_counter == num_nodes - 1) next_state = COMPUTE_A;
      end
      COMPUTE_A: begin
        if (compute_counter == num_nodes - 1) next_state = COMPUTE_B;
      end
      COMPUTE_B: begin
        if (compute_counter == num_nodes - 1) next_state = COMPARE;
      end
      COMPARE: begin
        if (compare_counter == multiset_size_A - 1) next_state = DONE;
      end
      DONE: begin
        if (!start) next_state = IDLE;
      end
    endcase
  end

  // Node loading logic
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      node_counter <= 0;
    end else if (current_state == LOAD_A || current_state == LOAD_B) begin
      if (node_valid) begin
        if (current_state == LOAD_A) begin
          node_type_mem_A[node_counter] <= node_type;
          node_value_mem_A[node_counter] <= node_value;
          child1_idx_mem_A[node_counter] <= child1_idx;
          child2_idx_mem_A[node_counter] <= child2_idx;
        end else begin // LOAD_B
          node_type_mem_B[node_counter] <= node_type;
          node_value_mem_B[node_counter] <= node_value;
          child1_idx_mem_B[node_counter] <= child1_idx;
          child2_idx_mem_B[node_counter] <= child2_idx;
        end
        node_counter <= node_counter + 1;
      end
    end
  end

  // Compute multiset for program A
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      compute_counter <= 0;
      multiset_size_A <= 0;
    end else if (current_state == COMPUTE_A) begin
      if (compute_counter == 0) begin
        // Initialize multiset
        multiset_size_A <= 0;
      end
      // Process current node
      logic [7:0] current_node = compute_counter;
      logic [7:0] type = node_type_mem_A[current_node];
      logic [31:0] value = node_value_mem_A[current_node];
      logic [7:0] c1 = child1_idx_mem_A[current_node];
      logic [7:0] c2 = child2_idx_mem_A[current_node];

      if (type == 0) begin // VALUE
        multiset_A[multiset_size_A] <= value;
        multiset_size_A <= multiset_size_A + 1;
      end else if (type == 1) begin // CONCAT
        // Combine multisets of children
        logic [7:0] i, j;
        logic [7:0] size1 = 0, size2 = 0;
        // Get sizes of child multisets (simplified for this example)
        // In a real implementation, you would need to track sizes per node
        // For this example, we assume children are already processed
        // and their multisets are stored in temp_multiset
        // This is a simplified approach
        if (c1 != 255) begin
          // Copy child1 multiset
          for (i = 0; i < 8; i = i + 1) begin
            if (multiset_A[i] != 0) begin
              temp_multiset[size1] <= multiset_A[i];
              size1 <= size1 + 1;
            end
          end
        end
        if (c2 != 255) begin
          // Copy child2 multiset
          for (j = 0; j < 8; j = j + 1) begin
            if (multiset_A[j] != 0) begin
              temp_multiset[size1 + size2] <= multiset_A[j];
              size2 <= size2 + 1;
            end
          end
        end
        // Copy back to multiset_A
        multiset_size_A <= size1 + size2;
        for (i = 0; i < multiset_size_A; i = i + 1) begin
          multiset_A[i] <= temp_multiset[i];
        end
      end else if (type == 2 || type == 3) begin // SHUFFLE or SORTED
        // Identity operation for multiset comparison
        // Just copy child multiset (simplified)
        if (c1 != 255) begin
          logic [7:0] i;
          logic [7:0] size = 0;
          for (i = 0; i < 8; i = i + 1) begin
            if (multiset_A[i] != 0) begin
              temp_multiset[size] <= multiset_A[i];
              size <= size + 1;
            end
          end
          multiset_size_A <= size;
          for (i = 0; i < multiset_size_A; i = i + 1) begin
            multiset_A[i] <= temp_multiset[i];
          end
        end
      end
      compute_counter <= compute_counter + 1;
    end
  end

  // Compute multiset for program B
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      compute_counter <= 0;
      multiset_size_B <= 0;
    end else if (current_state == COMPUTE_B) begin
      if (compute_counter == 0) begin
        // Initialize multiset
        multiset_size_B <= 0;
      end
      // Process current node
      logic [7:0] current_node = compute_counter;
      logic [7:0] type = node_type_mem_B[current_node];
      logic [31:0] value = node_value_mem_B[current_node];
      logic [7:0] c1 = child1_idx_mem_B[current_node];
      logic [7:0] c2 = child2_idx_mem_B[current_node];

      if (type == 0) begin // VALUE
        multiset_B[multiset_size_B] <= value;
        multiset_size_B <= multiset_size_B + 1;
      end else if (type == 1) begin // CONCAT
        // Combine multisets of children
        logic [7:0] i, j;
        logic [7:0] size1 = 0, size2 = 0;
        if (c1 != 255) begin
          // Copy child1 multiset
          for (i = 0; i < 8; i = i + 1) begin
            if (multiset_B[i] != 0) begin
              temp_multiset[size1] <= multiset_B[i];
              size1 <= size1 + 1;
            end
          end
        end
        if (c2 != 255) begin
          // Copy child2 multiset
          for (j = 0; j < 8; j = j + 1) begin
            if (multiset_B[j] != 0) begin
              temp_multiset[size1 + size2] <= multiset_B[j];
              size2 <= size2 + 1;
            end
          end
        end
        // Copy back to multiset_B
        multiset_size_B <= size1 + size2;
        for (i = 0; i < multiset_size_B; i = i + 1) begin
          multiset_B[i] <= temp_multiset[i];
        end
      end else if (type == 2 || type == 3) begin // SHUFFLE or SORTED
        // Identity operation for multiset comparison
        if (c1 != 255) begin
          logic [7:0] i;
          logic [7:0] size = 0;
          for (i = 0; i < 8; i = i + 1) begin
            if (multiset_B[i] != 0) begin
              temp_multiset[size] <= multiset_B[i];
              size <= size + 1;
            end
          end
          multiset_size_B <= size;
          for (i = 0; i < multiset_size_B; i = i + 1) begin
            multiset_B[i] <= temp_multiset[i];
          end
        end
      end
      compute_counter <= compute_counter + 1;
    end
  end

  // Compare multisets
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      compare_counter <= 0;
      result <= 0;
      done <= 0;
    end else if (current_state == COMPARE) begin
      if (compare_counter == 0) begin
        // Initialize comparison
        if (multiset_size_A != multiset_size_B) begin
          result <= 2; // Not equal
        end else begin
          result <= 1; // Assume equal until proven otherwise
        end
      end else begin
        // Compare elements
        if (multiset_A[compare_counter] != multiset_B[compare_counter]) begin
          result <= 2; // Not equal
        end
      end
      compare_counter <= compare_counter + 1;
    end else if (current_state == DONE) begin
      done <= 1;
    end else begin
      done <= 0;
    end
  end

endmodule