module max_length_list (
  input [3:0] valid_mask,
  input [3:0][3:0][7:0] lists,
  output reg [1:0] max_length_idx,
  output reg [3:0][7:0] max_list,
  output reg [2:0] max_length
);

  // Calculate lengths for each list (count non-zero elements)
  reg [2:0] lengths [0:3];
  integer i, j;

  always @* begin
    // Initialize lengths
    for (i = 0; i < 4; i = i + 1) begin
      lengths[i] = 0;
      if (valid_mask[i]) begin
        for (j = 0; j < 4; j = j + 1) begin
          if (lists[i][j] != 0) begin
            lengths[i] = lengths[i] + 1;
          end
        end
      end
    end

    // Find maximum length and corresponding index
    reg [2:0] current_max = 0;
    reg [1:0] current_idx = 0;

    for (i = 0; i < 4; i = i + 1) begin
      if (valid_mask[i] && (lengths[i] > current_max)) begin
        current_max = lengths[i];
        current_idx = i;
      end
    end

    // Assign outputs
    max_length_idx = current_idx;
    max_length = current_max;

    // Output the winning list (padded with zeros)
    for (j = 0; j < 4; j = j + 1) begin
      if (j < current_max) begin
        max_list[j] = lists[current_idx][j];
      end else begin
        max_list[j] = 0;
      end
    end
  end

endmodule