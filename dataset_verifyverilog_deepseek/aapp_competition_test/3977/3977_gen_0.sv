module max_stable_edges(
  input clk,
  input rst_n,
  input start,
  input [3:0] node_count,
  input [3:0] gov_count,
  input [3:0] gov_list [0:3],
  input [6:0] edge_count,
  input [15:0] edge_mask [0:15],
  output reg [6:0] max_edges,
  output reg done
);
  typedef enum logic [2:0] {
    IDLE,
    COMPONENT_SEARCH,
    SIZE_CALC,
    RESULT_CALC,
    DONE
  } state_t;
  
  state_t state, next_state;
  reg [15:0] visited;
  reg [15:0] stack;
  reg [3:0] gov_idx;
  reg [3:0] component_size [0:3];
  reg [3:0] current_size;
  reg [3:0] stack_ptr;
  reg [5:0] cycle_counter;
  reg [3:0] current_node;
  reg [1:0] component_id [0:15];
  reg [1:0] current_component;
  reg [3:0] largest_size;
  reg [6:0] total_possible;
  reg [6:0] sum_intra_edges;
  reg [3:0] remaining;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      max_edges <= 0;
      gov_idx <= 0;
      cycle_counter <= 0;
      stack_ptr <= 0;
      visited <= 0;
      current_node <= 0;
      current_component <= 0;
      foreach (component_size[i]) component_size[i] <= 0;
      foreach (component_id[i]) component_id[i] <= 2'b11;
      largest_size <= 0;
      total_possible <= 0;
      sum_intra_edges <= 0;
      remaining <= 0;
    end else begin
      cycle_counter <= cycle_counter + 1;
      case(state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= COMPONENT_SEARCH;
            visited <= 0;
            gov_idx <= 0;
            stack_ptr <= 0;
            current_component <= 0;
            cycle_counter <= 0;
          end
        end
        
        COMPONENT_SEARCH: begin
          if (gov_idx < gov_count) begin
            if (!visited[gov_list[gov_idx]]) begin
              visited[gov_list[gov_idx]] <= 1'b1;
              stack[0] <= gov_list[gov_idx];
              stack_ptr <= 1;
              component_id[gov_list[gov_idx]] <= current_component;
              current_node <= gov_list[gov_idx];
              current_size <= 1;
            end
            
            if (stack_ptr > 0) begin
              current_node <= stack[stack_ptr-1];
              stack_ptr <= stack_ptr - 1;
              for (int i=0; i<16; i++) begin
                if ((node_count > i) && edge_mask[current_node][i] && !visited[i]) begin
                  visited[i] <= 1'b1;
                  stack[stack_ptr] <= i;
                  stack_ptr <= stack_ptr + 1;
                  component_id[i] <= current_component;
                  current_size <= current_size + 1;
                end
              end
            end else begin
              component_size[current_component] <= current_size;
              current_component <= current_component + 1;
              gov_idx <= gov_idx + 1;
            end
          end else begin
            state <= SIZE_CALC;
          end
        end
        
        SIZE_CALC: begin
          largest_size <= 0;
          foreach (component_size[i]) begin
            if (component_size[i] > largest_size) largest_size <= component_size[i];
          end
          remaining <= node_count - (
            visited[0] + visited[1] + visited[2] + visited[3] +
            visited[4] + visited[5] + visited[6] + visited[7] +
            visited[8] + visited[9] + visited[10] + visited[11] +
            visited[12] + visited[13] + visited[14] + visited[15]);
          state <= RESULT_CALC;
        end
        
        RESULT_CALC: begin
          total_possible <= 0;
          sum_intra_edges <= 0;
          
          foreach (component_size[i]) begin
            if (component_size[i] > 1)
              total_possible <= total_possible + (component_size[i] * (component_size[i]-1)) / 2;
          end
          total_possible <= total_possible + largest_size * remaining;
          
          for (int i=0; i<15; i++) begin
            for (int j=i+1; j<16; j++) begin
              if (i < node_count && j < node_count && edge_mask[i][j]) begin
                if (component_id[i] == component_id[j] && component_id[i] != 2'b11)
                  sum_intra_edges <= sum_intra_edges + 1;
              end
            end
          end
          
          max_edges <= total_possible - edge_count - sum_intra_edges;
          
          if (cycle_counter >= 34) state <= DONE;
        end
        
        DONE: begin
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule