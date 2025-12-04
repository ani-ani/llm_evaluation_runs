module evolution_validator(
  input clk,
  input rst_n,
  input start,
  input [15:0] current_seq,
  input [7:0][15:0] fossil_seqs,
  input [3:0] num_fossils,
  output reg possible,
  output reg [3:0] s1,
  output reg [3:0] s2,
  output reg [7:0] path1_mask,
  output reg [7:0] path2_mask,
  output reg done
);

  typedef enum logic [2:0] { IDLE, PREPARE, CHECK_PATHS, DONE } state_t;
  state_t state;

  reg [3:0] lengths [0:7];
  reg [7:0] valid;
  reg [7:0][7:0] can_reach;
  reg [7:0] direct_parent;
  reg [7:0] is_parent_matrix [0:7];
  reg [2:0] fossil_i, fossil_j;
  reg [3:0] cycle_count;
  reg [7:0] temp_path1, temp_path2;
  reg [3:0] count1, count2;
  reg resolving;

  function automatic [3:0] calc_length(input [15:0] seq);
    integer i;
    calc_length = 0;
    for (i=0; i<8; i=i+1) begin
      if (seq[15-2*i -:2] != 2'b11) calc_length = calc_length + 1;
    end
  endfunction

  function automatic bit is_parent(input [15:0] par, input [15:0] child);
    integer pl, cl, i, j;
    bit match;
    pl = calc_length(par);
    cl = calc_length(child);
    is_parent = 0;
    if (pl + 1 != cl) return 0;
    
    for (i=0; i<cl; i=i+1) begin
      match = 1;
      j = 0;
      for (integer c=0; c<cl; c=c+1) begin
        if (c == i) continue;
        if (child[15-2*c -:2] != par[15-2*j -:2]) begin
          match = 0;
          break;
        end
        j = j+1;
      end
      if (match) begin
        is_parent = 1;
        break;
      end
    end
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state <= IDLE;
      possible <= 0;
      done <= 0;
      s1 <= 0;
      s2 <= 0;
      path1_mask <= 0;
      path2_mask <= 0;
      cycle_count <= 0;
      temp_path1 <= 0;
      temp_path2 <= 0;
      resolving <= 0;
      count1 <= 0;
      count2 <= 0;
    end else begin
      case (state)
        IDLE: begin
          if (start) begin
            state <= PREPARE;
            cycle_count <= 0;
            fossil_i <= 0;
          end else begin
            done <= 0;
          end
        end

        PREPARE: begin
          // Calculate lengths
          if (fossil_i < 8) begin
            if (fossil_i < num_fossils) begin
              lengths[fossil_i] <= calc_length(fossil_seqs[fossil_i]);
              direct_parent[fossil_i] <= is_parent(fossil_seqs[fossil_i], current_seq);
            end else begin
              lengths[fossil_i] <= 0;
              direct_parent[fossil_i] <= 0;
            end
            fossil_i <= fossil_i + 1;
          end else begin
            fossil_i <= 0;
            fossil_j <= 0;
            valid <= 0;
            can_reach <= '{default: 0};
            for (int k=0; k<8; k=k+1) begin
              if (k < num_fossils) begin
                if (direct_parent[k]) begin
                  valid[k] <= 1;
                  can_reach[k][lengths[k]] <= 1;
                end
              end
            end
            state <= CHECK_PATHS;
          end
        end

        CHECK_PATHS: begin
          // Dynamic programming for reachability
          for (int l=0; l<8; l=l+1) begin
            for (int p=0; p<8; p=p+1) begin
              if (p < num_fossils && valid[p] && lengths[p] == l && !can_reach[p][7] && l < 7) begin
                for (int q=0; q<8; q=q+1) begin
                  if (q < num_fossils && valid[q] && lengths[q] == l+1 && can_reach[q][7] && 
                      is_parent(fossil_seqs[p], fossil_seqs[q])) begin
                    can_reach[p] <= can_reach[p] | can_reach[q];
                    if (can_reach[p][7]) valid[p] <= 1;
                  end
                end
              end
            end
          end
          
          cycle_count <= cycle_count + 1;
          if (cycle_count == 8) begin
            // Check for possible paths
            resolving <= 1;
            fossil_i <= 0;
            temp_path1 <= 0;
            temp_path2 <= 0;
            count1 <= 0;
            count2 <= 0;
            possible <= 0;
          end
          
          if (resolving) begin
            // Try to merge fossils into two paths
            if (fossil_i < 8) begin
              if (fossil_i < num_fossils && valid[fossil_i]) begin
                reg conflict;
                conflict = (temp_path1[fossil_i] || temp_path2[fossil_i]);
                if (can_reach[fossil_i][7] && !conflict) begin
                  if (!temp_path1) begin
                    temp_path1 <= temp_path1 | (1 << fossil_i);
                    count1 <= count1 + 1;
                  end else if (!temp_path2) begin
                    temp_path2 <= temp_path2 | (1 << fossil_i);
                    count2 <= count2 + 1;
                  end else begin
                    possible <= 1;
                  end
                end
                fossil_i <= fossil_i + 1;
              end else begin
                fossil_i <= fossil_i + 1;
              end
            end else begin
              resolving <= 0;
              state <= DONE;
              
              if (temp_path1 != 0 && temp_path2 != 0) begin
                possible <= 1;
                path1_mask <= temp_path1;
                path2_mask <= temp_path2;
                s1 <= count1;
                s2 <= count2;
              end
            end
          end
        end

        DONE: begin
          done <= 1;
          state <= IDLE;
        end
      endcase
    end
  end

endmodule