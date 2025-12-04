module count_lists (
  input  reg [7:0] sublist_mask,
  output reg [3:0] count
);
  always_comb begin
    count = $countones(sublist_mask);
  end
endmodule