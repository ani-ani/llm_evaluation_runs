module common_in_nested(
  input  [5:0] list0 [0:7],
  input  [5:0] list1 [0:7],
  input  [5:0] list2 [0:7],
  output reg [63:0] common
);

  reg [63:0] presence0;
  reg [63:0] presence1;
  reg [63:0] presence2;

  integer i;

  always @* begin
    presence0 = 64'b0;
    presence1 = 64'b0;
    presence2 = 64'b0;

    // Build presence mask for list0
    for (i = 0; i < 8; i = i + 1) begin
      if (list0[i] != 6'd0)
        presence0[list0[i]] = 1'b1;
    end

    // Build presence mask for list1
    for (i = 0; i < 8; i = i + 1) begin
      if (list1[i] != 6'd0)
        presence1[list1[i]] = 1'b1;
    end

    // Build presence mask for list2
    for (i = 0; i < 8; i = i + 1) begin
      if (list2[i] != 6'd0)
        presence2[list2[i]] = 1'b1;
    end

    // Common elements across all three lists
    common = presence0 & presence1 & presence2;
  end

endmodule