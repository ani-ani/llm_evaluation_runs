module sublist_checker (
  input [7:0] main_list [0:7],
  input [7:0] sub_list [0:3],
  input [2:0] sub_len,
  output reg is_sublist
);

  reg [0:7] match_positions;
  integer i, j;

  always @* begin
    // Default: no match
    is_sublist = 1'b0;

    // Handle edge cases
    if (sub_len == 0) begin
      is_sublist = 1'b1;
    end else if (sub_len > 8) begin
      is_sublist = 1'b0;
    end else begin
      // Check each possible starting position
      for (i = 0; i <= 7; i = i + 1) begin
        match_positions[i] = 1'b1;
        
        // Check if sublist fits starting at position i
        if (i + sub_len > 8) begin
          match_positions[i] = 1'b0;
        end else begin
          // Check each element in the sublist
          for (j = 0; j < sub_len; j = j + 1) begin
            if (main_list[i + j] != sub_list[j]) begin
              match_positions[i] = 1'b0;
            end
          end
        end
      end

      // OR all match positions
      is_sublist = |match_positions;
    end
  end

endmodule