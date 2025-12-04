module pos_counter (
  input signed [3:0] numbers [3:0], // 4-element array of 4-bit signed integers (-8..7)
  output reg [2:0] pos_count            // Count of elements >= 0 (0..4)
);
  integer i;
  always @* begin
    pos_count = 3'd0;
    for (i = 0; i < 4; i = i + 1) begin
      // Non-negative if sign bit (MSB) is 0
      if (~numbers[i][3]) pos_count = pos_count + 1'b1;
    end
  end
endmodule