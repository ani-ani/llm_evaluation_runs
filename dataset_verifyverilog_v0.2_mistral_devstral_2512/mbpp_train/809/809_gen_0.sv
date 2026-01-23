module tuple_compare (
  input [7:0] tuple1 [0:7],
  input [7:0] tuple2 [0:7],
  input [2:0] length,
  output reg result
);

  integer i;
  reg [0:7] all_less;

  always @* begin
    all_less = 1'b1;
    for (i = 0; i < length; i = i + 1) begin
      if (tuple2[i] >= tuple1[i]) begin
        all_less = 1'b0;
      end
    end
    result = all_less;
  end

endmodule