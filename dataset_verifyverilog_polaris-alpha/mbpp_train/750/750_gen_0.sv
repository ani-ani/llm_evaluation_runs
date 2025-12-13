module list_tuple_append(
  input  [2:0] input_size,        // Valid elements in input_list (1-6)
  input  [7:0] input_list [5:0], // 6-element input array
  input  [7:0] tuple_element1,
  input  [7:0] tuple_element2,
  output reg [7:0] output_list [7:0], // 8-element output array
  output reg [3:0] output_size
);

  integer i;

  always @* begin
    // Default all outputs to zero
    for (i = 0; i < 8; i = i + 1) begin
      output_list[i] = 8'b0;
    end

    // Copy valid input_list elements
    for (i = 0; i < input_size; i = i + 1) begin
      output_list[i] = input_list[i];
    end

    // Append tuple elements (only when within output range)
    if (input_size < 8) begin
      output_list[input_size] = tuple_element1;
    end

    if ((input_size + 1) < 8) begin
      output_list[input_size + 1] = tuple_element2;
    end

    // Compute output_size = input_size + 2 (max 8)
    output_size = input_size + 4'd2;
  end

endmodule