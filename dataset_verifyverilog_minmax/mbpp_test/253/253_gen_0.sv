module integer_counter (
  input  [3:0] is_int,
  output reg [2:0] count
);

  // Count number of '1's in is_int
  always @* begin
    count = 3'd0;
    for (int i = 0; i < 4; i++) begin
      if (is_int[i]) count = count + 1'b1;
    end
  end

endmodule
