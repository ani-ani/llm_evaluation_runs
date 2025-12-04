module max_road_counter(
  input clk,
  input rst_n,
  input start,
  input [63:0] adjacency_matrix,
  input [4:0] current_road_count,
  output reg [5:0] max_new_roads,
  output reg done
);

  reg [4:0] cycle_count;
  reg [63:0] fwd_reach [0:7];
  reg [63:0] rev_reach [0:7];
  reg [2:0] component_label [0:7];
  reg [3:0] comp_size [0:7];
  reg [7:0] comp_adj_matrix;
  reg [7:0] comp_reachable;
  reg [63:0] adj_matrix_reg;
  integer i, j, k;

  always @(posedge clk or negedge rst_n) begin
    if (~rst_n) begin
      cycle_count <= 5'b0;
      done <= 1'b0;
      max_new_roads <= 6'b0;
      comp_adj_matrix <= 8'b0;
      comp_reachable <= 8'b0;
      for (i=0; i<8; i=i+1) begin
        fwd_reach[i] <= 64'b0;
        rev_reach[i] <= 64'b0;
        component_label[i] <= 3'b0;
        comp_size[i] <= 4'b0;
      end
    end
    else begin
      if (start) begin
        cycle_count <= 5'b00001;
        adj_matrix_reg <= adjacency_matrix;
        done <= 1'b0;
        max_new_roads <= 6'b0;
        for (i=0; i<8; i=i+1) begin
          fwd_reach[i] <= 64'b1 << i;
          rev_reach[i] <= 64'b1 << i;
        end
      end
      else if (cycle_count != 0) begin
        if (cycle_count <= 8) begin
          for (i=0; i<8; i=i+1) begin
            for (j=0; j<8; j=j+1) begin
              if (adj_matrix_reg[i*8 + j]) begin
                fwd_reach[i] <= fwd_reach[i] | fwd_reach[j];
                rev_reach[j] <= rev_reach[j] | rev_reach[i];
              end
            end
          end
        end
        else if (cycle_count == 9) begin
          for (i=0; i<8; i=i+1) begin
            component_label[i] <= 3'b111;
            for (j=0; j<8; j=j+1) begin
              if ((fwd_reach[i][j] & rev_reach[i][j])) begin
                if (j < component_label[i]) begin
                  component_label[i] <= j;
                end
              end
            end
          end
        end
        else if (cycle_count == 10) begin
          for (i=0; i<8; i=i+1) begin
            comp_size[i] <= 4'b0;
          end
          for (i=0; i<8; i=i+1) begin
            comp_size[component_label[i]] <= comp_size[component_label[i]] + 1;
          end
        end
        else if (cycle_count == 11) begin
          comp_adj_matrix <= 8'b0;
          for (i=0; i<8; i=i+1) begin
            for (j=0; j<8; j=j+1) begin
              if ((component_label[i] != component_label[j]) && adj_matrix_reg[i*8 + j]) begin
                comp_adj_matrix[component_label[i]] <= comp_adj_matrix[component_label[i]] | (1 << component_label[j]);
              end
            end
          end
        end
        else if (cycle_count >= 12 && cycle_count <= 14) begin
          comp_reachable <= comp_reachable | comp_adj_matrix;
          for (k=0; k<8; k=k+1) begin
            for (i=0; i<8; i=i+1) begin
              if (comp_reachable[i] & (1 << k)) begin
                comp_reachable[i] <= comp_reachable[i] | comp_reachable[k];
              end
            end
          end
        end
        else if (cycle_count == 15) begin
          integer s_sq, einternal, ecross;
          s_sq = 0;
          einternal = 0;
          ecross = 0;
          for (i=0; i<8; i=i+1) begin
            s_sq = s_sq + comp_size[i] * comp_size[i];
          end
          for (i=0; i<8; i=i+1) begin
            for (j=0; j<8; j=j+1) begin
              if (adj_matrix_reg[i*8 + j]) begin
                if (component_label[i] == component_label[j]) begin
                  einternal = einternal + 1;
                end
                else if (comp_reachable[component_label[i]][component_label[j]]) begin
                  ecross = ecross + 1;
                end
              end
            end
          end
          max_new_roads <= (56 - current_road_count) - ((s_sq - einternal) + ((comp_reachable.count_ones()) - ecross));
        end
        else if (cycle_count == 20) begin
          done <= 1'b1;
          cycle_count <= 0;
        end
        cycle_count <= cycle_count + 1;
      end
    end
  end

endmodule