module odd_digit_counter(
  input [63:0] str_i,
  output [3:0] count
);
  
  wire [7:0] odd_flags = {
    str_i[56], // Character 8 (LSb position of byte 7)
    str_i[48], // Character 7
    str_i[40], // Character 6
    str_i[32], // Character 5
    str_i[24], // Character 4
    str_i[16], // Character 3
    str_i[8],  // Character 2
    str_i[0]   // Character 1
  };

  assign count = odd_flags[0] + odd_flags[1] + odd_flags[2] + odd_flags[3]
               + odd_flags[4] + odd_flags[5] + odd_flags[6] + odd_flags[7];
endmodule