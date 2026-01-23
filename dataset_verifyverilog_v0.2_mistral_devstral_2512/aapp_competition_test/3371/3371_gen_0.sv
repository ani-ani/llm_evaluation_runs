module partition_divider (
  input clk,
  input rst_n,
  input start,
  input [3:0] n,
  input [5:0] c,
  input [5:0] year [0:15],
  input [3:0] a [0:15],
  input [3:0] b [0:15],
  output reg [5:0] result_year,
  output reg result_valid,
  output reg result_impossible,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    BUILD_MATRIX,
    CHECK_YEAR,
    VERIFY_PARTITION,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [5:0] y_counter; // Current year being checked (0-59)
  reg [5:0] min_valid_year; // Smallest valid year found
  reg found_valid; // Flag indicating at least one valid year found
  reg [3:0] group [0:15]; // Group assignment for each participant (0: unassigned, 1: Group A, 2: Group B)
  reg [3:0] group_count [0:1]; // Count of participants in each group
  reg [3:0] current_participant; // Current participant being processed
  reg [3:0] stack_ptr; // Stack pointer for DFS
  reg [3:0] stack [0:15]; // Stack for DFS
  reg [3:0] color [0:15]; // Color for bipartite check (0: uncolored, 1: color 1, 2: color 2)
  reg [3:0] color_count [0:1]; // Count of colors
  reg bipartite_valid; // Flag indicating if bipartite check passed
  reg size_constraint_valid; // Flag indicating if size constraint passed
  reg [3:0] i, j; // Loop counters

  // Adjacency matrix (for current year threshold)
  reg adj_matrix [0:15][0:15];

  // Initialize registers
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      y_counter <= 0;
      min_valid_year <= 0;
      found_valid <= 0;
      result_year <= 0;
      result_valid <= 0;
      result_impossible <= 0;
      done <= 0;
      for (i = 0; i < 16; i = i + 1) begin
        group[i] <= 0;
        color[i] <= 0;
        for (j = 0; j < 16; j = j + 1) begin
          adj_matrix[i][j] <= 0;
        end
      end
      group_count[0] <= 0;
      group_count[1] <= 0;
      color_count[0] <= 0;
      color_count[1] <= 0;
      current_participant <= 0;
      stack_ptr <= 0;
      bipartite_valid <= 0;
      size_constraint_valid <= 0;
    end else begin
      current_state <= next_state;
      if (current_state == BUILD_MATRIX && next_state == CHECK_YEAR) begin
        // Build adjacency matrix for current year threshold
        for (i = 0; i < 16; i = i + 1) begin
          for (j = 0; j < 16; j = j + 1) begin
            adj_matrix[i][j] <= 0;
          end
        end
        for (i = 0; i < c; i = i + 1) begin
          if (year[i] < y_counter) begin
            // Must be in same group (Group A)
            adj_matrix[a[i]][b[i]] <= 1;
            adj_matrix[b[i]][a[i]] <= 1;
          end else begin
            // Must be in same group (Group B)
            adj_matrix[a[i]][b[i]] <= 1;
            adj_matrix[b[i]][a[i]] <= 1;
          end
        end
      end else if (current_state == VERIFY_PARTITION && next_state == CHECK_YEAR) begin
        // Reset group assignments
        for (i = 0; i < 16; i = i + 1) begin
          group[i] <= 0;
        end
        group_count[0] <= 0;
        group_count[1] <= 0;
        current_participant <= 0;
        stack_ptr <= 0;
        bipartite_valid <= 0;
        size_constraint_valid <= 0;
      end
    end
  end

  // State machine logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = BUILD_MATRIX;
          y_counter = 0;
          min_valid_year = 0;
          found_valid = 0;
          result_year = 0;
          result_valid = 0;
          result_impossible = 0;
          done = 0;
        end
      end
      BUILD_MATRIX: begin
        next_state = CHECK_YEAR;
      end
      CHECK_YEAR: begin
        next_state = VERIFY_PARTITION;
      end
      VERIFY_PARTITION: begin
        // Check if partition is valid
        if (bipartite_valid && size_constraint_valid) begin
          if (!found_valid) begin
            min_valid_year = y_counter;
            found_valid = 1;
          end
          if (y_counter == 59) begin
            next_state = DONE;
          end else begin
            y_counter = y_counter + 1;
            next_state = BUILD_MATRIX;
          end
        end else begin
          if (y_counter == 59) begin
            next_state = DONE;
          end else begin
            y_counter = y_counter + 1;
            next_state = BUILD_MATRIX;
          end
        end
      end
      DONE: begin
        if (found_valid) begin
          result_year = min_valid_year;
          result_valid = 1;
          result_impossible = 0;
        end else begin
          result_valid = 0;
          result_impossible = 1;
        end
        done = 1;
        next_state = IDLE;
      end
      default: begin
        next_state = IDLE;
      end
    endcase
  end

  // Combinational logic for partition verification
  always @(*) begin
    if (current_state == VERIFY_PARTITION) begin
      // Reset color assignments
      for (i = 0; i < 16; i = i + 1) begin
        color[i] = 0;
      end
      color_count[0] = 0;
      color_count[1] = 0;
      stack_ptr = 0;
      bipartite_valid = 1;

      // Perform DFS to check bipartiteness
      for (i = 0; i < n; i = i + 1) begin
        if (color[i] == 0) begin
          color[i] = 1;
          color_count[0] = color_count[0] + 1;
          stack[stack_ptr] = i;
          stack_ptr = stack_ptr + 1;

          while (stack_ptr > 0) begin
            current_participant = stack[stack_ptr - 1];
            stack_ptr = stack_ptr - 1;

            for (j = 0; j < n; j = j + 1) begin
              if (adj_matrix[current_participant][j] && color[j] == 0) begin
                color[j] = (color[current_participant] == 1) ? 2 : 1;
                if (color[j] == 1) begin
                  color_count[0] = color_count[0] + 1;
                end else begin
                  color_count[1] = color_count[1] + 1;
                end
                stack[stack_ptr] = j;
                stack_ptr = stack_ptr + 1;
              end else if (adj_matrix[current_participant][j] && color[j] == color[current_participant]) begin
                bipartite_valid = 0;
              end
            end
          end
        end
      end

      // Check size constraint
      if (bipartite_valid) begin
        if (color_count[0] > (2 * n) / 3 || color_count[1] > (2 * n) / 3) begin
          size_constraint_valid = 0;
        end else begin
          size_constraint_valid = 1;
        end
      end else begin
        size_constraint_valid = 0;
      end
    end
  end

endmodule