module max_list_finder(
  input reg [3:0][3:0][4:0] lists,
  input reg [3:0][4:0] valid_lengths,
  output reg [1:0] max_length,
  output reg [3:0][4:0] max_list
);

  always @* begin
    // Find the list with the maximum valid length (first on ties)
    integer i;
    reg [4:0] max_len; // 0..4
    reg [1:0] max_idx;

    max_len = valid_lengths[0];
    max_idx = 2'd0;
    for (i = 1; i < 4; i = i + 1) begin
      if (valid_lengths[i] > max_len) begin
        max_len = valid_lengths[i];
        max_idx = i[1:0];
      end
    end

    // Output max length as 2-bit (0..4)
    max_length = max_len[1:0];

    // Output the corresponding list, padded to 4 elements with zeros
    max_list = lists[max_idx];
  end

endmodule