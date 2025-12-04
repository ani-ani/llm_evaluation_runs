module max_box_piles(
  input clk,
  input rst_n,
  input start,
  input [2:0] n,
  input [5:0] a [0:7],
  output reg [31:0] result,
  output reg done
);

  localparam MOD = 32'd1000000007;
  localparam IDLE = 3'd0, BUILD_GRAPH = 3'd1, FIND_WCC = 3'd2, DP_START = 3'd3, DP_PROCESS = 3'd4, COMBINE = 3'd5, DONE_STATE = 3'd6;

  reg [2:0] state;
  reg [7:0] adj_matrix [0:7];
  reg [7:0] visited;
  reg [2:0] component_id [0:7];
  reg [2:0] wcc_sizes [0:7];
  reg [7:0] dfs_stack [0:7];
  reg [3:0] stack_ptr;
  reg [2:0] max_length;
  reg [31:0] count_temp, total_count;
  reg [2:0] current_node, wcc_idx, node_idx;
  reg [31:0] factorial [0:8];
  reg [2:0] cycle_counter;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      result <= 32'd0;
      state <= IDLE;
      visited <= 8'd0;
      stack_ptr <= 4'd0;
      count_temp <= 32'd0;
      total_count <= 32'd0;
      wcc_idx <= 3'd0;
      current_node <= 3'd0;
      cycle_counter <= 3'd0;
      for (int i=0; i<8; i=i+1) begin
        component_id[i] <= 3'd0;
        wcc_sizes[i] <= 3'd0;
      end
    end else begin
      case (state)
        IDLE: begin
          done <= 1'b0;
          result <= 32'd0;
          if (start) begin
            state <= BUILD_GRAPH;
            visited <= 8'd0;
            stack_ptr <= 4'd0;
            count_temp <= 32'd0;
            total_count <= 32'd1;
            wcc_idx <= 3'd0;
            cycle_counter <= 3'd0;
            for (int i=0; i<8; i=i+1) begin
              wcc_sizes[i] <= 3'd0;
              component_id[i] <= 3'd0;
            end
          end
        end

        BUILD_GRAPH: begin
          for (int i=0; i<8; i=i+1) begin
            for (int j=0; j<8; j=j+1) begin
              if (i==j) adj_matrix[i][j] <= 1'b0;
              else adj_matrix[i][j] <= (a[i]!=0 && a[j]!=0) && ((a[i]%a[j]==0) || (a[j]%a[i]==0));
            end
          end
          state <= FIND_WCC;
          current_node <= 3'd0;
        end

        FIND_WCC: begin
          if (current_node < 3'd8) begin
            if (!visited[current_node]) begin
              visited[current_node] <= 1'b1;
              dfs_stack[stack_ptr] <= current_node;
              stack_ptr <= stack_ptr + 1;
              component_id[current_node] <= wcc_idx;
              wcc_sizes[wcc_idx] <= wcc_sizes[wcc_idx] + 1;
              state <= DP_START;
            end else begin
              current_node <= current_node + 1;
            end
          end else begin
            state <= COMBINE;
          end
        end

        DP_START: begin
          if (stack_ptr > 0) begin
            stack_ptr <= stack_ptr - 1;
            node_idx <= dfs_stack[stack_ptr-1];
            for (int i=0; i<8; i=i+1) begin
              if (adj_matrix[node_idx][i] && !visited[i]) begin
                visited[i] <= 1'b1;
                dfs_stack[stack_ptr] <= i;
                stack_ptr <= stack_ptr + 1;
                component_id[i] <= wcc_idx;
                wcc_sizes[wcc_idx] <= wcc_sizes[wcc_idx] + 1;
              end
            end
          end else begin
            wcc_idx <= wcc_idx + 1;
            state <= FIND_WCC;
            current_node <= current_node + 1;
          end
        end

        COMBINE: begin
          factorial[0] <= 32'd1;
          for (int i=1; i<=8; i=i+1) begin
            factorial[i] <= (factorial[i-1] * i) % MOD;
          end
          state <= DONE_STATE;
          for (int i=0; i<8; i=i+1) begin
            if (wcc_sizes[i] > 0) begin
              total_count <= (total_count * factorial[wcc_sizes[i]]) % MOD;
            end
          end
        end

        DONE_STATE: begin
          result <= total_count % MOD;
          done <= 1'b1;
          state <= IDLE;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule