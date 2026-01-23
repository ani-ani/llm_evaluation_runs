module find_element_after_rotations (
  input [2:0] index_final,
  input [1:0] num_rotations,
  input [2:0] rotation_ranges_left [3:0],
  input [2:0] rotation_ranges_right [3:0],
  input [3:0][2:0] array_data,
  output reg [2:0] result
);

  reg [2:0] current_index;
  integer i;

  always @* begin
    current_index = index_final;
    for (i = num_rotations - 1; i >= 0; i = i - 1) begin
      if (current_index >= rotation_ranges_left[i] && current_index <= rotation_ranges_right[i]) begin
        if (current_index == rotation_ranges_left[i]) begin
          current_index = rotation_ranges_right[i];
        end else begin
          current_index = current_index - 1;
        end
      end
    end
    result = array_data[current_index];
  end

endmodule