module max_length_finder(
  input [24:0] flattened_lists,
  input [14:0] list_lengths,
  output reg [2:0] max_length,
  output reg [4:0] max_list,
  output reg [2:0] list_index
);

  // Find max length and its first occurrence index, tie-break by lower index
  function [2:0] find_max_index_and_len(input [14:0] lens, output [2:0] max_len);
    integer i;
    begin
      max_len = 3'd0;
      find_max_index_and_len = 3'd0; // default to list 0 when all lengths are 0
      for (i = 0; i < 5; i = i + 1) begin
        if ((lens[i*3+:3] > max_len) || ((lens[i*3+:3] == max_len) && (i < find_max_index_and_len))) begin
          max_len = lens[i*3+:3];
          find_max_index_and_len = i[2:0];
        end
      end
    end
  endfunction

  reg [2:0] idx;
  reg [2:0] max_len_internal;

  always @(*) begin
    idx = find_max_index_and_len(list_lengths, max_len_internal);
    max_length = max_len_internal;
    list_index = idx;
    // Sublist elements are packed as [elem4, elem3, elem2, elem1, elem0]
    // Sublist 0 is stored in flattened_lists[4:0], sublist 1 in [9:5], ..., sublist 4 in [24:20]
    max_list = flattened_lists[idx*5 +: 5];
  end

endmodule
