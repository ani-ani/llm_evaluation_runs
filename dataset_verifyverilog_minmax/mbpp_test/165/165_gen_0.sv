module char_position_counter(
  input [7:0] str [0:7],
  output reg [3:0] count
);
  integer i;
  always @* begin
    count = 0;
    for (i = 0; i < 8; i = i + 1) begin
      if (str[i] === 8'(65 + i) || str[i] === 8'(97 + i))
        count = count + 1;
    end
  end
endmodule