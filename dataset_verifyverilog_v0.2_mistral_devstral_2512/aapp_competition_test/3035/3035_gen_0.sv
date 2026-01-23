module lemonade_trade (
  input clk,
  input rst_n,
  input start,
  input [4:0] num_nodes,
  input [4:0] num_edges,
  input [2:0] pink_idx,
  input [2:0] blue_idx,
  input [15:0] edge_start [15:0],
  input [15:0] edge_end [15:0],
  input [31:0] edge_rate [15:0],
  output reg [31:0] max_blue,
  output reg done
);

  // State definitions
  typedef enum logic [3:0] {
    IDLE,
    INIT,
    PROCESSING,
    CAP_CHECK,
    DONE
  } state_t;

  state_t state;
  reg [31:0] current_max;
  reg [31:0] current_product;
  reg [2:0] current_node;
  reg [7:0] visited [7:0];
  reg [4:0] edge_counter;
  reg [4:0] node_counter;
  reg [4:0] cycle_counter;

  // Fixed-point constants
  parameter Q16_16_ONE = 32'h00010000;
  parameter Q16_16_TEN = 32'h000A0000;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      max_blue <= 32'h00000000;
      done <= 1'b0;
      current_max <= 32'h00000000;
      current_product <= 32'h00000000;
      current_node <= 3'b000;
      edge_counter <= 5'b00000;
      node_counter <= 5'b00000;
      cycle_counter <= 5'b00000;
      for (int i = 0; i < 8; i++) begin
        visited[i] <= 8'h00;
      end
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= INIT;
            done <= 1'b0;
            current_max <= 32'h00000000;
            current_product <= Q16_16_ONE;
            current_node <= pink_idx;
            edge_counter <= 5'b00000;
            node_counter <= 5'b00000;
            cycle_counter <= 5'b00000;
            for (int i = 0; i < 8; i++) begin
              visited[i] <= 8'h00;
            end
          end
        end

        INIT: begin
          state <= PROCESSING;
          visited[pink_idx] <= 1'b1;
        end

        PROCESSING: begin
          if (cycle_counter == 5'd100) begin
            state <= CAP_CHECK;
          end else if (current_node == blue_idx) begin
            // Found a path to blue, update max
            if (current_product > current_max) begin
              current_max <= current_product;
            end
            // Backtrack to find other paths
            state <= PROCESSING;
            edge_counter <= edge_counter - 1'b1;
            current_node <= edge_start[edge_counter];
            current_product <= current_product / edge_rate[edge_counter];
            visited[current_node] <= 1'b0;
          end else begin
            // Find next edge to traverse
            reg found_edge = 1'b0;
            for (int i = 0; i < num_edges; i++) begin
              if (edge_start[i] == current_node && !visited[edge_end[i]]) begin
                found_edge = 1'b1;
                edge_counter <= i;
                current_node <= edge_end[i];
                current_product <= current_product * edge_rate[i];
                visited[current_node] <= 1'b1;
                break;
              end
            end

            if (!found_edge) begin
              // No more edges from current node, backtrack
              if (edge_counter > 0) begin
                edge_counter <= edge_counter - 1'b1;
                current_node <= edge_start[edge_counter];
                current_product <= current_product / edge_rate[edge_counter];
                visited[current_node] <= 1'b0;
              end else begin
                // All paths explored
                state <= CAP_CHECK;
              end
            end
            cycle_counter <= cycle_counter + 1'b1;
          end
        end

        CAP_CHECK: begin
          if (current_max > Q16_16_TEN) begin
            max_blue <= Q16_16_TEN;
          end else begin
            max_blue <= current_max;
          end
          state <= DONE;
        end

        DONE: begin
          done <= 1'b1;
          if (!start) begin
            state <= IDLE;
          end
        end

        default: begin
          state <= IDLE;
        end
      endcase
    end
  end

endmodule