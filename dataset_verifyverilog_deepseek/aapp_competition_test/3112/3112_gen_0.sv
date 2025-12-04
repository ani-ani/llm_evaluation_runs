module conveyor_scheduler (
  input clk,
  input rst_n,
  input start,
  input [2:0] N,
  input [1:0] K,
  input [3:0] M,
  input [15:0][5:0] edges,
  output reg [1:0] max_producers,
  output reg done
);
  localparam IDLE = 3'd0;
  localparam FIND_PATHS = 3'd1;
  localparam CHECK_CONFLICTS = 3'd2;
  localparam CALC_RESULT = 3'd3;
  localparam DONE = 3'd4;

  reg [2:0] state, next_state;
  reg [1:0] producer_idx;
  reg [2:0] bfs_step;
  reg found_N;
  reg [7:0] visited;
  reg [7:0] queue;
  reg [2:0] current_u;
  reg reconstructing;
  reg [2:0] path_step;
  reg [2:0] start_node;
  reg [2:0] current_node;
  reg [3:0] belt_path [0:6];
  reg [2:0] parent_node[0:7];
  reg [3:0] parent_belt[0:7];
  reg [2:0] producer_path_length[0:3];
  reg [3:0] producer_belts[0:3][0:6];
  reg [3:0] belt_time_masks[0:15][0:3];
  reg [3:0] conflict_matrix [0:3];
  reg [3:0] i, j;
  reg [3:0] bid;

  function automatic [1:0] count_ones;
    input [3:0] x;
    count_ones = x[0] + x[1] + x[2] + x[3];
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      state <= IDLE;
      producer_idx <= 0;
      done <= 0;
      max_producers <= 0;
      for (bid=0; bid<16; bid=bid+1)
        for (j=0; j<4; j=j+1)
          belt_time_masks[bid][j] <= 0;
      for (i=0; i<4; i=i+1) conflict_matrix[i] <= 4'b0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= FIND_PATHS;
            producer_idx <= 0;
            bfs_step <= 0;
            reconstructing <= 0;
            done <= 0;
            max_producers <= 0;
            for (bid=0; bid<16; bid=bid+1)
              for (j=0; j<4; j=j+1)
                belt_time_masks[bid][j] <= 0;
          end
        end

        FIND_PATHS: begin
          if (!reconstructing) begin
            if (bfs_step == 0) begin
              start_node = producer_idx + 1;
              visited <= 8'b0;
              queue <= 8'b0;
              found_N <= 0;
              if (producer_idx < K) begin
                visited[start_node] <= 1'b1;
                queue[start_node] <= 1'b1;
                parent_node[start_node] <= 3'b111;
                parent_belt[start_node] <= 0;
              end
              bfs_step <= 1;
            end else if (found_N || queue == 0) begin
              if (found_N) begin
                reconstructing <= 1;
                path_step <= 0;
                current_node <= N;
              end else if (producer_idx + 1 >= K) state <= CHECK_CONFLICTS;
              else begin
                producer_idx <= producer_idx + 1;
                bfs_step <= 0;
              end
            end else begin
              for (i=0; i<8; i=i+1)
                if (queue[i]) current_u = i;
              queue[current_u] <= 1'b0;
              if (current_u == N) begin
                found_N <= 1;
              end else begin
                for (bid=0; bid<16; bid=bid+1) begin
                  reg [2:0] a = edges[bid][5:3];
                  reg [2:0] b = edges[bid][2:0];
                  reg [2:0] v;
                  v = (a == current_u) ? b : (b == current_u) ? a : 3'b111;
                  if (v != 3'b111 && !visited[v]) begin
                    visited[v] <= 1'b1;
                    queue[v] <= 1'b1;
                    parent_node[v] <= current_u;
                    parent_belt[v] <= bid;
                  end
                end
              end
              bfs_step <= bfs_step + 1;
            end
          end else begin
            if (current_node == start_node) begin
              producer_path_length[producer_idx] <= path_step;
              for (i=0; i<path_step; i=i+1) begin
                reg [3:0] belt_id = belt_path[i];
                reg [1:0] t_slot = (producer_idx + i) % K;
                belt_time_masks[belt_id][producer_idx] <= belt_time_masks[belt_id][producer_idx] | (1 << t_slot);
              end
              reconstructing <= 0;
              bfs_step <= 0;
              if (producer_idx + 1 >= K) state <= CHECK_CONFLICTS;
              else producer_idx <= producer_idx + 1;
            end else begin
              reg [3:0] pb = parent_belt[current_node];
              belt_path[path_step] <= pb;
              path_step <= path_step + 1;
              current_node <= parent_node[current_node];
            end
          end
        end

        CHECK_CONFLICTS: begin
          for (i=0; i<4; i=i+1) conflict_matrix[i] <= 4'b0;
          for (bid=0; bid<16; bid=bid+1) begin
            for (i=0; i<4; i=i+1) begin
              for (j=i+1; j<4; j=j+1) begin
                if (belt_time_masks[bid][i] & belt_time_masks[bid][j]) begin
                  conflict_matrix[i][j] <= 1'b1;
                  conflict_matrix[j][i] <= 1'b1;
                end
              end
            end
          end
          state <= CALC_RESULT;
        end

        CALC_RESULT: begin
          reg [1:0] max_val = 0;
          for (bid=15; bid>0; bid=bid-1) begin
            if (bid <= (1 << K) -1) begin
              reg [1:0] ones = count_ones(bid);
              if (ones > max_val) begin
                reg conflict_found = 0;
                for (i=0; i<4; i=i+1) begin
                  for (j=i+1; j<4; j=j+1) begin
                    if (bid[i] && bid[j] && conflict_matrix[i][j]) conflict_found = 1;
                  end
                end
                if (!conflict_found) max_val = ones;
              end
            end
          end
          max_producers <= max_val;
          state <= DONE;
        end

        DONE: begin
          done <= 1'b1;
        end
      endcase
    end
  end
endmodule