module array_intersperse(
  input [2:0] length,
  input [7:0] delimeter,
  input [3:0][7:0] input_array,
  output reg [3:0] output_length,
  output reg [6:0][7:0] result_array
);
  always_comb begin
    result_array = '0;
    if (length == 0) begin
      output_length = 4'd0;
    end else begin
      output_length = (length << 1) - 1;
      result_array[0] = input_array[0];
      if (length > 1) begin
        result_array[1] = delimeter;
        result_array[2] = input_array[1];
      end
      if (length > 2) begin
        result_array[3] = delimeter;
        result_array[4] = input_array[2];
      end
      if (length > 3) begin
        result_array[5] = delimeter;
        result_array[6] = input_array[3];
      end
    end
  end
endmodule