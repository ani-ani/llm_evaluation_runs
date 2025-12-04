module list_tuple_append(
  input [2:0] input_size,
  input [7:0] input_list [5:0],
  input [7:0] tuple_element1,
  input [7:0] tuple_element2,
  output reg [7:0] output_list [7:0],
  output reg [3:0] output_size
);

integer i;

always @* begin
  // Default: all zero
  for (i = 0; i < 8; i++) output_list[i] = 8'h0;
  output_size = 4'b0;

  // Copy valid input list elements
  for (i = 0; i < 6; i++) begin
    if (i < input_size) output_list[i] = input_list[i];
  end

  // Append tuple elements
  if (input_size < 7) begin
    output_list[input_size] = tuple_element1;
    if (input_size + 1 < 8) output_list[input_size + 1] = tuple_element2;
  end

  // Update output size (input_size + 2, capped at 8)
  output_size = input_size + 4'b10;
  if (output_size > 4'd8) output_size = 4'd8;
end

endmodule