module dora_city_height (
  input clk,
  input rst_n,
  input start,
  input [15:0] a[0:3][0:3],
  input [1:0] target_i, target_j,
  output reg [3:0] x_result,
  output reg done
);

  reg [15:0] row[0:3];
  reg [15:0] col[0:3];
  reg [15:0] target_val;
  reg [15:0] sorted_row[0:3];
  reg [15:0] sorted_col[0:3];
  reg [15:0] R_unique[0:3];
  reg [15:0] C_unique[0:3];
  reg [2:0] R_len;
  reg [2:0] C_len;
  reg [3:0] row_temp[0:3];
  reg [3:0] col_temp[0:3];
  reg [3:0] stage_counter;
  reg [3:0] row_rank, col_rank;
  reg [15:0] sorted_row_st1[0:3], sorted_row_st2[0:3];
  reg [15:0] sorted_col_st1[0:3], sorted_col_st2[0:3];

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      stage_counter <= 0;
      done <= 0;
      x_result <= 0;
      row_rank <= 0;
      col_rank <= 0;
    end else begin
      if (start) begin
        stage_counter <= 1;
        // Capture target row and col
        for (int i=0; i<4; i++) begin
          row[i] <= a[target_i][i];
          col[i] <= a[i][target_j];
        end
        target_val <= a[target_i][target_j];
        done <= 0;
      end else if (stage_counter != 0) begin
        if (stage_counter < 6)
          stage_counter <= stage_counter + 1;
        else begin
          stage_counter <= 0;
          done <= 1;
        end
      end else begin
        done <= 0;
      end

      // Stage 1: Sorting (3 cycles)
      if (stage_counter == 1) begin
        // Sort row - Stage 1
        sorted_row_st1[0] <= (row[0] < row[1]) ? row[0] : row[1];
        sorted_row_st1[1] <= (row[0] < row[1]) ? row[1] : row[0];
        sorted_row_st1[2] <= (row[2] < row[3]) ? row[2] : row[3];
        sorted_row_st1[3] <= (row[2] < row[3]) ? row[3] : row[2];
        // Sort col - Stage 1
        sorted_col_st1[0] <= (col[0] < col[1]) ? col[0] : col[1];
        sorted_col_st1[1] <= (col[0] < col[1]) ? col[1] : col[0];
        sorted_col_st1[2] <= (col[2] < col[3]) ? col[2] : col[3];
        sorted_col_st1[3] <= (col[2] < col[3]) ? col[3] : col[2];
      end

      if (stage_counter == 2) begin
        // Sort row - Stage 2
        sorted_row_st2[0] <= (sorted_row_st1[0] < sorted_row_st1[2]) ? sorted_row_st1[0] : sorted_row_st1[2];
        sorted_row_st2[1] <= (sorted_row_st1[1] < sorted_row_st1[3]) ? sorted_row_st1[1] : sorted_row_st1[3];
        // Sort col - Stage 2
        sorted_col_st2[0] <= (sorted_col_st1[0] < sorted_col_st1[2]) ? sorted_col_st1[0] : sorted_col_st1[2];
        sorted_col_st2[1] <= (sorted_col_st1[1] < sorted_col_st1[3]) ? sorted_col_st1[1] : sorted_col_st1[3];
        // Maintain previous elements
        sorted_row_st2[2] <= sorted_row_st1[2];
        sorted_row_st2[3] <= sorted_row_st1[3];
        sorted_col_st2[2] <= sorted_col_st1[2];
        sorted_col_st2[3] <= sorted_col_st1[3];
      end

      if (stage_counter == 3) begin
        // Sort row - Stage 3
        sorted_row[0] <= sorted_row_st2[0];
        sorted_row[1] <= (sorted_row_st2[1] < sorted_row_st2[2]) ? sorted_row_st2[1] : sorted_row_st2[2];
        sorted_row[2] <= (sorted_row_st2[1] < sorted_row_st2[2]) ? sorted_row_st2[2] : sorted_row_st2[1];
        sorted_row[3] <= sorted_row_st2[3];
        // Sort col - Stage 3
        sorted_col[0] <= sorted_col_st2[0];
        sorted_col[1] <= (sorted_col_st2[1] < sorted_col_st2[2]) ? sorted_col_st2[1] : sorted_col_st2[2];
        sorted_col[2] <= (sorted_col_st2[1] < sorted_col_st2[2]) ? sorted_col_st2[2] : sorted_col_st2[1];
        sorted_col[3] <= sorted_col_st2[3];
      end

      // Remove duplicates (end of Stage 1)
      if (stage_counter == 3) begin
        R_len <= 1;
        R_unique[0] <= sorted_row[0];
        for (int i=1; i<4; i++) begin
          if (sorted_row[i] != sorted_row[i-1]) begin
            R_unique[R_len] <= sorted_row[i];
            R_len <= R_len + 1;
          end
        end

        C_len <= 1;
        C_unique[0] <= sorted_col[0];
        for (int i=1; i<4; i++) begin
          if (sorted_col[i] != sorted_col[i-1]) begin
            C_unique[C_len] <= sorted_col[i];
            C_len <= C_len + 1;
          end
        end
      end

      // Stage 2: Rank calculation (2 cycles)
      if (stage_counter == 4) begin
        // Initialize ranks
        row_rank <= 0;
        col_rank <= 0;
        // Compare first two elements
        for (int i=0; i < (R_len > 2 ? 2 : R_len); i++) begin
          if (R_unique[i] == target_val) row_rank <= i + 1;
        end
        for (int i=0; i < (C_len > 2 ? 2 : C_len); i++) begin
          if (C_unique[i] == target_val) col_rank <= i + 1;
        end
      end

      if (stage_counter == 5) begin
        // Compare last two elements
        for (int i=2; i < R_len; i++) begin
          if (R_unique[i] == target_val) row_rank <= i + 1;
        end
        for (int i=2; i < C_len; i++) begin
          if (C_unique[i] == target_val) col_rank <= i + 1;
        end
      end

      // Stage 3: Compute result
      if (stage_counter == 6) begin
        x_result <= ($unsigned(max(row_rank, col_rank)) + 
                    $unsigned(max(R_len - row_rank, C_len - col_rank)));
        done <= 1;
      end else begin
        done <= 0;
      end
    end
  end

  function [3:0] max(input [3:0] a, input [3:0] b);
    max = (a > b) ? a : b;
  endfunction

endmodule