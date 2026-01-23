module find_min_tuple (
  input [7:0] values [0:7],
  input [31:0] names [0:7],
  output reg [31:0] result_name
);

  reg [3:0] min_index;
  reg [7:0] min_value;
  integer i;

  always @* begin
    min_value = values[0];
    min_index = 0;
    for (i = 1; i < 8; i = i + 1) begin
      if (values[i] < min_value) begin
        min_value = values[i];
        min_index = i;
      end
    end
    result_name = names[min_index];
  end

endmodule