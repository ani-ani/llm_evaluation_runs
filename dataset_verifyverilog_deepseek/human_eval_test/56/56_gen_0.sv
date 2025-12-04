module bracket_checker(input [15:0] brackets, output result);
  logic signed [5:0] balance [0:15];
  logic [15:0] neg_flags;
  
  assign balance[0] = brackets[0] ? 6'sd-1 : 6'sd1;
  
  generate
    for (genvar i = 1; i < 16; i++) begin
      assign balance[i] = balance[i-1] + (brackets[i] ? 6'sd-1 : 6'sd1);
    end
  endgenerate
  
  generate
    for (genvar i = 0; i < 16; i++) begin
      assign neg_flags[i] = (balance[i] < 0);
    end
  endgenerate
  
  assign result = !(|neg_flags) && (balance[15] == 0);
endmodule