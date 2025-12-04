module array_intersperse(
  input [2:0] length,
  input [7:0] delimeter,
  input [3:0][7:0] input_array,
  output reg [3:0] output_length,
  output reg [6:0][7:0] result_array
);
  always_comb begin
    output_length = 0;
    result_array = '{default:0};
    if (length != 0) begin
      output_length = 2 * length - 1;
      for (int i = 0; i < length; i++) begin
        result_array[2*i] = input_array[i];
      end
      for (int j = 0; j < (length - 1); j++) begin
        result_array[2*j + 1] = delimeter;
      end
    end
  end
endmodule