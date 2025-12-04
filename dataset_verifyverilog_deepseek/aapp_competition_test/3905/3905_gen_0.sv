module min_data_centers (
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [3:0] m,
  input [2:0] h,
  input [7:0][2:0] u_array,
  input [15:0][5:0] client_pairs,
  output reg [2:0] k,
  output reg [7:0] solution_set,
  output reg done,
  output reg valid
);

  // State encoding
  typedef enum {
    IDLE,
    BUILD_GRAPH,
    FIND_SCCS,
    CALC_OUTDEG,
    SELECT_SCC,
    DONE
  } state_t;

  state_t state, next_state;
  reg [7:0] cycle_cnt;
  reg [7:0][7:0] adj_matrix, trans_matrix;
  reg [7:0] visited_first, visited_second;
  reg [2:0] finish_order [7:0];
  reg [2:0] finish_idx;
  reg [7:0] scc_masks [7:0];
  reg [2:0] scc_sizes [7:0];
  reg [7:0] scc_outdeg;
  reg [2:0] scc_count;
  reg [7:0] stack;
  reg [2:0] stack_ptr;
  reg [2:0] curr_node;
  reg [2:0] search_idx;
  reg [2:0] min_scc_idx;
  reg [2:0] i, j;
  reg [2:0] build_i, build_j;
  reg direction;

  // Sequential block
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      valid <= 0;
      k <= 0;
      solution_set <= 0;
      cycle_cnt <= 0;
      for (int i=0; i<8; i++) begin
        adj_matrix[i] <= 0;
        trans_matrix[i] <= 0;
        scc_masks[i] <= 0;
        finish_order[i] <= 0;
      end
    end else begin
      cycle_cnt <= (start & (state == IDLE)) ? 8'd1 :
                  (cycle_cnt != 0) ? cycle_cnt + 1 : 0;
      state <= next_state;

      case (state)
        IDLE: begin
          if (start) begin
            next_state <= BUILD_GRAPH;
            build_i <= 0;
            build_j <= 0;
          end
          done <= 0;
          valid <= 0;
        end

        BUILD_GRAPH: begin
          if (build_i < n) begin
            if (build_j < n) begin
              adj_matrix[build_i][build_j] <= ((u_array[build_i] + 1) % h == u_array[build_j]);
              trans_matrix[build_j][build_i] <= adj_matrix[build_i][build_j];
              build_j <= build_j + 1;
            end else begin
              build_j <= 0;
              build_i <= build_i + 1;
            end
          end else begin
            next_state <= FIND_SCCS;
            visited_first <= 0;
            finish_idx <= 0;
            curr_node <= 0;
            stack <= 0;
            stack_ptr <= 0;
            direction <= 0;
          end
        end

        FIND_SCCS: begin
          if (!direction) begin  // First DFS pass (original graph)
            if (stack_ptr == 0) begin
              if (curr_node < n) begin
                if (!visited_first[curr_node]) begin
                  stack[stack_ptr] <= curr_node;
                  stack_ptr <= stack_ptr + 1;
                  visited_first[curr_node] <= 1;
                end
                curr_node <= curr_node + 1;
              end else begin
                // Switch to second DFS pass
                direction <= 1;
                visited_second <= 0;
                curr_node <= finish_idx - 1;
                scc_count <= 0;
                stack_ptr <= 0;
              end
            end else begin
              // DFS exploration
              if (search_idx < n) begin
                if (adj_matrix[stack[stack_ptr-1]][search_idx] && 
                    !visited_first[search_idx]) begin
                  stack[stack_ptr] <= search_idx;
                  stack_ptr <= stack_ptr + 1;
                  visited_first[search_idx] <= 1;
                end
                search_idx <= search_idx + 1;
              end else begin
                // Node processing complete
                finish_order[finish_idx] <= stack[stack_ptr-1];
                finish_idx <= finish_idx + 1;
                stack_ptr <= stack_ptr - 1;
                search_idx <= 0;
              end
            end
          end else begin          // Second DFS pass (transposed graph)
            if (stack_ptr == 0) begin
              if (curr_node >= 0 && scc_count < 8) begin
                if (!visited_second[finish_order[curr_node]]) begin
                  stack[stack_ptr] <= finish_order[curr_node];
                  stack_ptr <= stack_ptr + 1;
                  visited_second[finish_order[curr_node]] <= 1;
                  scc_masks[scc_count] <= (1 << finish_order[curr_node]);
                end
                curr_node <= curr_node - 1;
              end else begin
                next_state <= CALC_OUTDEG;
                i <= 0;
                j <= 0;
              end
            end else begin
              // SCC formation
              if (search_idx < n) begin
                if (trans_matrix[stack[stack_ptr-1]][search_idx] && 
                    !visited_second[search_idx]) begin
                  stack[stack_ptr] <= search_idx;
                  stack_ptr <= stack_ptr + 1;
                  visited_second[search_idx] <= 1;
                  scc_masks[scc_count] <= scc_masks[scc_count] | (1 << search_idx);
                end
                search_idx <= search_idx + 1;
              end else begin
                stack_ptr <= stack_ptr - 1;
                search_idx <= 0;
                if (stack_ptr == 1) begin // SCC complete
                  scc_sizes[scc_count] <= $countones(scc_masks[scc_count]);
                  scc_count <= scc_count + 1;
                end
              end
            end
          end
        end

        CALC_OUTDEG: begin
          if (i < scc_count) begin
            scc_outdeg[i] <= 0;
            for (int k=0; k<n; k++) begin
              if (scc_masks[i][k]) begin
                for (int l=0; l<n; l++) begin
                  if (adj_matrix[k][l] && !scc_masks[i][l]) begin
                    scc_outdeg[i] <= 1;
                  end
                end
              end
            end
            i <= i + 1;
            next_state <= CALC_OUTDEG;
          end else begin
            next_state <= SELECT_SCC;
            min_scc_idx <= 8;
          end
        end

        SELECT_SCC: begin
          if (i < scc_count) begin
            if (!scc_outdeg[i] && 
                (min_scc_idx == 8 || scc_sizes[i] < scc_sizes[min_scc_idx])) begin
              min_scc_idx <= i;
            end
            i <= i + 1;
          end else begin
            next_state <= DONE;
          end
        end

        DONE: begin
          done <= 1;
          valid <= (min_scc_idx != 8);
          k <= (min_scc_idx != 8) ? scc_sizes[min_scc_idx] : 0;
          solution_set <= (min_scc_idx != 8) ? scc_masks[min_scc_idx] : 0;
          if (cycle_cnt == 255) next_state <= IDLE;
        end
      endcase
    end
  end

endmodule