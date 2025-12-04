module superdoku_solver(
  input clk,
  input rst_n,
  input start,
  input [2:0] k,
  input [31:0] grid_in,
  output reg valid_out,
  output reg [31:0] grid_out,
  output reg done
);

  reg [2:0] count;
  reg [7:0] grid_reg [0:3];
  reg [2:0] k_reg;
  reg invalid_flag;
  reg processing;
  reg row_invalid;
  reg col_invalid;
  integer i, j, m, n;

  function [7:0] rotate_left(input [7:0] row);
    rotate_left = {row[5:0], row[7:6]};
  endfunction

  always @(*) begin
    row_invalid = 0;
    if (count == 0) begin
      for (i = 0; i < k_reg; i = i + 1) begin
        if ((grid_reg[i][7:6] == grid_reg[i][5:4]) ||
            (grid_reg[i][7:6] == grid_reg[i][3:2]) ||
            (grid_reg[i][7:6] == grid_reg[i][1:0]) ||
            (grid_reg[i][5:4] == grid_reg[i][3:2]) ||
            (grid_reg[i][5:4] == grid_reg[i][1:0]) ||
            (grid_reg[i][3:2] == grid_reg[i][1:0]))
          row_invalid = 1;
      end
    end
    
    col_invalid = 0;
    if (count == 0) begin
      for (j = 0; j < 4; j = j + 1) begin
        for (m = 0; m < k_reg; m = m + 1) begin
          for (n = m + 1; n < k_reg; n = n + 1) begin
            case (j)
              0: if (grid_reg[m][7:6] == grid_reg[n][7:6]) col_invalid = 1;
              1: if (grid_reg[m][5:4] == grid_reg[n][5:4]) col_invalid = 1;
              2: if (grid_reg[m][3:2] == grid_reg[n][3:2]) col_invalid = 1;
              3: if (grid_reg[m][1:0] == grid_reg[n][1:0]) col_invalid = 1;
            endcase
          end
        end
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      valid_out <= 0;
      done <= 0;
      count <= 0;
      processing <= 0;
      invalid_flag <= 0;
      grid_reg[0] <= 8'b0;
      grid_reg[1] <= 8'b0;
      grid_reg[2] <= 8'b0;
      grid_reg[3] <= 8'b0;
      k_reg <= 0;
      grid_out <= 32'b0;
    end else begin
      if (start) begin
        k_reg <= k;
        grid_reg[0] <= grid_in[31:24];
        grid_reg[1] <= grid_in[23:16];
        grid_reg[2] <= grid_in[15:8];
        grid_reg[3] <= grid_in[7:0];
        count <= 0;
        processing <= 1;
        invalid_flag <= 0;
        done <= 0;
        valid_out <= 0;
      end else if (processing) begin
        if (count < 4)
          count <= count + 1;

        if (count == 0) begin
          invalid_flag <= row_invalid | col_invalid;
        end else if (count > 0) begin
          if (k_reg + count - 1 < 4) begin
            grid_reg[k_reg + count - 1] <= rotate_left(grid_reg[k_reg + count - 2]);
          end
        end

        if (count == 4) begin
          valid_out <= ~invalid_flag;
          done <= 1;
          processing <= 0;
        end
        grid_out <= {grid_reg[0], grid_reg[1], grid_reg[2], grid_reg[3]};
      end else begin
        done <= 0;
        valid_out <= 0;
      end
    end
  end
endmodule