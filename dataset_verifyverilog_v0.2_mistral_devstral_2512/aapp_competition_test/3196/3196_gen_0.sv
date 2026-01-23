module bicycle_race_routes (
  input clk,
  input rst_n,
  input start,
  input [7:0] node_enable,
  input [7:0] adj_matrix [0:7],
  output reg [29:0] result,
  output reg done,
  output reg inf_flag
);

  // State definitions
  typedef enum logic [2:0] {
    IDLE,
    INIT,
    PROCESSING,
    COUNTING,
    CYCLE_CHECK,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Internal registers
  reg [2:0] depth;
  reg [7:0] current_node;
  reg [7:0] visited [0:15];
  reg [31:0] path_count;
  reg [7:0] cycle_detected;
  reg [7:0] stack_ptr;
  reg [7:0] stack [0:15];
  reg [7:0] next_nodes;
  reg [7:0] temp_visited;
  reg cycle_found;

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      depth <= 0;
      current_node <= 0;
      path_count <= 0;
      cycle_detected <= 0;
      stack_ptr <= 0;
      done <= 0;
      inf_flag <= 0;
      result <= 0;
      for (int i = 0; i < 16; i++) begin
        visited[i] <= 0;
        stack[i] <= 0;
      end
    end else begin
      current_state <= next_state;

      case (current_state)
        IDLE: begin
          if (start) begin
            next_state = INIT;
          end
        end

        INIT: begin
          depth <= 0;
          current_node <= 0;
          path_count <= 0;
          cycle_detected <= 0;
          stack_ptr <= 0;
          done <= 0;
          inf_flag <= 0;
          result <= 0;
          for (int i = 0; i < 16; i++) begin
            visited[i] <= 0;
            stack[i] <= 0;
          end
          next_state = PROCESSING;
        end

        PROCESSING: begin
          if (depth > 15) begin
            next_state = CYCLE_CHECK;
          end else if (current_node == 1) begin
            path_count <= path_count + 1;
            if (stack_ptr > 0) begin
              stack_ptr <= stack_ptr - 1;
              current_node <= stack[stack_ptr];
              depth <= depth - 1;
            end else begin
              next_state = DONE;
            end
          end else begin
            // Push current node to stack
            stack[stack_ptr] <= current_node;
            stack_ptr <= stack_ptr + 1;
            depth <= depth + 1;
            visited[depth] <= current_node;

            // Find next nodes
            next_nodes = adj_matrix[current_node] & node_enable;

            if (next_nodes == 0) begin
              if (stack_ptr > 0) begin
                stack_ptr <= stack_ptr - 1;
                current_node <= stack[stack_ptr];
                depth <= depth - 1;
              end else begin
                next_state = DONE;
              end
            end else begin
              // Find first enabled node
              for (int i = 0; i < 8; i++) begin
                if (next_nodes[i]) begin
                  current_node <= i;
                  break;
                end
              end
            end
          end
        end

        CYCLE_CHECK: begin
          cycle_found = 0;
          for (int i = 0; i < depth; i++) begin
            if (visited[i] == current_node) begin
              cycle_found = 1;
              break;
            end
          end

          if (cycle_found) begin
            inf_flag <= 1;
            next_state = DONE;
          end else begin
            next_state = PROCESSING;
          end
        end

        DONE: begin
          result <= path_count[29:0];
          done <= 1;
        end

        default: begin
          next_state = IDLE;
        end
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = INIT;
        end
      end

      INIT: begin
        next_state = PROCESSING;
      end

      PROCESSING: begin
        if (depth > 15) begin
          next_state = CYCLE_CHECK;
        end else if (current_node == 1) begin
          if (stack_ptr == 0) begin
            next_state = DONE;
          end
        end else if (next_nodes == 0 && stack_ptr == 0) begin
          next_state = DONE;
        end
      end

      CYCLE_CHECK: begin
        if (cycle_found) begin
          next_state = DONE;
        end else begin
          next_state = PROCESSING;
        end
      end

      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end

      default: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule