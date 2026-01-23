module uppercase_counter (
  input [7:0][7:0] char_array,
  input [2:0] valid_length,
  output reg [3:0] count
);

  integer i;
  reg [7:0] char;
  reg is_uppercase;
  reg [3:0] temp_count;

  always @* begin
    temp_count = 0;
    for (i = 0; i < 8; i = i + 1) begin
      if (i < valid_length) begin
        char = char_array[i];
        is_uppercase = (char >= 8'h41) && (char <= 8'h5A);
        temp_count = temp_count + is_uppercase;
      end
    end
    count = temp_count;
  end

endmodule