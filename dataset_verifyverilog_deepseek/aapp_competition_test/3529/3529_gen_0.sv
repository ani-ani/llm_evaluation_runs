module spanning_tree_k_blue (
  input         clk,
  input         rst_n,
  input         start,
  input  [2:0]  n,
  input  [3:0]  m,
  input  [2:0]  k,
  input  [15:0][7:0] edges,
  output reg     result,
  output reg     done
);
  
  reg [2:0] parent_min [0:7];
  reg [2:0] parent_max [0:7];
  reg [1:0] rank_min [0:7];
  reg [1:0] rank_max [0:7];
  
  reg [3:0] min_blue_order [0:15];
  reg [3:0] max_blue_order [0:15];
  
  reg [3:0] min_blue_count;
  reg [3:0] max_blue_count;
  
  reg [4:0] cycle_count;
  enum {IDLE, PROCESS, DONE} state;
  
  reg [3:0] m_reg;
  reg [3:0] num_red;
  reg [3:0] num_blue;
  
  function automatic [2:0] find_min(input [2:0] x);
    begin
      while (parent_min[x] != x) x = parent_min[x];
      find_min = x;
    end
  endfunction
  
  function automatic [2:0] find_max(input [2:0] x);
    begin
      while (parent_max[x] != x) x = parent_max[x];
      find_max = x;
    end
  endfunction
  
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= IDLE;
      done    <= 0;
      result  <= 0;
      min_blue_count <= 0;
      max_blue_count <= 0;
      cycle_count <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            num_red = 0;
            num_blue = 0;
            for (int i=0; i<16; i++) 
              if (i < m && !edges[i][7]) num_red++;
              else if (i < m) num_blue++;
            
            begin
              automatic int min_r = 0, min_b = num_red;
              automatic int max_b = 0, max_r = num_blue;
              for (int i=0; i<16; i++) begin
                if (i < m) begin
                  if (!edges[i][7]) begin
                    min_blue_order[min_r] = i;
                    min_r++;
                    max_blue_order[max_r] = i;
                    max_r++;
                  end else begin
                    min_blue_order[min_b] = i;
                    min_b++;
                    max_blue_order[max_b] = i;
                    max_b++;
                  end
                end
              end
            end
            
            for (int i=0; i<8; i++) begin
              parent_min[i] = (i < n) ? i[2:0] : 0;
              rank_min[i] = 0;
              parent_max[i] = (i < n) ? i[2:0] : 0;
              rank_max[i] = 0;
            end
            
            min_blue_count <= 0;
            max_blue_count <= 0;
            cycle_count <= 0;
            m_reg <= m;
            done <= 0;
            result <= 0;
            state <= PROCESS;
          end
        end
        
        PROCESS: begin
          if (cycle_count < 31) begin
            if (cycle_count < m_reg) begin
              automatic reg [2:0] root0_min, root1_min, root0_max, root1_max;
              automatic reg [3:0] idx_min = min_blue_order[cycle_count];
              automatic reg [2:0] node0_min = edges[idx_min][2:0];
              automatic reg [2:0] node1_min = edges[idx_min][6:4];
              root0_min = find_min(node0_min);
              root1_min = find_min(node1_min);
              
              if (root0_min != root1_min) begin
                if (rank_min[root0_min] < rank_min[root1_min]) begin
                  parent_min[root0_min] <= root1_min;
                end else if (rank_min[root0_min] > rank_min[root1_min]) begin
                  parent_min[root1_min] <= root0_min;
                end else begin
                  parent_min[root1_min] <= root0_min;
                  rank_min[root0_min] <= rank_min[root0_min] + 1;
                end
                if (edges[idx_min][7]) min_blue_count <= min_blue_count + 1;
              end
              
              automatic reg [3:0] idx_max = max_blue_order[cycle_count];
              automatic reg [2:0] node0_max = edges[idx_max][2:0];
              automatic reg [2:0] node1_max = edges[idx_max][6:4];
              root0_max = find_max(node0_max);
              root1_max = find_max(node1_max);
              
              if (root0_max != root1_max) begin
                if (rank_max[root0_max] < rank_max[root1_max]) begin
                  parent_max[root0_max] <= root1_max;
                end else if (rank_max[root0_max] > rank_max[root1_max]) begin
                  parent_max[root1_max] <= root0_max;
                end else begin
                  parent_max[root1_max] <= root0_max;
                  rank_max[root0_max] <= rank_max[root0_max] + 1;
                end
                if (edges[idx_max][7]) max_blue_count <= max_blue_count + 1;
              end
            end
            
            cycle_count <= cycle_count + 1;
          end else begin
            result <= (k >= min_blue_count) && (k <= max_blue_count);
            done <= 1;
            state <= DONE;
          end
        end
        
        DONE: begin
          done <= 1;
        end
      endcase
    end
  end
endmodule