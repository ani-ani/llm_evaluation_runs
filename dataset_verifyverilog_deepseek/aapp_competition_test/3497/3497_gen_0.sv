module pig_escape_calculator(
  input clk,
  input rst_n,
  input start,
  input [2:0] v,
  input [2:0] p,
  input [31:0] edges_vec,
  input [23:0] pigs_vec,
  input [23:0] wolves_vec,
  output reg [2:0] result,
  output reg done
);

  reg [4:0] cycle_cnt;
  reg [7:0] adj_list [0:7];
  reg [7:0] pig_nodes;
  reg [7:0] wolf_nodes;
  reg [7:0] leaf_nodes;
  reg [7:0] animal_nodes;
  
  // Path storage for pigs (8 pigs max, 8 paths each, 8-bit masks)
  reg [7:0] pig_paths [0:7][0:7];
  reg [2:0] num_paths [0:7];
  
  // Algorithm state
  reg [2:0] k;
  reg [7:0] cur_set;
  reg [3:0] pig_idx;
  reg found;
  reg [2:0] best_result;
  
  // Generate adjacency list
  always @(posedge clk) begin
    if (!rst_n) begin
      cycle_cnt <= 0;
      done <= 0;
      result <= 0;
      for (int i=0; i<8; i++) adj_list[i] <= 0;
    end else if (start) begin
      if (cycle_cnt < 24) cycle_cnt <= cycle_cnt + 1;
      
      case (cycle_cnt)
        // Cycle 0: Parse edges
        0: begin
          for (int i=0; i<8; i++) begin
            if (i < v) begin
              adj_list[edges_vec[i*4 +:3]] |= (1 << edges_vec[i*4+3 +:3]);
              adj_list[edges_vec[i*4+3 +:3]] |= (1 << edges_vec[i*4 +:3]);
            end
          end
          
          for (int i=0; i<8; i++) begin
            pig_nodes[i] <= |(pigs_vec >> (i*3) & 7);
            wolf_nodes[i] <= (|pigs_vec) ? (|(wolves_vec >> (i*3) & 7)) : 0;
          end
          animal_nodes <= pig_nodes | wolf_nodes;
        end
        
        // Cycle 1: Find leaf nodes
        1: begin
          for (int i=0; i<8; i++) begin
            leaf_nodes[i] <= ($countones(adj_list[i]) == 1) && (i < v);
          end
          for (int i=0; i<8; i++) num_paths[i] <= 0;
          pig_idx <= 0;
        end
        
        // Cycles 2-9: Build paths per pig
        default: if (cycle_cnt >= 2 && cycle_cnt <= 9) begin
          if (pig_nodes[pig_idx] && num_paths[pig_idx] < p) begin
            // Simplified: Record wolf nodes in adjacency list for this pig
            pig_paths[pig_idx][num_paths[pig_idx]] <= adj_list[pig_idx] & ~pig_nodes;
            num_paths[pig_idx] <= num_paths[pig_idx] + 1;
          end
          pig_idx <= pig_idx + 1;
        end
        
        // Cycles 10-24: Check removal sets
        10: begin
          k <= 0;
          cur_set <= 0;
          best_result <= 3'd8;
        end
        
        default: if (cycle_cnt >10 && cycle_cnt<24) begin
          found <= 1;
          for (int i=0; i<p; i++) begin
            if (pig_nodes[i]) begin
              reg path_found;
              path_found = 0;
              for (int j=0; j<num_paths[i]; j++) begin
                if ((pig_paths[i][j] & cur_set) == pig_paths[i][j]) path_found = 1;
              end
              if (!path_found) found <= 0;
            end
          end
          
          if (found) best_result = k;
          
          // Increment set
          if (cur_set != 8'hff) cur_set <= cur_set + 1;
          else begin
            k <= k + 1;
            cur_set <= (1 << k) -1;
          end
        end
        
        24: begin
          result <= best_result;
          done <= 1;
        end
      endcase
    end
  end

  function automatic integer countones(input [7:0] x);
    countones = 0;
    for (int i=0; i<8; i++) countones += x[i];
  endfunction
endmodule