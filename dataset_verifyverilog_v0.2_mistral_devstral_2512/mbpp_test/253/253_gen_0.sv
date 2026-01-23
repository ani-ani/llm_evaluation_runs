module count_integers (
  input [7:0] data [0:7],
  output [3:0] count
);
  wire [0:7] is_int;
  integer i;
  
  // Check each element in parallel
  for (i = 0; i < 8; i = i + 1) begin
    is_int[i] = (data[i][7:4] == 4'b0001);
  end
  
  // Count the number of integer elements
  assign count = is_int[0] + is_int[1] + is_int[2] + is_int[3] + 
                 is_int[4] + is_int[5] + is_int[6] + is_int[7];
endmodule