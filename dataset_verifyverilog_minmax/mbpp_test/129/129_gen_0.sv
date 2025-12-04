module magic_square_checker(
  input clk,
  input rst_n,
  input start,
  input [1:0] size,
  input [7:0] matrix [0:3][0:3],
  output reg result,
  output reg valid
);

  reg [4:0] state;
  reg [1:0] size_reg;
  reg [9:0] row_sum [0:3];
  reg [9:0] col_sum [0:3];
  reg [9:0] diag_sum1, diag_sum2;
  reg [9:0] sum_ref;
  reg result_temp;
  integer i;

  always_ff @(posedge clk) begin
    if (!rst_n) begin
      state <= 5'd0;
      valid <= 1'b0;
      result <= 1'b0;
      for (i=0; i<4; i++) row_sum[i] <= 10'd0;
      for (i=0; i<4; i++) col_sum[i] <= 10'd0;
      diag_sum1 <= 10'd0;
      diag_sum2 <= 10'd0;
      size_reg <= 2'd0;
      sum_ref <= 10'd0;
      result_temp <= 1'b1;
    end
    else begin
      case (state)
        0: begin
          valid <= 1'b0;
          if (start) begin
            size_reg <= size;
            for (i=0; i<4; i++) row_sum[i] <= 10'd0;
            for (i=0; i<4; i++) col_sum[i] <= 10'd0;
            diag_sum1 <= 10'd0;
            diag_sum2 <= 10'd0;
            state <= 5'd1;
          end
        end
        1: begin
          if (size_reg == 2'b10) begin
            row_sum[0] <= $unsigned(matrix[0][0]) + $unsigned(matrix[0][1]) + $unsigned(matrix[0][2]);
          end else begin
            row_sum[0] <= $unsigned(matrix[0][0]) + $unsigned(matrix[0][1]) + $unsigned(matrix[0][2]) + $unsigned(matrix[0][3]);
          end
          sum_ref <= row_sum[0];
          state <= 5'd2;
        end
        2: begin
          if (size_reg == 2'b10) begin
            row_sum[1] <= $unsigned(matrix[1][0]) + $unsigned(matrix[1][1]) + $unsigned(matrix[1][2]);
          end else begin
            row_sum[1] <= $unsigned(matrix[1][0]) + $unsigned(matrix[1][1]) + $unsigned(matrix[1][2]) + $unsigned(matrix[1][3]);
          end
          state <= 5'd3;
        end
        3: begin
          if (size_reg == 2'b10) begin
            row_sum[2] <= $unsigned(matrix[2][0]) + $unsigned(matrix[2][1]) + $unsigned(matrix[2][2]);
          end else begin
            row_sum[2] <= $unsigned(matrix[2][0]) + $unsigned(matrix[2][1]) + $unsigned(matrix[2][2]) + $unsigned(matrix[2][3]);
          end
          state <= 5'd4;
        end
        4: begin
          if (size_reg != 2'b10) begin
            row_sum[3] <= $unsigned(matrix[3][0]) + $unsigned(matrix[3][1]) + $unsigned(matrix[3][2]) + $unsigned(matrix[3][3]);
          end
          state <= 5'd5;
        end
        5: begin
          if (size_reg == 2'b10) begin
            col_sum[0] <= $unsigned(matrix[0][0]) + $unsigned(matrix[1][0]) + $unsigned(matrix[2][0]);
          end else begin
            col_sum[0] <= $unsigned(matrix[0][0]) + $unsigned(matrix[1][0]) + $unsigned(matrix[2][0]) + $unsigned(matrix[3][0]);
          end
          state <= 5'd6;
        end
        6: begin
          if (size_reg == 2'b10) begin
            col_sum[1] <= $unsigned(matrix[0][1]) + $unsigned(matrix[1][1]) + $unsigned(matrix[2][1]);
          end else begin
            col_sum[1] <= $unsigned(matrix[0][1]) + $unsigned(matrix[1][1]) + $unsigned(matrix[2][1]) + $unsigned(matrix[3][1]);
          end
          state <= 5'd7;
        end
        7: begin
          if (size_reg == 2'b10) begin
            col_sum[2] <= $unsigned(matrix[0][2]) + $unsigned(matrix[1][2]) + $unsigned(matrix[2][2]);
          end else begin
            col_sum[2] <= $unsigned(matrix[0][2]) + $unsigned(matrix[1][2]) + $unsigned(matrix[2][2]) + $unsigned(matrix[3][2]);
          end
          state <= 5'd8;
        end
        8: begin
          if (size_reg != 2'b10) begin
            col_sum[3] <= $unsigned(matrix[0][3]) + $unsigned(matrix[1][3]) + $unsigned(matrix[2][3]) + $unsigned(matrix[3][3]);
          end
          state <= 5'd9;
        end
        9: begin
          if (size_reg == 2'b10) begin
            diag_sum1 <= $unsigned(matrix[0][0]) + $unsigned(matrix[1][1]) + $unsigned(matrix[2][2]);
          end else begin
            diag_sum1 <= $unsigned(matrix[0][0]) + $unsigned(matrix[1][1]) + $unsigned(matrix[2][2]) + $unsigned(matrix[3][3]);
          end
          state <= 5'd10;
        end
        10: begin
          if (size_reg == 2'b10) begin
            diag_sum2 <= $unsigned(matrix[0][2]) + $unsigned(matrix[1][1]) + $unsigned(matrix[2][0]);
          end else begin
            diag_sum2 <= $unsigned(matrix[0][3]) + $unsigned(matrix[1][2]) + $unsigned(matrix[2][1]) + $unsigned(matrix[3][0]);
          end
          state <= 5'd11;
        end
        11: begin
          result_temp <= 1'b1;
          if (row_sum[1] != sum_ref) result_temp <= 1'b0;
          if (row_sum[2] != sum_ref) result_temp <= 1'b0;
          state <= 5'd12;
        end
        12: begin
          if (size_reg != 2'b10) begin
            if (row_sum[3] != sum_ref) result_temp <= 1'b0;
          end
          if (col_sum[0] != sum_ref) result_temp <= 1'b0;
          state <= 5'd13;
        end
        13: begin
          if (col_sum[1] != sum_ref) result_temp <= 1'b0;
          if (col_sum[2] != sum_ref) result_temp <= 1'b0;
          state <= 5'd14;
        end
        14: begin
          if (size_reg != 2'b10) begin
            if (col_sum[3] != sum_ref) result_temp <= 1'b0;
          end
          if (diag_sum1 != sum_ref) result_temp <= 1'b0;
          state <= 5'd15;
        end
        15: begin
          if (diag_sum2 != sum_ref) result_temp <= 1'b0;
          state <= 5'd16;
        end
        16: begin
          result <= result_temp;
          valid <= 1'b1;
          state <= 5'd0;
        end
      endcase
    end
  end

endmodule