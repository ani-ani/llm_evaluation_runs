module pairs_sum_to_zero(
  input [5:0] l_0,
  input [5:0] l_1,
  input [5:0] l_2,
  input [5:0] l_3,
  input [5:0] l_4,
  input [5:0] l_5,
  input [5:0] l_6,
  input [5:0] l_7,
  output out
);

  logic signed [5:0] l[8];
  assign l[0] = l_0;
  assign l[1] = l_1;
  assign l[2] = l_2;
  assign l[3] = l_3;
  assign l[4] = l_4;
  assign l[5] = l_5;
  assign l[6] = l_6;
  assign l[7] = l_7;

  logic temp;
  always_comb begin
    temp = 1'b0;
    for (int i = 0; i < 8; i++) begin
      for (int j = i + 1; j < 8; j++) begin
        if (l[i] + l[j] == 6'sb0) begin
          temp = 1'b1;
        end
      end
    end
  end

  assign out = temp;

endmodule