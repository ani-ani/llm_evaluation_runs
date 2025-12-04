module even_xor_pairs_counter (
  input [7:0] a0,
  input [7:0] a1,
  input [7:0] a2,
  input [7:0] a3,
  input [7:0] a4,
  input [7:0] a5,
  input [7:0] a6,
  input [7:0] a7,
  output logic [4:0] count
);
  logic [3:0] zeros, ones;
  // Count how many inputs have LSB=0 and LSB=1
  assign zeros = ~a0[0] + ~a1[0] + ~a2[0] + ~a3[0] + ~a4[0] + ~a5[0] + ~a6[0] + ~a7[0];
  assign ones  =  a0[0] +  a1[0] +  a2[0] +  a3[0] +  a4[0] +  a5[0] +  a6[0] +  a7[0];
  // Pairs are valid when both LSBs match (both 0 or both 1)
  assign count = (zeros * (zeros - 1)) >> 1 + (ones * (ones - 1)) >> 1;
endmodule