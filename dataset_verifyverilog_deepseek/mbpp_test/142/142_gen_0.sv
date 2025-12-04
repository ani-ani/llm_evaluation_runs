module list_position_matcher(
  input [31:0] list1,
  input [31:0] list2,
  input [31:0] list3,
  output reg [3:0] match_count
);
  always_comb begin
    match_count = '0;
    for (int i = 0; i < 8; i++) begin
      if ((list1[4*i +:4] == list2[4*i +:4]) && 
          (list1[4*i +:4] == list3[4*i +:4])) begin
        match_count++;
      end
    end
  end
endmodule