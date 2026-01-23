module longest_race_path(input clk, input rst_n, input start, input [7:0] adj_matrix [8][8], output reg [3:0] max_length, output reg done);
reg [3:0] state;
reg [7:0] stack_node [15];
reg [27:0] stack_edge_mask [15];
reg [3:0] stack_length [15];
reg [2:0] stack_next_neighbor [15];
reg [3:0] stack_depth;
reg [3:0] max_length_reg;
reg done_reg;

always @(*) begin
  if (!rst_n) begin
    state <= 0;
    stack_depth <=0;
    max_length_reg <=0;
    done_reg <=0;
  end else begin
    case (state)
      0: if (start) state <=1; else begin state<=0; max_length<=0; done<=0; end
      1: begin
          stack_depth<=7;
          stack_node[0]<=1; stack_edge_mask[0]<=0; stack_length[0]<=0; stack_next_neighbor[0]<=0;
          stack_node[1]<=2; stack_edge_mask[1]<=0; stack_length[1]<=0; stack_next_neighbor[1]<=0;
          stack_node[2]<=3; stack_edge_mask[2]<=0; stack_length[2]<=0; stack_next_neighbor[2]<=0;
          stack_node[3]<=4; stack_edge_mask[3]<=0; stack_length[3]<=0; stack_next_neighbor[3]<=0;
          stack_node[4]<=5; stack_edge_mask[4]<=0; stack_length[4]<=0; stack_next_neighbor[4]<=0;
          stack_node[5]<=6; stack_edge_mask[5]<=0; stack_length[5]<=0; stack_next_neighbor[5]<=0;
          stack_node[6]<=7; stack_edge_mask[6]<=0; stack_length[6]<=0; stack_next_neighbor[6]<=0;
          state<=2;
        end
      2: begin
          if (stack_depth==0) state<=5;
          else begin
            int current_top=stack_depth-1;
            int current_node=stack_node[current_top];
            if (current_node ==1) begin
              if (stack_length[current_top] > max_length_reg) max_length_reg <= stack_length[current_top];
              stack_depth <= stack_depth -1;
              if (stack_depth >0) state<=2; else state<=5;
            end else begin
              int current_mask=stack_edge_mask[current_top];
              int current_len=stack_length[current_top];
              int found=0;
              int chosen;
              if (adj_matrix[current_node][0]==1) begin
                int min_u = current_node < 0 ? current_node : 0;
                int max_u = current_node > 0 ? current_node : 0;
                int edge_index = min_u*(8 - min_u -1) + (max_u - min_u -1);
                if (!(current_mask & (1 << edge_index))) begin
                  found=1;
                  chosen=0;
                end
              end
              if (!found && adj_matrix[current_node][1]==1) begin
                int min_u = current_node < 1 ? current_node : 1;
                int max_u = current_node > 1 ? current_node : 1;
                int edge_index = min_u*(8 - min_u -1) + (max_u - min_u -1);
                if (!(current_mask & (1 << edge_index))) begin
                  found=1;
                  chosen=1;
                end
              end
              if (!found && adj_matrix[current_node][2]==1) begin
                int min_u = current_node < 2 ? current_node : 2;
                int max_u = current_node > 2 ? current_node : 2;
                int edge_index = min_u*(8 - min_u -1) + (max_u - min_u -1);
                if (!(current_mask & (1 << edge_index))) begin
                  found=1;
                  chosen=2;
                end
              end
              if (!found && adj_matrix[current_node][3]==1) begin
                int min_u = current_node < 3 ? current_node : 3;
                int max_u = current_node > 3 ? current_node : 3;
                int edge_index = min_u*(8 - min_u -1) + (max_u - min_u -1);
                if (!(current_mask & (1 << edge_index))) begin
                  found=1;
                  chosen=3;
                end
              end
              if (!found && adj_matrix[current_node][4]==1) begin
                int min_u = current_node < 4 ? current_node : 4;
                int max_u = current_node > 4 ? current_node : 4;
                int edge_index = min_u*(8 - min_u -1) + (max_u - min_u -1);
                if (!(current_mask & (1 << edge_index))) begin
                  found=1;
                  chosen=4;
                end
              end
              if (!found && adj_matrix[current_node][5]==1) begin
                int min_u = current_node < 5 ? current_node : 5;
                int max_u = current_node > 5 ? current_node : 5;
                int edge_index = min_u*(8 - min_u -1) + (max_u - min_u -1);
                if (!(current_mask & (1 << edge_index))) begin
                  found=1;
                  chosen=5;
                end
              end
              if (!found && adj_matrix[current_node][6]==1) begin
                int min_u = current_node < 6 ? current_node : 6;
                int max_u = current_node > 6 ? current_node : 6;
                int edge_index = min_u*(8 - min_u -1) + (max_u - min_u -1);
                if (!(current_mask & (1 << edge_index))) begin
                  found=1;
                  chosen=6;
                end
              end
              if (!found && adj_matrix[current_node][7]==1) begin
                int min_u = current_node < 7 ? current_node : 7;
                int max_u = current_node > 7 ? current_node : 7;
                int edge_index = min_u*(8 - min_u -1) + (max_u - min_u -1);
                if (!(current_mask & (1 << edge_index))) begin
                  found=1;
                  chosen=7;
                end
              end
              if (found) begin
                stack_depth<=stack_depth+1;
                stack_node[stack_depth-1]<=chosen;
                int new_mask=current_mask | (1<<edge_index);
                stack_edge_mask[stack_depth-1]<=new_mask;
                stack_length[stack_depth-1]<=current_len+1;
                stack_next_neighbor[stack_depth-1]<=0;
                stack_next_neighbor[current_top]<=0;
                state<=2;
              end else begin
                if (stack_depth>1) stack_depth<=stack_depth-1;
                else if (stack_depth==1) begin
                  stack_depth<=0;
                  state<=5;
                end
              end
            end
          end
      5: done_reg<=1; state<=5;
    endcase
  end
end

always @(posedge clk) if (!rst_n) begin max_length_reg<=0; done_reg<=0; end else begin max_length<=max_length_reg; done<=done_reg; end
endmodule