module tuple_to_int (
  input [15:0] digits,  // Four 4-bit digits: [d3,d2,d1,d0]
  output [13:0] result  // Combined integer: d3*1000 + d2*100 + d1*10 + d0
);

  // Extract individual digits
  wire [3:0] d3 = digits[15:12];  // Thousands digit
  wire [3:0] d2 = digits[11:8];   // Hundreds digit
  wire [3:0] d1 = digits[7:4];    // Tens digit
  wire [3:0] d0 = digits[3:0];    // Ones digit

  // Combine digits into integer result
  assign result = d3 * 1000 + d2 * 100 + d1 * 10 + d0;

endmodule