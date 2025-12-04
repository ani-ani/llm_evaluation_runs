module magic_square_checker (
  input clk,
  input rst_n,
  input start,
  input [1:0] size,
  input [7:0] matrix [0:3][0:3],
  output reg result,
  output reg valid
);

  reg [3:0] cycle_count;
  reg [1:0] size_reg;
  reg [15:0] row_sums [0:3];
  reg [15:0] col_sums [0:3];
  reg [15:0] diag_sums [0:1];
  reg [15:0] reference_sum;
  reg all_match;

  always @(posedge clk) begin
    if (!rst_n) begin
      cycle_count <= 4'b0;
      size_reg <= 2'b0;
      row_sums[0] <= 0; row_sums[1] <= 0; row_sums[2] <= 0; row_sums[3] <= 0;
      col_sums[0] <= 0; col_sums[1] <= 0; col_sums[2] <= 0; col_sums[3] <= 0;
      diag_sums[0] <= 0; diag_sums[1] <= 0;
      reference_sum <= 0;
      all_match <= 1'b1;
      result <= 1'b0;
      valid <= 1'b0;
    end else begin
      valid <= 1'b0;
      if (start) begin
        cycle_count <= 4'b0;
        size_reg <= size;
        row_sums[0] <= 0; row_sums[1] <= 0; row_sums[2] <= 0; row_sums[3] <= 0;
        col_sums[0] <= 0; col_sums[1] <= 0; col_sums[2] <= 0; col_sums[3] <= 0;
        diag_sums[0] <= 0; diag_sums[1] <= 0;
        reference_sum <= 0;
        all_match <= 1'b1;
        result <= 1'b0;
      end else if (cycle_count < 15) begin
        cycle_count <= cycle_count + 1;
        case (cycle_count)
          0,1,2,3: begin // Row sums
            if (size_reg == 2'b10) begin
              row_sums[cycle_count] <= matrix[cycle_count][0] + matrix[cycle_count][1] + matrix[cycle_count][2];
            end else begin
              row_sums[cycle_count] <= matrix[cycle_count][0] + matrix[cycle_count][1] + matrix[cycle_count][2] + matrix[cycle_count][3];
            end
            if (cycle_count == 0) begin
              reference_sum <= (size_reg == 2'b10) ?
                (matrix[0][0] + matrix[0][1] + matrix[0][2]) :
                (matrix[0][0] + matrix[0][1] + matrix[0][2] + matrix[0][3]);
            end
          end
          4,5,6,7: begin // Column sums
            case (cycle_count)
              4: col_sums[0] <= (size_reg == 2'b10) ? (matrix[0][0] + matrix[1][0] + matrix[2][0]) : (matrix[0][0] + matrix[1][0] + matrix[2][0] + matrix[3][0]);
              5: col_sums[1] <= (size_reg == 2'b10) ? (matrix[0][1] + matrix[1][1] + matrix[2][1]) : (matrix[0][1] + matrix[1][1] + matrix[2][1] + matrix[3][1]);
              6: col_sums[2] <= (size_reg == 2'b10) ? (matrix[0][2] + matrix[1][2] + matrix[2][2]) : (matrix[0][2] + matrix[1][2] + matrix[2][2] + matrix[3][2]);
              7: if (size_reg == 2'b11)
                   col_sums[3] <= matrix[0][3] + matrix[1][3] + matrix[2][3] + matrix[3][3];
            endcase
          end
          8: diag_sums[0] <= (size_reg == 2'b10) ? (matrix[0][0] + matrix[1][1] + matrix[2][2]) : (matrix[0][0] + matrix[1][1] + matrix[2][2] + matrix[3][3]);
          9: diag_sums[1] <= (size_reg == 2'b10) ? (matrix[0][2] + matrix[1][1] + matrix[2][0]) : (matrix[0][3] + matrix[1][2] + matrix[2][1] + matrix[3][0]);
          10: all_match <= all_match && (row_sums[1] == reference_sum) && (row_sums[2] == reference_sum) && ((size_reg != 2'b10) ? (row_sums[3] == reference_sum) : 1'b1);
          11: all_match <= all_match && (col_sums[0] == reference_sum) && (col_sums[1] == reference_sum) && (col_sums[2] == reference_sum);
          12: if (size_reg == 2'b11)
                 all_match <= all_match && (col_sums[3] == reference_sum);
          13: all_match <= all_match && (diag_sums[0] == reference_sum);
          14: all_match <= all_match && (diag_sums[1] == reference_sum);
        endcase
      end else if (cycle_count == 15) begin
        result <= all_match;
        valid <= 1'b1;
      end
    end
  end
endmodule