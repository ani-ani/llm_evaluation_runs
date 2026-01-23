module chromatic_number_solver (
  input clk,
  input rst_n,
  input start,
  input [7:0] adjacency_matrix [0:7] [0:7],
  input [2:0] num_vertices,
  output reg [2:0] chromatic_number,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    INIT_COLOR_K,
    CHECK_K,
    SETUP_BACKTRACK,
    ASSIGN_COLOR,
    VERIFY_CONSTRAINT,
    BACKTRACK,
    NEXT_VERTEX,
    FOUND_SOLUTION,
    INCREMENT_K,
    DONE
  } state_t;

  state_t state, next_state;

  // Internal registers
  reg [2:0] current_k; // Current number of colors being tried (1-8)
  reg [2:0] current_vertex; // Current vertex being colored (0-7)
  reg [2:0] current_color; // Current color being tried (0-7)
  reg [2:0] color_assignment [0:7]; // Color assigned to each vertex
  reg [2:0] vertex_index; // Index for vertex processing
  reg [2:0] color_index; // Index for color checking
  reg valid_coloring; // Flag indicating valid coloring found

  // State transition logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      current_k <= 0;
      current_vertex <= 0;
      current_color <= 0;
      chromatic_number <= 0;
      done <= 0;
      valid_coloring <= 0;
      for (int i = 0; i < 8; i++) begin
        color_assignment[i] <= 0;
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
        if (start) next_state = INIT_COLOR_K;
      end
      INIT_COLOR_K: begin
        next_state = CHECK_K;
      end
      CHECK_K: begin
        if (current_k >= num_vertices) begin
          next_state = DONE;
        end else begin
          next_state = SETUP_BACKTRACK;
        end
      end
      SETUP_BACKTRACK: begin
        next_state = ASSIGN_COLOR;
      end
      ASSIGN_COLOR: begin
        next_state = VERIFY_CONSTRAINT;
      end
      VERIFY_CONSTRAINT: begin
        if (valid_coloring) begin
          next_state = NEXT_VERTEX;
        end else begin
          next_state = BACKTRACK;
        end
      end
      BACKTRACK: begin
        if (current_color < current_k - 1) begin
          next_state = ASSIGN_COLOR;
        end else if (current_vertex > 0) begin
          next_state = BACKTRACK;
        end else begin
          next_state = INCREMENT_K;
        end
      end
      NEXT_VERTEX: begin
        if (current_vertex == num_vertices - 1) begin
          next_state = FOUND_SOLUTION;
        end else begin
          next_state = SETUP_BACKTRACK;
        end
      end
      FOUND_SOLUTION: begin
        next_state = DONE;
      end
      INCREMENT_K: begin
        next_state = CHECK_K;
      end
      DONE: begin
        next_state = IDLE;
      end
      default: next_state = IDLE;
    endcase
  end

  // Datapath logic
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      // Reset all registers
    end else begin
      case (state)
        INIT_COLOR_K: begin
          current_k <= 1;
          current_vertex <= 0;
          current_color <= 0;
          valid_coloring <= 0;
          for (int i = 0; i < 8; i++) begin
            color_assignment[i] <= 0;
          end
        end
        SETUP_BACKTRACK: begin
          current_color <= 0;
          valid_coloring <= 0;
        end
        ASSIGN_COLOR: begin
          color_assignment[current_vertex] <= current_color;
        end
        VERIFY_CONSTRAINT: begin
          // Check if current color assignment is valid
          valid_coloring = 1;
          for (int i = 0; i < current_vertex; i++) begin
            if (adjacency_matrix[current_vertex][i] && 
                (color_assignment[i] == current_color)) begin
              valid_coloring = 0;
            end
          end
        end
        BACKTRACK: begin
          if (current_color < current_k - 1) begin
            current_color <= current_color + 1;
          end else if (current_vertex > 0) begin
            current_vertex <= current_vertex - 1;
            current_color <= color_assignment[current_vertex] + 1;
          end
        end
        NEXT_VERTEX: begin
          current_vertex <= current_vertex + 1;
        end
        FOUND_SOLUTION: begin
          chromatic_number <= current_k;
          done <= 1;
        end
        INCREMENT_K: begin
          current_k <= current_k + 1;
          current_vertex <= 0;
          current_color <= 0;
          valid_coloring <= 0;
          for (int i = 0; i < 8; i++) begin
            color_assignment[i] <= 0;
          end
        end
        DONE: begin
          done <= 1;
        end
      endcase
    end
  end

endmodule