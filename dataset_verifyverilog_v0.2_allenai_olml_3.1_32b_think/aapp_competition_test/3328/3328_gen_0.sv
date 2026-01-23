module domino_solver (
input clk,
input rst_n, // active-low reset 
input start,
input [1:0] K,
input [3:0][3:0][7:0] grid,
output reg [15:0] min_sum,
output reg done
);

localparam DOMINO_COUNT =24;
localparam [3:0] domino_a[DOMINO_COUNT], domino_b[DOMINO_COUNT];

generate
   for (int r=0; r<4; r++) begin
      for (int c=0; c<3; c++) begin
         domino_a[r*3 + c] = r*4 + c;
         domino_b[r*3 + c] = r*4 + c +1;
      end
   end
   for (int c=0; c<4; c++) begin
      for (int r=0; r<3; r++) begin
         int idx = 12 + c*3 + r;
         domino_a[idx] = r*4 + c;
         domino_b[idx] = (r+1)*4 + c;
      end
   end
endgenerate

parameter IDLE = 3'd0,
       CALC_TOTAL = 3'd1,
       GEN_DOMINOS = 3'd2,
       FIND_BEST = 3'd3,
       DONE = 3'd4;

reg [2:0] state;
reg [15:0] total_sum_reg;
reg [15:0] max_covered;
reg [4:0] domino_idx_k1;
reg [4:0] i_k2, j_k2;
reg [4:0] i_k3, j_k3, k_k3;
reg [15:0] min_sum_reg;
reg done_reg;

assign done = done_reg;
assign min_sum = min_sum_reg;

always @(posedge clk) begin
   if (!rst_n) begin
      state <= IDLE;
      total_sum_reg <= 16'd0;
      max_covered <= 16'd0;
      min_sum_reg <= 16'd0;
      done_reg <= 1'b0;
      domino_idx_k1 <= 5'd0;
      i_k2 <= 5'd0;
      j_k2 <= 5'd0;
      i_k3 <=5'd0;
      j_k3 <=5'd0;
      k_k3 <=5'd0;
   end else begin
      if (state == IDLE) begin
         if (start) state <= CALC_TOTAL;
      end else if (state == CALC_TOTAL) begin
         total_sum_reg <= total_sum_comb;
         state <= GEN_DOMINOS;
      end else if (state == GEN_DOMINOS) begin
         state <= FIND_BEST;
      end else if (state == FIND_BEST) begin
         case (K)
            2'd1: begin
               if (domino_idx_k1 == 0) max_covered <= 16'd0;
               [7:0] val_a = get_cell_value(domino_a[domino_idx_k1]);
               [7:0] val_b = get_cell_value(domino_b[domino_idx_k1]);
               [15:0] current_sum = val_a + val_b;
               if (current_sum > max_covered) max_covered <= current_sum;
               domino_idx_k1 <= domino_idx_k1 +1;
               if (domino_idx_k1 > 23) begin
                  min_sum_reg <= total_sum_reg - max_covered;
                  done_reg <= 1'b1;
                  state <= DONE;
               end
            end
            2'd2: begin
               if (i_k2 ==0 && j_k2 ==0) begin
                  i_k2 <=5'd0;
                  j_k2 <= i_k2 +1;
               end
               if (i_k2 <24 && j_k2 <24 && j_k2 > i_k2) begin
                  if (!domino_overlap(domino_a[i_k2], domino_b[i_k2], domino_a[j_k2], domino_b[j_k2])) begin
                     [15:0] sum_i = get_cell_value(domino_a[i_k2]) + get_cell_value(domino_b[i_k2]);
                     [15:0] sum_j = get_cell_value(domino_a[j_k2]) + get_cell_value(domino_b[j_k2]);
                     [15:0] total_pair = sum_i + sum_j;
                     if (total_pair > max_covered) max_covered <= total_pair;
                  end
               end
               j_k2 <= j_k2 +1;
               if (j_k2 >23) begin
                  if (i_k2 <23) begin
                     i_k2 <= i_k2 +1;
                     j_k2 <= i_k2 +1;
                  end else begin
                     min_sum_reg <= total_sum_reg - max_covered;
                     done_reg <=1'b1;
                     state <= DONE;
                  end
               end
            end
            2'd3: begin
               min_sum_reg <= total_sum_reg;
               done_reg <=1'b1;
               state <= DONE;
            end
            default: state <= DONE;
         endcase
      end else if (state == DONE) begin
         // stay
      end
   end
end

function automatic [7:0] get_cell_value;
   input [3:0] cell_idx;
   get_cell_value = grid[cell_idx>>2][cell_idx&3];
endfunction

function automatic int domino_overlap;
   input [3:0] a1, b1, a2, b2;
   domino_overlap = 0;
   if (a1 == a2 || a1 == b2 || b1 ==a2 || b1 == b2) begin
      domino_overlap =1;
   end
endfunction

endmodule