module secure_telecom_network (
  input clk,                   
  input rst_n,                 
  input start,                 
  input [2:0] num_buildings,   
  input [3:0] num_edges,       
  input [2:0] num_insecure,    
  input [7:0] insecure_mask,   
  input [2:0] edge_src[0:15], 
  input [2:0] edge_dst[0:15],
  input [15:0] edge_cost[0:15],
  output reg [15:0] total_cost,
  output reg done              
);
  
  typedef enum reg [2:0] {IDLE = 3'b000, SORT = 3'b001, PROCESS = 3'b010, VALIDATE = 3'b011, DONE = 3'b100} state_t;
  reg [2:0] state, next_state;
  
  reg [2:0] sorted_src[0:15];
  reg [2:0] sorted_dst[0:15];
  reg [15:0] sorted_cost[0:15];
  
  reg [3:0] sort_i, sort_j;
  reg [3:0] process_idx;
  reg [2:0] valid_idx;
  
  reg [15:0] total_cost_reg;
  reg done_reg;
  
  reg [2:0] parent[0:7];
  reg [3:0] degree[0:7];
  
  reg [2:0] u, v;
  reg [2:0] fu, fv;
  reg [15:0] temp_cost;
  reg [2:0] temp_src, temp_dst;
  
  reg valid_error;
  reg [2:0] valid_root;
  reg [3:0] edge_count;
  
  function automatic [2:0] find(input [2:0] node);
    begin
      find = node;
      while (parent[find] != find) begin
        find = parent[find];
      end
    end
  endfunction
  
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      done_reg <= 0;
      total_cost_reg <= 16'hFFFF;
      valid_error <= 0;
      sort_i <= 0;
      sort_j <= 0;
      process_idx <= 0;
      valid_idx <= 0;
      edge_count <= 0;
      for (int i=0; i<16; i=i+1) begin
        sorted_src[i] <= 0;
        sorted_dst[i] <= 0;
        sorted_cost[i] <= 0;
      end
      for (int i=0; i<8; i=i+1) begin
        parent[i] <= 0;
        degree[i] <= 0;
      end
    end
    else begin
      case(state)
        IDLE: begin
          done_reg <= 0;
          total_cost_reg <= 16'hFFFF;
          edge_count <= 0;
          if (start) begin
            for (int i=0; i<num_edges; i=i+1) begin
              sorted_src[i] <= edge_src[i];
              sorted_dst[i] <= edge_dst[i];
              sorted_cost[i] <= edge_cost[i];
            end
            for (int i=0; i<8; i=i+1) begin
              parent[i] <= i;
              degree[i] <= 0;
            end
            sort_i <= 1;
            sort_j <= 1;
            state <= SORT;
          end
        end
        
        SORT: begin
          if (sort_i < num_edges) begin
            if (sort_j > 0 && sorted_cost[sort_j] < sorted_cost[sort_j-1]) begin
              temp_src = sorted_src[sort_j];
              temp_dst = sorted_dst[sort_j];
              temp_cost = sorted_cost[sort_j];
              sorted_src[sort_j] <= sorted_src[sort_j-1];
              sorted_dst[sort_j] <= sorted_dst[sort_j-1];
              sorted_cost[sort_j] <= sorted_cost[sort_j-1];
              sorted_src[sort_j-1] <= temp_src;
              sorted_dst[sort_j-1] <= temp_dst;
              sorted_cost[sort_j-1] <= temp_cost;
              sort_j <= sort_j - 1;
            end
            else begin
              sort_i <= sort_i + 1;
              sort_j <= sort_i;
            end
          end
          else begin
            state <= PROCESS;
            process_idx <= 0;
            total_cost_reg <= 0;
          end
        end
        
        PROCESS: begin
          if (process_idx < num_edges) begin
            u = sorted_src[process_idx];
            v = sorted_dst[process_idx];
            fu = find(u);
            fv = find(v);
            if (fu != fv) begin
              if ((!insecure_mask[u] || degree[u] == 0) && (!insecure_mask[v] || degree[v] == 0)) begin
                parent[fv] <= fu;
                degree[u] <= degree[u] + 1;
                degree[v] <= degree[v] + 1;
                total_cost_reg <= total_cost_reg + sorted_cost[process_idx];
                edge_count <= edge_count + 1;
              end
            end
            process_idx <= process_idx + 1;
          end
          else begin
            state <= VALIDATE;
            valid_idx <= 0;
            valid_root <= find(0);
            valid_error <= 0;
          end
        end
        
        VALIDATE: begin
          if (edge_count != num_buildings - 1) begin
            valid_error <= 1;
          end
          if (valid_idx < num_buildings) begin
            if (find(valid_idx) != valid_root) begin
              valid_error <= 1;
            end
            if (insecure_mask[valid_idx]) begin
              if (degree[valid_idx] != 1) valid_error <= 1;
            end
            else begin
              if (degree[valid_idx] < 1) valid_error <= 1;
            end
            valid_idx <= valid_idx + 1;
          end
          else begin
            state <= DONE;
            if (valid_error) begin
              total_cost_reg <= 16'hFFFF;
            end
            done_reg <= 1;
          end
        end
        
        DONE: begin
          done_reg <= 1;
          if (start) begin
            state <= IDLE;
            done_reg <= 0;
          end
        end
      endcase
    end
  end
  
  assign done = done_reg;
  assign total_cost = total_cost_reg;
  
endmodule