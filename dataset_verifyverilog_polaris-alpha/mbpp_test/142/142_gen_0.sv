module list_position_matcher(
  input  [31:0] list1,
  input  [31:0] list2,
  input  [31:0] list3,
  output reg [3:0] match_count
);

  integer i;
  reg [3:0] e1, e2, e3;

  always @* begin
    match_count = 4'd0;
    for (i = 0; i < 8; i = i + 1) begin
      e1 = list1[31 - 4*i -: 4];
      e2 = list2[31 - 4*i -: 4];
      e3 = list3[31 - 4*i -: 4];
      if ((e1 == e2) && (e2 == e3)) begin
        match_count = match_count + 1'b1;
      end
    end
  end

endmodule