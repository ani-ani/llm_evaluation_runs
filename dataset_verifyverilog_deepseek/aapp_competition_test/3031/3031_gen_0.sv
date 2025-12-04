module good_node_finder(
  input clk, 
  input rst_n, 
  input start, 
  input [2:0] edge_count, 
  input [2:0] node_a [0:7], 
  input [2:0] node_b [0:7], 
  input [2:0] color [0:7], 
  output reg [7:0] good_nodes, 
  output reg done
);

  typedef enum {IDLE, CHECK_NODE, POP_STACK, PROCESS_EDGE, CHECK_NEXT_NODE, DONE} state_t;
  state_t state;

  reg [2:0] node_counter;
  reg [7:0] good_nodes_reg;
  reg [2:0] stack_ptr;
  reg [5:0] stack [0:7]; // {node, last_color}
  reg [2:0] current_node;
  reg [2:0] current_last_color;
  reg [2:0] edge_index;
  reg found_bad;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      good_nodes <= 8\'b0;
      done <= 1\'b0;
      good_nodes_reg <= 8\'b0;
      stack_ptr <= 3\'b0;
      node_counter <= 3\'b0;
      found_bad <= 1\'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= CHECK_NODE;
            node_counter <= 3\'b0;
            good_nodes_reg <= 8\'b0;
            done <= 1\'b0;
            found_bad <= 1\'b0;
            stack_ptr <= 3\'b0;
          end
        end

        CHECK_NODE: begin
          stack[stack_ptr] <= {node_counter, 3\'b111};
          stack_ptr <= stack_ptr + 1;
          found_bad <= 1\'b0;
          state <= POP_STACK;
        end

        POP_STACK: begin
          if (stack_ptr == 0) begin
            if (!found_bad) good_nodes_reg[node_counter] <= 1\'b1;
            state <= CHECK_NEXT_NODE;
          end else begin
            {current_node, current_last_color} <= stack[stack_ptr - 1];
            stack_ptr <= stack_ptr - 1;
            edge_index <= 0;
            state <= PROCESS_EDGE;
          end
        end

        PROCESS_EDGE: begin
          if (edge_index < edge_count) begin
            if (node_a[edge_index] == current_node) begin
              if (current_last_color == 3\'b111) begin
                if (stack_ptr < 8) begin
                  stack[stack_ptr] <= {node_b[edge_index], color[edge_index]};
                  stack_ptr <= stack_ptr + 1;
                end
              end else if (color[edge_index] == current_last_color) begin
                found_bad <= 1\'b1;
                edge_index <= edge_count;
              end else begin
                if (stack_ptr < 8) begin
                  stack[stack_ptr] <= {node_b[edge_index], color[edge_index]};
                  stack_ptr <= stack_ptr + 1;
                end
              end
            end
            edge_index <= edge_index + 1;
          end else begin
            state <= POP_STACK;
          end
        end

        CHECK_NEXT_NODE: begin
          if (node_counter < 7) begin
            node_counter <= node_counter + 1;
            state <= CHECK_NODE;
          end else begin
            state <= DONE;
          end
        end

        DONE: begin
          good_nodes <= good_nodes_reg;
          done <= 1\'b1;
          if (!start) state <= IDLE;
        end
      endcase
    end
  end

endmodule