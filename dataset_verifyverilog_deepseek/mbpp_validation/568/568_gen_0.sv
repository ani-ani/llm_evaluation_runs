module empty_list(input [2:0] length, output reg [0:7] arr);
  always_comb begin
    for (int i = 0; i < 8; i++) begin
      arr[i] = (i < (length + 1)) ? 1'b0 : 1'b1;
    end
  end
endmodule