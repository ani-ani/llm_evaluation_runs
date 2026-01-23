module longest_race_path (
  input clk,
  input rst_n,
  input start,
  input [7:0] adj_matrix [0:7][0:7],
  output reg [3:0] max_length,
  output reg done
);

  parameter N = 8;
  parameter TARGET_NODE = 1;

  typedef enum logic [2:0] {
    IDLE,
    INIT,
    SEARCH,
    UPDATE_MAX,
    BACKTRACK,
    DONE
  } state_t;

  state_t current_state, next_state;

  reg [2:0] current_node;
  reg [2:0] next_node;
  reg [55:0] edge_mask;
  reg [3:0] current_length;
  reg [3:0] temp_max_length;
  reg [2:0] search_index;
  reg [2:0] backtrack_stack [0:55];
  reg [2:0] stack_ptr;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      current_node <= 0;
      edge_mask <= 0;
      current_length <= 0;
      temp_max_length <= 0;
      search_index <= 0;
      stack_ptr <= 0;
      max_length <= 0;
      done <= 0;
    end else begin
      current_state <= next_state;
      case (current_state)
        INIT: begin
          current_node <= 1;
          edge_mask <= 0;
          current_length <= 0;
          temp_max_length <= 0;
          search_index <= 0;
          stack_ptr <= 0;
        end
        SEARCH: begin
          if (search_index < N) begin
            if (adj_matrix[current_node][search_index] && !edge_mask[{current_node, search_index}]) begin
              next_node <= search_index;
              edge_mask[{current_node, search_index}] <= 1;
              edge_mask[{search_index, current_node}] <= 1;
              current_length <= current_length + 1;
              backtrack_stack[stack_ptr] <= current_node;
              stack_ptr <= stack_ptr + 1;
              current_node <= next_node;
              search_index <= 0;
            end else begin
              search_index <= search_index + 1;
            end
          end else begin
            if (stack_ptr > 0) begin
              stack_ptr <= stack_ptr - 1;
              current_node <= backtrack_stack[stack_ptr];
              search_index <= current_node + 1;
              edge_mask[{current_node, backtrack_stack[stack_ptr]}] <= 0;
              edge_mask[{backtrack_stack[stack_ptr], current_node}] <= 0;
              current_length <= current_length - 1;
            end else begin
              next_state <= DONE;
            end
          end
        end
        UPDATE_MAX: begin
          if (current_node == TARGET_NODE && current_length > temp_max_length) begin
            temp_max_length <= current_length;
          end
          next_state <= SEARCH;
        end
        BACKTRACK: begin
          if (stack_ptr > 0) begin
            stack_ptr <= stack_ptr - 1;
            current_node <= backtrack_stack[stack_ptr];
            search_index <= current_node + 1;
            edge_mask[{current_node, backtrack_stack[stack_ptr]}] <= 0;
            edge_mask[{backtrack_stack[stack_ptr], current_node}] <= 0;
            current_length <= current_length - 1;
          end else begin
            next_state <= DONE;
          end
        end
        DONE: begin
          max_length <= temp_max_length;
          done <= 1;
        end
      endcase
    end
  end

  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = INIT;
          done = 0;
        end
      end
      INIT: begin
        next_state = SEARCH;
      end
      SEARCH: begin
        if (search_index < N && adj_matrix[current_node][search_index] && !edge_mask[{current_node, search_index}]) begin
          next_state = UPDATE_MAX;
        end else if (search_index >= N && stack_ptr == 0) begin
          next_state = DONE;
        end
      end
      UPDATE_MAX: begin
        next_state = SEARCH;
      end
      BACKTRACK: begin
        if (stack_ptr == 0) begin
          next_state = DONE;
        end
      end
      DONE: begin
        next_state = IDLE;
      end
    endcase
  end

endmodule