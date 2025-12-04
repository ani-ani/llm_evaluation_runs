module unique_element_finder(input reg [7:0] arr[0:15], output reg [7:0] unique_num);

integer i;
always_comb begin
  unique_num = 0;
  for (i = 0; i < 16; i++) begin
    unique_num = unique_num ^ arr[i];
  end
end

endmodule