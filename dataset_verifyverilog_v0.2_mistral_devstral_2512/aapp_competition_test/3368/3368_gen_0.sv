module sanitaire(
  input clk,
  input rst_n,
  input start,
  input [7:0] enclosure_count,
  input [7:0] animal_count,
  input [7:0] correct_animal [0:3],
  input [7:0] num_animals [0:3],
  input [7:0] animal_types [0:7],
  input [7:0] enclosure_idx [0:7],
  output reg [1:0] result,
  output reg done
);

  // State definitions
  typedef enum logic [1:0] {
    IDLE,
    BUILD_GRAPH,
    CHECK_CONNECTIVITY,
    DONE
  } state_t;

  state_t state;
  reg [7:0] cycle_count;
  reg [3:0] current_enclosure;
  reg [3:0] current_animal;
  reg [3:0] visited [0:3];
  reg [3:0] adjacency [0:3][0:3];
  reg [3:0] incorrect_enclosures;
  reg [3:0] stack [0:3];
  reg [1:0] stack_ptr;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      cycle_count <= 0;
      current_enclosure <= 0;
      current_animal <= 0;
      for (int i = 0; i < 4; i++) begin
        visited[i] <= 0;
        for (int j = 0; j < 4; j++) begin
          adjacency[i][j] <= 0;
        end
      end
      incorrect_enclosures <= 0;
      stack_ptr <= 0;
      result <= 0;
      done <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= BUILD_GRAPH;
            cycle_count <= 0;
            current_enclosure <= 0;
            current_animal <= 0;
            incorrect_enclosures <= 0;
            for (int i = 0; i < 4; i++) begin
              visited[i] <= 0;
              for (int j = 0; j < 4; j++) begin
                adjacency[i][j] <= 0;
              end
            end
          end
        end

        BUILD_GRAPH: begin
          if (cycle_count < 20) begin
            cycle_count <= cycle_count + 1;
            if (current_enclosure < enclosure_count) begin
              if (current_animal < num_animals[current_enclosure]) begin
                // Check if animal is incorrect
                if (animal_types[current_animal] != correct_animal[current_enclosure]) begin
                  incorrect_enclosures[current_enclosure] <= 1;
                  // Add edge to correct enclosure
                  if (enclosure_idx[current_animal] != current_enclosure) begin
                    adjacency[current_enclosure][enclosure_idx[current_animal]] <= 1;
                  end
                end
                current_animal <= current_animal + 1;
              end else begin
                current_animal <= 0;
                current_enclosure <= current_enclosure + 1;
              end
            end else begin
              state <= CHECK_CONNECTIVITY;
              stack_ptr <= 0;
              // Find first incorrect enclosure
              for (int i = 0; i < 4; i++) begin
                if (incorrect_enclosures[i]) begin
                  stack[0] <= i;
                  stack_ptr <= 1;
                  break;
                end
              end
            end
          end
        end

        CHECK_CONNECTIVITY: begin
          if (stack_ptr > 0) begin
            current_enclosure <= stack[stack_ptr - 1];
            stack_ptr <= stack_ptr - 1;
            visited[current_enclosure] <= 1;
            // Push neighbors
            for (int i = 0; i < 4; i++) begin
              if (adjacency[current_enclosure][i] && !visited[i] && !stack[stack_ptr]) begin
                stack[stack_ptr] <= i;
                stack_ptr <= stack_ptr + 1;
              end
            end
          end else begin
            // Check if all incorrect enclosures are visited
            reg all_visited = 1;
            for (int i = 0; i < 4; i++) begin
              if (incorrect_enclosures[i] && !visited[i]) begin
                all_visited = 0;
              end
            end
            if (incorrect_enclosures == 0) begin
              result <= 0; // FALSE_ALARM
            end else if (all_visited) begin
              result <= 1; // POSSIBLE
            end else begin
              result <= 2; // IMPOSSIBLE
            end
            state <= DONE;
          end
        end

        DONE: begin
          done <= 1;
          if (!start) begin
            state <= IDLE;
            done <= 0;
          end
        end
      endcase
    end
  end

endmodule