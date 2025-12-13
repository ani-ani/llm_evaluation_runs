module odd_equivalent(
  input  [7:0] s,
  input  [2:0] n,
  output [3:0] count
);

  integer i;
  reg [3:0] cnt;
  reg [7:0] rotated;

  always @* begin
    cnt = 4'd0;
    for (i = 0; i < n; i = i + 1) begin
      rotated = (s >> i) | (s << (8 - i));
      if (rotated[0])
        cnt = cnt + 1'b1;
    end
  end

  assign count = cnt;

endmodule