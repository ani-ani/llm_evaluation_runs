module common_element (
  input [7:0][7:0] list1,
  input [7:0] list1_valid,
  input [7:0][7:0] list2,
  input [7:0] list2_valid,
  output result
);
  logic temp;
  always_comb begin
    temp = 1'b0;
    for (int i=0; i<8; i++) begin
      for (int j=0; j<8; j++) begin
        if (list1_valid[i] && list2_valid[j] && (list1[i] == list2[j])) begin
          temp = 1'b1;
        end
      end
    end
  end
  assign result = temp;
endmodule