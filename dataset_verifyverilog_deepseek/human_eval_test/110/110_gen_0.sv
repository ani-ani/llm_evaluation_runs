module list_even_exchange(
  input reg [7:0] lst1 [0:3],
  input reg [7:0] lst2 [0:3],
  output logic result
);
  
  wire [2:0] odd1_count = lst1[0][0] + lst1[1][0] + lst1[2][0] + lst1[3][0];
  wire [2:0] even2_count = !lst2[0][0] + !lst2[1][0] + !lst2[2][0] + !lst2[3][0];
  
  assign result = (odd1_count <= even2_count) ? 1'b1 : 1'b0;
  
endmodule