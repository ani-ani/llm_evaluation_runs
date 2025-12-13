module min_sublist(
  input  [3:0] valid_mask [3:0],
  input  [7:0] data       [3:0][3:0],
  output reg [7:0] min_data[3:0],
  output reg [3:0] out_valid_mask
);

  integer i, j;
  reg [2:0] count [3:0];      // popcount per sublist (0-4)
  reg [2:0] min_count;
  reg [1:0] min_index;

  always @* begin
    // Popcount for each sublist
    for (i = 0; i < 4; i = i + 1) begin
      count[i] = valid_mask[i][0] +
                 valid_mask[i][1] +
                 valid_mask[i][2] +
                 valid_mask[i][3];
    end

    // Find index of sublist with minimum count (tie -> lowest index)
    min_index = 2'd0;
    min_count = count[0];
    for (i = 1; i < 4; i = i + 1) begin
      if (count[i] < min_count) begin
        min_count = count[i];
        min_index = i[1:0];
      end
    end

    // Drive outputs from selected sublist
    out_valid_mask = valid_mask[min_index];
    for (j = 0; j < 4; j = j + 1) begin
      min_data[j] = data[min_index][j];
    end
  end

endmodule