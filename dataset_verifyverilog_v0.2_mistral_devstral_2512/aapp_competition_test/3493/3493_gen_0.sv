module max_bipartite_matching (
  input clk,
  input rst_n,
  input start,
  input [2:0] row_idx,
  input [2:0] col_idx,
  input valid,
  input edge_value,
  output reg [2:0] num_matchings,
  output reg [2:0] matching_indices [0:7],
  output reg output_valid,
  output reg done,
  output reg [2:0] state_out
);

  // State definitions
  localparam [2:0] IDLE = 3'b000;
  localparam [2:0] LOAD_MATRIX = 3'b001;
  localparam [2:0] CHECK_PERFECT = 3'b010;
  localparam [2:0] FIND_MATCHING = 3'b011;
  localparam [2:0] OUTPUT_MATCHING = 3'b100;
  localparam [2:0] VERIFY_DISJOINT = 3'b101;
  localparam [2:0] DONE = 3'b110;

  reg [2:0] state, next_state;

  // Adjacency matrix storage (8x8)
  reg [7:0] adj_matrix [0:7];
  reg [2:0] matrix_row, matrix_col;
  reg [5:0] matrix_count;

  // Used edges tracking
  reg [7:0] used_edges [0:7];

  // Matching storage
  reg [2:0] current_matching [0:7];
  reg [2:0] temp_matching [0:7];
  reg [2:0] matching_count;

  // DFS state
  reg [2:0] dfs_row;
  reg [2:0] dfs_col;
  reg [2:0] dfs_level;
  reg [7:0] visited_rows;
  reg [7:0] visited_cols;
  reg dfs_found;
  reg dfs_complete;

  // Output control
  reg [2:0] output_idx;
  reg [2:0] output_matching_idx;

  // Counters and flags
  reg [2:0] check_count;
  reg check_found;
  reg verify_passed;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      matrix_row <= 0;
      matrix_col <= 0;
      matrix_count <= 0;
      matching_count <= 0;
      num_matchings <= 0;
      output_valid <= 0;
      done <= 0;
      output_idx <= 0;
      output_matching_idx <= 0;
      dfs_level <= 0;
      dfs_found <= 0;
      dfs_complete <= 0;
      check_count <= 0;
      check_found <= 0;
      verify_passed <= 0;
      for (int i = 0; i < 8; i = i + 1) begin
        adj_matrix[i] <= 0;
        used_edges[i] <= 0;
        current_matching[i] <= 0;
        temp_matching[i] <= 0;
      end
    end else begin
      state <= next_state;
    end
  end

  // Next state logic
  always @(*) begin
    next_state = state;
    case (state)
      IDLE: begin
        if (start) next_state = LOAD_MATRIX;
      end
      LOAD_MATRIX: begin
        if (matrix_count == 63) next_state = CHECK_PERFECT;
      end
      CHECK_PERFECT: begin
        if (check_found) next_state = FIND_MATCHING;
        else next_state = DONE;
      end
      FIND_MATCHING: begin
        if (dfs_complete) begin
          if (dfs_found) next_state = VERIFY_DISJOINT;
          else next_state = DONE;
        end
      end
      VERIFY_DISJOINT: begin
        if (verify_passed) begin
          if (matching_count == 7) next_state = DONE;
          else next_state = FIND_MATCHING;
        end else begin
          next_state = DONE;
        end
      end
      OUTPUT_MATCHING: begin
        if (output_idx == 7) begin
          if (output_matching_idx == matching_count) next_state = DONE;
          else next_state = OUTPUT_MATCHING;
        end
      end
      DONE: begin
        if (start) next_state = LOAD_MATRIX;
      end
      default: next_state = IDLE;
    endcase
  end

  // Matrix loading
  always @(posedge clk) begin
    if (!rst_n) begin
      matrix_row <= 0;
      matrix_col <= 0;
      matrix_count <= 0;
    end else if (state == LOAD_MATRIX && valid) begin
      adj_matrix[row_idx][col_idx] <= edge_value;
      if (row_idx == 7 && col_idx == 7) begin
        matrix_count <= matrix_count + 1;
      end
    end
  end

  // Check for perfect matching (simplified check)
  always @(posedge clk) begin
    if (!rst_n) begin
      check_count <= 0;
      check_found <= 0;
    end else if (state == CHECK_PERFECT) begin
      // Simple check: count edges per row and column
      reg [2:0] row_edges [0:7];
      reg [2:0] col_edges [0:7];
      integer i, j;

      for (i = 0; i < 8; i = i + 1) begin
        row_edges[i] = 0;
        col_edges[i] = 0;
      end

      for (i = 0; i < 8; i = i + 1) begin
        for (j = 0; j < 8; j = j + 1) begin
          if (adj_matrix[i][j]) begin
            row_edges[i] = row_edges[i] + 1;
            col_edges[j] = col_edges[j] + 1;
          end
        end
      end

      // Check if at least one perfect matching might exist
      reg possible = 1;
      for (i = 0; i < 8; i = i + 1) begin
        if (row_edges[i] == 0 || col_edges[i] == 0) possible = 0;
      end

      check_found <= possible;
      check_count <= check_count + 1;
      if (check_count == 1) next_state = (possible) ? FIND_MATCHING : DONE;
    end
  end

  // DFS for finding perfect matching
  always @(posedge clk) begin
    if (!rst_n) begin
      dfs_row <= 0;
      dfs_col <= 0;
      dfs_level <= 0;
      dfs_found <= 0;
      dfs_complete <= 0;
      visited_rows <= 0;
      visited_cols <= 0;
    end else if (state == FIND_MATCHING) begin
      if (!dfs_complete) begin
        if (dfs_level == 0) begin
          // Initialize DFS
          visited_rows <= 0;
          visited_cols <= 0;
          dfs_row <= 0;
          dfs_col <= 0;
          dfs_found <= 0;
        end

        // DFS implementation
        if (dfs_level < 8) begin
          if (dfs_col == 8) begin
            // Backtrack
            dfs_level <= dfs_level - 1;
            dfs_col <= temp_matching[dfs_level] + 1;
            visited_rows[dfs_level] <= 0;
            visited_cols[temp_matching[dfs_level]] <= 0;
          end else begin
            // Try next column
            if (!visited_cols[dfs_col] && adj_matrix[dfs_row][dfs_col] && !used_edges[dfs_row][dfs_col]) begin
              temp_matching[dfs_row] <= dfs_col;
              visited_rows[dfs_row] <= 1;
              visited_cols[dfs_col] <= 1;

              if (dfs_row == 7) begin
                // Found complete matching
                dfs_found <= 1;
                dfs_complete <= 1;
              end else begin
                dfs_row <= dfs_row + 1;
                dfs_col <= 0;
                dfs_level <= dfs_level + 1;
              end
            end else begin
              dfs_col <= dfs_col + 1;
            end
          end
        end else begin
          dfs_complete <= 1;
        end
      end
    end
  end

  // Verify disjointness
  always @(posedge clk) begin
    if (!rst_n) begin
      verify_passed <= 0;
    end else if (state == VERIFY_DISJOINT) begin
      reg [2:0] i, j;
      reg valid = 1;

      // Check if any used edges are in the new matching
      for (i = 0; i < 8; i = i + 1) begin
        j = temp_matching[i];
        if (used_edges[i][j]) begin
          valid = 0;
          break;
        end
      end

      verify_passed <= valid;
      if (valid) begin
        // Update used edges and current matching
        for (i = 0; i < 8; i = i + 1) begin
          j = temp_matching[i];
          used_edges[i][j] <= 1;
          current_matching[i] <= j + 1; // 1-based output
        end
        matching_count <= matching_count + 1;
      end
      next_state = (valid && matching_count < 7) ? FIND_MATCHING : DONE;
    end
  end

  // Output handling
  always @(posedge clk) begin
    if (!rst_n) begin
      output_idx <= 0;
      output_matching_idx <= 0;
      output_valid <= 0;
    end else if (state == OUTPUT_MATCHING) begin
      if (output_idx == 0) begin
        output_valid <= 1;
        num_matchings <= matching_count;
      end

      matching_indices[output_idx] <= current_matching[output_idx];

      if (output_idx == 7) begin
        output_idx <= 0;
        output_matching_idx <= output_matching_idx + 1;
        if (output_matching_idx == matching_count) begin
          output_valid <= 0;
          done <= 1;
        end
      end else begin
        output_idx <= output_idx + 1;
      end
    end else if (state == DONE) begin
      done <= 1;
    end else begin
      output_valid <= 0;
      done <= 0;
    end
  end

  // State output
  always @(*) begin
    state_out = state;
  end

endmodule