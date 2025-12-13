module list_even_exchange(
  input  [7:0] lst1 [0:3],
  input  [7:0] lst2 [0:3],
  output       result
);

  integer i;
  reg [2:0] odd1_count;
  reg [2:0] even2_count;

  always @* begin
    odd1_count  = 3'd0;
    even2_count = 3'd0;

    // Count odd elements in lst1
    for (i = 0; i < 4; i = i + 1) begin
      if (lst1[i][0] == 1'b1)
        odd1_count = odd1_count + 1'b1;
    end

    // Count even elements in lst2
    for (i = 0; i < 4; i = i + 1) begin
      if (lst2[i][0] == 1'b0)
        even2_count = even2_count + 1'b1;
    end
  end

  assign result = (odd1_count <= even2_count) ? 1'b1 : 1'b0;

endmodule