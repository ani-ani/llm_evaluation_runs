module odd_position (
  input [7:0][7:0] data,
  input [2:0] length,
  output reg result
);

  integer i;
  reg [7:0] current_elem;
  reg is_odd_index;
  reg is_odd_value;
  reg valid;

  always @* begin
    result = 1'b1;
    for (i = 0; i < length; i = i + 1) begin
      current_elem = data[i];
      is_odd_index = (i % 2 == 1);
      is_odd_value = (current_elem[0] == 1'b1);
      valid = (is_odd_index == is_odd_value);
      if (!valid) begin
        result = 1'b0;
      end
    end
  end

endmodule