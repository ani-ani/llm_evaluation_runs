module add_even_at_odd_indices(
  input [2:0] length,
  input [7:0] lst [7:0],
  output reg [10:0] sum
);
  integer i;
  always @(*) begin
    sum = 0;
    for (i = 0; i < 8; i = i + 1) begin
      if (i < length) begin
        if (i[0] == 1) begin  // odd index
          if (lst[i][0] == 0) begin  // even value
            sum = sum + lst[i];
          end
        end
      end
    end
  end
endmodule