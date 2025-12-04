module max_university_pairs(
  input clk,                 
  input rst_n,               
  input start,               
  input [2:0] node_count,    
  input [7:0] univ_mask,     
  input [7:0][2:0] adj_list, 
  output reg [4:0] max_sum,  
  output reg done            
);

  // State machine declarations
  enum logic [2:0] {IDLE, TRAVERSE, COUNT_SUBTREES, CALC_SUM, FINISH} state;

  // Internal registers
  reg [2:0] parent [0:7];
  reg [2:0] subtree_count [0:7];
  reg [7:0] visited;
  reg [2:0] bfs_queue [0:7];
  reg [2:0] front_ptr, rear_ptr;
  reg [2:0] current_node;
  reg bfs_done;
  reg [2:0] total_uni;
  reg [2:0] process_ctr;
  reg [2:0] calc_ctr;

  // Combinational population count
  always_comb begin
    total_uni = '0;
    for (int i=0; i<8; i++)
      if (i < node_count) total_uni += univ_mask[i];
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done <= 0;
      max_sum <= 0;
      bfs_done <= 0;
      front_ptr <= 0;
      rear_ptr <= 0;
      visited <= 0;
      process_ctr <= 0;
      calc_ctr <= 0;
      foreach(parent[i]) parent[i] <= 3'h7;
      foreach(subtree_count[i]) subtree_count[i] <= 0;
      foreach(bfs_queue[i]) bfs_queue[i] <= 0;
    end else begin
      case(state)
        IDLE: begin
          done <= 0;
          if (start) begin
            state <= TRAVERSE;
            visited <= 0;
            bfs_queue[0] <= 3'h0;
            visited[0] <= 1'b1;
            front_ptr <= 0;
            rear_ptr <= 1;
            bfs_done <= 0;
          end
        end

        TRAVERSE: begin
          if (front_ptr != rear_ptr) begin
            current_node <= bfs_queue[front_ptr];
            front_ptr <= front_ptr + 1;
          end else begin
            bfs_done <= 1;
          end

          if (!bfs_done) begin
            for (int i=0; i<8; i++) begin
              if (adj_list[current_node][i] < node_count && 
                  !visited[adj_list[current_node][i]]) begin
                visited[adj_list[current_node][i]] <= 1'b1;
                parent[adj_list[current_node][i]] <= current_node;
                bfs_queue[rear_ptr] <= adj_list[current_node][i];
                rear_ptr <= rear_ptr + 1;
              end
            end
          end else begin
            state <= COUNT_SUBTREES;
            process_ctr <= node_count - 1;
            foreach(subtree_count[i])
              subtree_count[i] <= (i < node_count) ? {2'b0, univ_mask[i]} : 0;
          end
        end

        COUNT_SUBTREES: begin
          if (process_ctr > 0) begin
            if (parent[process_ctr] != 3'h7)  // Skip root
              subtree_count[parent[process_ctr]] <= 
                subtree_count[parent[process_ctr]] + subtree_count[process_ctr];
            process_ctr <= process_ctr - 1;
          end else begin
            state <= CALC_SUM;
            calc_ctr <= 1;  // Start from first non-root node
            max_sum <= 0;
          end
        end

        CALC_SUM: begin
          if (calc_ctr < node_count) begin
            if (parent[calc_ctr] != 3'h7) begin
              automatic logic [2:0] cnt = subtree_count[calc_ctr];
              max_sum <= max_sum + (cnt < (total_uni - cnt) ? cnt : (total_uni - cnt));
            end
            calc_ctr <= calc_ctr + 1;
          end else begin
            state <= FINISH;
          end
        end

        FINISH: begin
          done <= 1'b1;
          state <= IDLE;
        end
      endcase
    end
  end
endmodule