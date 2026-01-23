module chemistry_table (
  input [7:0] row1_val_0, row1_val_1, row1_val_2, row1_val_3, row1_val_4, row1_val_5, row1_val_6, row1_val_7,
  input [7:0] row2_val_0, row2_val_1, row2_val_2, row2_val_3, row2_val_4, row2_val_5, row2_val_6, row2_val_7,
  input [7:0] row3_val_0, row3_val_1, row3_val_2, row3_val_3, row3_val_4, row3_val_5, row3_val_6, row3_val_7,
  output [3:0] min_deletions
);

  reg [7:0] mask;
  reg [2:0] row1_count [1:8];
  reg [2:0] row2_count [1:8];
  reg [2:0] row3_count [1:8];
  reg [3:0] max_popcount;
  reg [3:0] current_popcount;
  reg valid;
  reg [3:0] i;
  reg [7:0] j;
  reg [2:0] k;

  always @* begin
    max_popcount = 0;
    for (mask = 0; mask < 256; mask = mask + 1) begin
      // Initialize counts
      for (k = 0; k < 8; k = k + 1) begin
        row1_count[k+1] = 0;
        row2_count[k+1] = 0;
        row3_count[k+1] = 0;
      end

      // Count frequencies for each row
      for (j = 0; j < 8; j = j + 1) begin
        if (mask[j]) begin
          case (row1_val_0[j])
            1: row1_count[1] = row1_count[1] + 1;
            2: row1_count[2] = row1_count[2] + 1;
            3: row1_count[3] = row1_count[3] + 1;
            4: row1_count[4] = row1_count[4] + 1;
            5: row1_count[5] = row1_count[5] + 1;
            6: row1_count[6] = row1_count[6] + 1;
            7: row1_count[7] = row1_count[7] + 1;
            8: row1_count[8] = row1_count[8] + 1;
          endcase

          case (row2_val_0[j])
            1: row2_count[1] = row2_count[1] + 1;
            2: row2_count[2] = row2_count[2] + 1;
            3: row2_count[3] = row2_count[3] + 1;
            4: row2_count[4] = row2_count[4] + 1;
            5: row2_count[5] = row2_count[5] + 1;
            6: row2_count[6] = row2_count[6] + 1;
            7: row2_count[7] = row2_count[7] + 1;
            8: row2_count[8] = row2_count[8] + 1;
          endcase

          case (row3_val_0[j])
            1: row3_count[1] = row3_count[1] + 1;
            2: row3_count[2] = row3_count[2] + 1;
            3: row3_count[3] = row3_count[3] + 1;
            4: row3_count[4] = row3_count[4] + 1;
            5: row3_count[5] = row3_count[5] + 1;
            6: row3_count[6] = row3_count[6] + 1;
            7: row3_count[7] = row3_count[7] + 1;
            8: row3_count[8] = row3_count[8] + 1;
          endcase
        end
      end

      // Check if all counts match
      valid = 1;
      for (k = 0; k < 8; k = k + 1) begin
        if (row1_count[k+1] != row2_count[k+1] || row2_count[k+1] != row3_count[k+1]) begin
          valid = 0;
        end
      end

      // Count population if valid
      if (valid) begin
        current_popcount = 0;
        for (j = 0; j < 8; j = j + 1) begin
          if (mask[j]) current_popcount = current_popcount + 1;
        end
        if (current_popcount > max_popcount) max_popcount = current_popcount;
      end
    end

    min_deletions = 8 - max_popcount;
  end

endmodule