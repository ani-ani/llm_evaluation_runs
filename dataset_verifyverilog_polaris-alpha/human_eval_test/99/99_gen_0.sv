module closest_integer(
  input  [31:0] fixed_point_number,
  output reg [16:0] rounded_value
);

  wire signed [15:0] integer_part;
  wire [15:0]       fractional_part;
  wire              int_positive;

  assign integer_part    = fixed_point_number[31:16];
  assign fractional_part = fixed_point_number[15:0];
  assign int_positive    = (integer_part >= 0);

  always @(*) begin
    if (fractional_part < 16'h8000) begin
      rounded_value = {{1{integer_part[15]}}, integer_part};
    end else if (fractional_part > 16'h8000) begin
      if (int_positive) begin
        rounded_value = {{1{integer_part[15]}}, integer_part} + 17'sd1;
      end else begin
        rounded_value = {{1{integer_part[15]}}, integer_part} - 17'sd1;
      end
    end else begin // fractional_part == 16'h8000
      if (int_positive) begin
        rounded_value = {{1{integer_part[15]}}, integer_part} + 17'sd1;
      end else begin
        rounded_value = {{1{integer_part[15]}}, integer_part} - 17'sd1;
      end
    end
  end

endmodule