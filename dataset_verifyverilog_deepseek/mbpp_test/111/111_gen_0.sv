module common_in_nested(
  input [5:0] list0 [0:7],
  input [5:0] list1 [0:7],
  input [5:0] list2 [0:7],
  output reg [63:0] common
);

  reg [63:0] presence0, presence1, presence2;

  always_comb begin
    presence0 = 64'b0;
    for (int i=0; i<8; i++) begin
      if (|list0[i]) presence0[list0[i]] = 1'b1;
    end
  end

  always_comb begin
    presence1 = 64'b0;
    for (int i=0; i<8; i++) begin
      if (|list1[i]) presence1[list1[i]] = 1'b1;
    end
  end

  always_comb begin
    presence2 = 64'b0;
    for (int i=0; i<8; i++) begin
      if (|list2[i]) presence2[list2[i]] = 1'b1;
    end
  end

  always_comb begin
    common = presence0 & presence1 & presence2;
  end

endmodule