module matrix_row_sort(
  input clk,
  input rst_n,
  input start,
  input [8:0][7:0] matrix_flat,
  output reg [8:0][7:0] sorted_matrix,
  output reg done
);

  reg [8:0][7:0] matrix_reg;
  reg signed [5:0] sum [0:2];
  reg [2:0] cnt;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      cnt <= 0;
      done <= 0;
      matrix_reg <= 0;
      sum[0] <= 0;
      sum[1] <= 0;
      sum[2] <= 0;
      sorted_matrix <= 0;
    end else begin
      if (start && cnt == 0)
        cnt <= 1;
      else if (cnt != 0)
        cnt <= (cnt < 5) ? cnt + 1 : 0;

      done <= (cnt == 5);

      case (cnt)
        1: begin
          sum[0] <= $signed(matrix_flat[0]) + $signed(matrix_flat[1]) + $signed(matrix_flat[2]);
          sum[1] <= $signed(matrix_flat[3]) + $signed(matrix_flat[4]) + $signed(matrix_flat[5]);
          sum[2] <= $signed(matrix_flat[6]) + $signed(matrix_flat[7]) + $signed(matrix_flat[8]);
          matrix_reg <= matrix_flat;
        end

        2: if (sum[0] > sum[1]) begin
          matrix_reg <= {matrix_reg[3], matrix_reg[4], matrix_reg[5], matrix_reg[0], matrix_reg[1], matrix_reg[2], matrix_reg[6], matrix_reg[7], matrix_reg[8]};
          sum[0] <= sum[1];
          sum[1] <= sum[0];
        end

        3: if (sum[1] > sum[2]) begin
          matrix_reg <= {matrix_reg[0], matrix_reg[1], matrix_reg[2], matrix_reg[6], matrix_reg[7], matrix_reg[8], matrix_reg[3], matrix_reg[4], matrix_reg[5]};
          sum[1] <= sum[2];
          sum[2] <= sum[1];
        end

        4: if (sum[0] > sum[1]) begin
          matrix_reg <= {matrix_reg[3], matrix_reg[4], matrix_reg[5], matrix_reg[0], matrix_reg[1], matrix_reg[2], matrix_reg[6], matrix_reg[7], matrix_reg[8]};
          sum[0] <= sum[1];
          sum[1] <= sum[0];
        end

        5: sorted_matrix <= matrix_reg;
      endcase
    end
  end
endmodule