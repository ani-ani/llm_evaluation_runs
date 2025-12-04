module list_position_matcher (
  input [3:0] list1 [7:0],
  input [3:0] list2 [7:0],
  input [3:0] list3 [7:0],
  output reg [3:0] match_count
);

integer i;
reg [3:0] count;

always @* begin
  count = 4'b0;
  for (i = 0; i < 8; i = i + 1) begin
    if (list1[i] == list2[i] && list2[i] == list3[i])
      count = count + 1;
  end
  match_count = count;
end

endmodule