module bst_insertion (
  input clk,
  input rst_n,
  input start,
  input [7:0] data_in,
  output reg [7:0] cumulative_depth,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    LOAD_ROOT,
    SEARCH_INSERT,
    UPDATE_DEPTH,
    DONE
  } state_t;

  state_t current_state, next_state;

  // Tree storage
  reg [7:0] node_val [0:7];
  reg [7:0] left_child [0:7];
  reg [7:0] right_child [0:7];

  // Control signals
  reg [7:0] current_node_index;
  reg [7:0] current_depth;
  reg [3:0] insertion_count;
  reg [7:0] new_node_index;
  reg [7:0] parent_index;
  reg [7:0] temp_node_index;
  reg [7:0] temp_depth;

  // Initialize tree
  integer i;
  initial begin
    for (i = 0; i < 8; i = i + 1) begin
      node_val[i] = 0;
      left_child[i] = 8'hFF;
      right_child[i] = 8'hFF;
    end
  end

  // State machine
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      current_state <= IDLE;
      cumulative_depth <= 0;
      done <= 0;
      insertion_count <= 0;
      current_node_index <= 0;
      current_depth <= 0;
      new_node_index <= 0;
      parent_index <= 0;
      temp_node_index <= 0;
      temp_depth <= 0;
    end else begin
      current_state <= next_state;

      case (current_state)
        IDLE: begin
          done <= 0;
          if (start) begin
            next_state <= LOAD_ROOT;
          end
        end

        LOAD_ROOT: begin
          if (insertion_count == 0) begin
            node_val[0] <= data_in;
            insertion_count <= insertion_count + 1;
            cumulative_depth <= cumulative_depth + 0;
            next_state <= DONE;
          end else begin
            current_node_index <= 0;
            current_depth <= 0;
            next_state <= SEARCH_INSERT;
          end
        end

        SEARCH_INSERT: begin
          if (data_in < node_val[current_node_index]) begin
            if (left_child[current_node_index] == 8'hFF) begin
              // Found insertion point
              temp_node_index <= current_node_index;
              temp_depth <= current_depth + 1;
              next_state <= UPDATE_DEPTH;
            end else begin
              current_node_index <= left_child[current_node_index];
              current_depth <= current_depth + 1;
            end
          end else if (data_in > node_val[current_node_index]) begin
            if (right_child[current_node_index] == 8'hFF) begin
              // Found insertion point
              temp_node_index <= current_node_index;
              temp_depth <= current_depth + 1;
              next_state <= UPDATE_DEPTH;
            end else begin
              current_node_index <= right_child[current_node_index];
              current_depth <= current_depth + 1;
            end
          end else begin
            // Duplicate value - ignore
            next_state <= DONE;
          end
        end

        UPDATE_DEPTH: begin
          // Find next available node index
          for (i = 0; i < 8; i = i + 1) begin
            if (node_val[i] == 0) begin
              new_node_index <= i;
              break;
            end
          end

          // Insert new node
          node_val[new_node_index] <= data_in;
          if (data_in < node_val[temp_node_index]) begin
            left_child[temp_node_index] <= new_node_index;
          end else begin
            right_child[temp_node_index] <= new_node_index;
          end

          cumulative_depth <= cumulative_depth + temp_depth;
          insertion_count <= insertion_count + 1;
          next_state <= DONE;
        end

        DONE: begin
          done <= 1;
          if (!start) begin
            next_state <= IDLE;
          end
        end

        default: next_state <= IDLE;
      endcase
    end
  end

  // Next state logic
  always @(*) begin
    next_state = current_state;
    case (current_state)
      IDLE: begin
        if (start) begin
          next_state = LOAD_ROOT;
        end
      end

      LOAD_ROOT: begin
        if (insertion_count == 0) begin
          next_state = DONE;
        end else begin
          next_state = SEARCH_INSERT;
        end
      end

      SEARCH_INSERT: begin
        if (data_in < node_val[current_node_index]) begin
          if (left_child[current_node_index] == 8'hFF) begin
            next_state = UPDATE_DEPTH;
          end
        end else if (data_in > node_val[current_node_index]) begin
          if (right_child[current_node_index] == 8'hFF) begin
            next_state = UPDATE_DEPTH;
          end
        end else begin
          next_state = DONE;
        end
      end

      UPDATE_DEPTH: begin
        next_state = DONE;
      end

      DONE: begin
        if (!start) begin
          next_state = IDLE;
        end
      end

      default: next_state = IDLE;
    endcase
  end

endmodule