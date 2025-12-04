module minimal_tunnel_cost(
  input clk,
  input rst_n,
  input start,
  input signed [7:0] x[0:3],
  input signed [7:0] y[0:3],
  input signed [7:0] z[0:3],
  output reg [9:0] total_cost,
  output reg done
);

function [7:0] abs_diff;
  input [7:0] a;
  input [7:0] b;
  reg [8:0] diff;
begin
  diff = $signed(a) - $signed(b);
  if (diff[8])
    abs_diff = -diff[7:0];
  else
    abs_diff = diff[7:0];
end
endfunction

function [7:0] min3;
  input [7:0] a;
  input [7:0] b;
  input [7:0] c;
  reg [7:0] temp;
begin
  temp = a < b ? a : b;
  min3 = temp < c ? temp : c;
end
endfunction

function [1:0] get_root;
  input [1:0] node;
  reg [1:0] root;
begin
  root = node;
  if (parent[root] != root) begin
    root = parent[root];
    if (parent[root] != root) begin
      root = parent[root];
      if (parent[root] != root) begin
        root = parent[root];
      end
    end
  end
  get_root = root;
end
endfunction

reg [1:0] state;
parameter IDLE=0, RUN=1, DONE=2;

reg [5:0] run_counter;
reg [13:0] edges [0:5];
reg [1:0] parent [0:3];
reg [1:0] mst_count;
reg [9:0] total_cost_reg;

always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
    state <= IDLE;
    done <= 1'b0;
    total_cost <= 10'b0;
    run_counter <= 6'b0;
    edges[0] <= 14'b0;
    edges[1] <= 14'b0;
    edges[2] <= 14'b0;
    edges[3] <= 14'b0;
    edges[4] <= 14'b0;
    edges[5] <= 14'b0;
    parent[0] <= 2'b0;
    parent[1] <= 2'b1;
    parent[2] <= 2'b10;
    parent[3] <= 2'b11;
    mst_count <= 2'b0;
    total_cost_reg <= 10'b0;
  end else begin
    case (state)
      IDLE: begin
        if (start) begin
          state <= RUN;
          run_counter <= 6'b1;
          parent[0] <= 2'b0;
          parent[1] <= 2'b1;
          parent[2] <= 2'b10;
          parent[3] <= 2'b11;
          mst_count <= 2'b0;
          total_cost_reg <= 10'b0;
        end
      end
      RUN: begin
        if (run_counter < 50) begin
          run_counter <= run_counter + 1;
        end
        if (run_counter == 1) begin
          edges[0].node1 <= 2'b00;
          edges[0].node2 <= 2'b01;
          edges[0].cost <= min3( abs_diff(x[0],x[1]), abs_diff(y[0],y[1]), abs_diff(z[0],z[1]) );
          edges[1].node1 <= 2'b00;
          edges[1].node2 <= 2'b10;
          edges[1].cost <= min3( abs_diff(x[0],x[2]), abs_diff(y[0],y[2]), abs_diff(z[0],z[2]) );
          edges[2].node1 <= 2'b00;
          edges[2].node2 <= 2'b11;
          edges[2].cost <= min3( abs_diff(x[0],x[3]), abs_diff(y[0],y[3]), abs_diff(z[0],z[3]) );
          edges[3].node1 <= 2'b01;
          edges[3].node2 <= 2'b10;
          edges[3].cost <= min3( abs_diff(x[1],x[2]), abs_diff(y[1],y[2]), abs_diff(z[1],z[2]) );
          edges[4].node1 <= 2'b01;
          edges[4].node2 <= 2'b11;
          edges[4].cost <= min3( abs_diff(x[1],x[3]), abs_diff(y[1],y[3]), abs_diff(z[1],z[3]) );
          edges[5].node1 <= 2'b10;
          edges[5].node2 <= 2'b11;
          edges[5].cost <= min3( abs_diff(x[2],x[3]), abs_diff(y[2],y[3]), abs_diff(z[2],z[3]) );
        end
        if (run_counter >= 2 && run_counter <= 20) begin
          int j = (run_counter - 2) % 5;
          if (edges[j].cost > edges[j+1].cost) begin
            edges[j] <= edges[j+1];
            edges[j+1] <= edges[j];
          end
        end
        if (run_counter >= 21 && run_counter <= 26) begin
          int e_idx = run_counter - 21;
          if (e_idx < 6) begin
            int node1 = edges[e_idx].node1;
            int node2 = edges[e_idx].node2;
            int root1 = get_root(node1);
            int root2 = get_root(node2);
            if (root1 != root2) begin
              total_cost_reg <= total_cost_reg + edges[e_idx].cost;
              parent[root1] <= root2;
              mst_count <= mst_count + 1;
            end
          end
        end
        if (run_counter == 50) begin
          state <= DONE;
          done <= 1'b1;
          total_cost <= total_cost_reg;
        end
      end
      DONE: begin
        done <= 1'b1;
        total_cost <= total_cost_reg;
      end
    endcase
  end
end

endmodule