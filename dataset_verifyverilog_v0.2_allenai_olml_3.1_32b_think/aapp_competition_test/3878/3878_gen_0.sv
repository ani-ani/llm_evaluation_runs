module graph_optimizer (
  input clk,
  input rst_n,
  input start,
  input [15:0] adj_matrix_0,
  input [15:0] adj_matrix_1,
  input [15:0] adj_matrix_2,
  input [15:0] adj_matrix_3,
  input [15:0] adj_matrix_4,
  input [15:0] adj_matrix_5,
  input [15:0] adj_matrix_6,
  input [15:0] adj_matrix_7,
  input [15:0] adj_matrix_8,
  input [15:0] adj_matrix_9,
  input [15:0] adj_matrix_10,
  input [15:0] adj_matrix_11,
  input [15:0] adj_matrix_12,
  input [15:0] adj_matrix_13,
  input [15:0] adj_matrix_14,
  input [15:0] adj_matrix_15,
  input [3:0] n,
  output reg [3:0] result_steps,
  output reg [15:0] result_mask,
  output reg done
);

reg [15:0] adj_matrix [0:15];
always @(*) begin
  adj_matrix[0] = adj_matrix_0;
  adj_matrix[1] = adj_matrix_1;
  adj_matrix[2] = adj_matrix_2;
  adj_matrix[3] = adj_matrix_3;
  adj_matrix[4] = adj_matrix_4;
  adj_matrix[5] = adj_matrix_5;
  adj_matrix[6] = adj_matrix_6;
  adj_matrix[7] = adj_matrix_7;
  adj_matrix[8] = adj_matrix_8;
  adj_matrix[9] = adj_matrix_9;
  adj_matrix[10] = adj_matrix_10;
  adj_matrix[11] = adj_matrix_11;
  adj_matrix[12] = adj_matrix_12;
  adj_matrix[13] = adj_matrix_13;
  adj_matrix[14] = adj_matrix_14;
  adj_matrix[15] = adj_matrix_15;
end

reg [2:0] state;
reg [15:0] current_mask;
reg [3:0] current_k;
reg [15:0] best_mask;
reg [3:0] min_steps;
reg done_reg;

assign result_steps = min_steps;
assign result_mask = best_mask;
assign done = done_reg;

function [3:0] popcount;
  input [15:0] x;
  begin
    popcount = (x>>0 &1) + (x>>1 &1) + (x>>2 &1) + (x>>3 &1) +
               (x>>4 &1) + (x>>5 &1) + (x>>6 &1) + (x>>7 &1) +
               (x>>8 &1) + (x>>9 &1) + (x>>10 &1) + (x>>11 &1) +
               (x>>12 &1) + (x>>13 &1) + (x>>14 &1) + (x>>15 &1);
  end

always @(posedge clk) begin
  if (!rst_n) begin
    state <= 0;
    current_k <= 0;
    best_mask <= 0;
    min_steps <= 4'd16;
    done_reg <= 1'b0;
  end else begin
    case (state)
      0: if (start) begin
           state <= 1;
           current_k <= 0;
           current_mask <= 0;
         end
      1: if (current_mask == {16{1'b1}}) begin
           min_steps <= current_k;
           best_mask <= current_mask;
           state <= 2;
           done_reg <= 1'b1;
         end else begin
           current_mask <= current_mask + 1;
           if (current_mask > (1<<current_k)-1) begin
             current_k <= current_k + 1;
           end
         end
      2: ;
    endcase
  end
end

endmodule