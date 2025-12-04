module minimal_tunnel_cost (
  input clk,
  input rst_n,
  input start,
  input signed [7:0] x[0:3],
  input signed [7:0] y[0:3],
  input signed [7:0] z[0:3],
  output reg [9:0] total_cost,
  output reg done
);

  reg [7:0] cycle;
  typedef struct packed {
    logic [1:0] u;
    logic [1:0] v;
    logic [7:0] cost;
  } edge_t;

  edge_t edges [0:5];
  edge_t sorted_edges [0:5];
  reg [1:0] parent [0:3];
  reg [2:0] edges_selected;
  reg [2:0] edge_idx;
  reg [9:0] cost_sum;

  function [1:0] find_root(input [1:0] node);
    automatic [1:0] temp = node;
    temp = (parent[temp] != temp) ? parent[temp] : temp;
    temp = (parent[temp] != temp) ? parent[temp] : temp;
    return temp;
  endfunction

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      done <= 1'b0;
      total_cost <= 10'd0;
      cycle <= 8'd0;
      for (int i=0; i<6; i++) begin
        edges[i] <= '{u:2'd0, v:2'd0, cost:8'd0};
        sorted_edges[i] <= '{u:2'd0, v:2'd0, cost:8'd0};
      end
      foreach (parent[i]) parent[i] <= 2'(i);
      edges_selected <= 3'd0;
      edge_idx <= 3'd0;
      cost_sum <= 10'd0;
    end else begin
      done <= 1'b0;
      if (cycle == 8'd50) begin
        done <= 1'b1;
        total_cost <= cost_sum;
      end else if (start) begin
        cycle <= cycle + 1;
      end

      case (cycle)
        0: begin
          // Compute edge costs
          edges[0] <= '{u:0, v:1, cost:$signed(x[0]-x[1])[7] ? -($signed(x[0]-x[1])) : ($signed(x[0]-x[1]))};
          edges[1] <= '{u:0, v:2, cost:$signed(x[0]-x[2])[7] ? -($signed(x[0]-x[2])) : ($signed(x[0]-x[2]))};
          edges[2] <= '{u:0, v:3, cost:$signed(x[0]-x[3])[7] ? -($signed(x[0]-x[3])) : ($signed(x[0]-x[3]))};
          edges[3] <= '{u:1, v:2, cost:$signed(x[1]-x[2])[7] ? -($signed(x[1]-x[2])) : ($signed(x[1]-x[2]))};
          edges[4] <= '{u:1, v:3, cost:$signed(x[1]-x[3])[7] ? -($signed(x[1]-x[3])) : ($signed(x[1]-x[3]))};
          edges[5] <= '{u:2, v:3, cost:$signed(x[2]-x[3])[7] ? -($signed(x[2]-x[3])) : ($signed(x[2]-x[3]))};

          for (int i=0; i<6; i++) begin
            logic [7:0] dx, dy, dz, dy_tmp, dz_tmp, min1, min_val;
            dx = edges[i].cost;
            dy_tmp = $signed(y[edges[i].u]-y[edges[i].v]);
            dy = dy_tmp[7] ? -dy_tmp : dy_tmp;
            dz_tmp = $signed(z[edges[i].u]-z[edges[i].v]);
            dz = dz_tmp[7] ? -dz_tmp : dz_tmp;
            min1 = (dx < dy) ? dx : dy;
            min_val = (min1 < dz) ? min1 : dz;
            edges[i].cost <= min_val;
          end
          for (int i=0; i<4; i++) parent[i] <= 2'(i);
          edges_selected <= 0;
          edge_idx <= 0;
          cost_sum <= 0;
        end

        1: begin
          for (int i=0; i<6; i++) begin
            sorted_edges[i] <= edges[i];
          end
        end

        default: begin
          if (cycle >= 2 && cycle <=16) begin
            // Bubble sort
            automatic int k = cycle -2;
            automatic int j;
            if (k <=4)       j = k;
            else if (k <=8)  j = k-5;
            else if (k <=11) j = k-9;
            else if (k <=13) j = k-12;
            else             j =0;

            if (sorted_edges[j].cost > sorted_edges[j+1].cost) begin
              edge_t temp = sorted_edges[j];
              sorted_edges[j] <= sorted_edges[j+1];
              sorted_edges[j+1] <= temp;
            end
          end else if (cycle >=17 && cycle <=23) begin
            // Kruskal's﻿ algorithm
            automatic edge_t current_edge = sorted_edges[edge_idx];
            automatic [1:0] root_u = find_root(current_edge.u);
            automatic [1:0] root_v = find_root(current_edge.v);

            if (root_u != root_v && edges_selected < 3) begin
              parent[root_v] <= root_u;
              cost_sum <= cost_sum + current_edge.cost;
              edges_selected <= edges_selected +1;
            end
            edge_idx <= edge_idx +1;
          end
        end
      endcase
    end
  end
endmodule