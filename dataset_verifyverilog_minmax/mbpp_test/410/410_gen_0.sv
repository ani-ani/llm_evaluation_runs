module min_hetero_list(
  input [5:0] elem_0, elem_1, elem_2, elem_3,
  input [5:0] elem_4, elem_5, elem_6, elem_7,
  input [7:0] validity_mask,
  output reg [5:0] min_val
);

  always @(*) begin
    // Initialize to maximum value (63) to represent undefined state
    min_val = 6'b111111;
    
    // Check each element only if its validity bit is set
    if (validity_mask[0]) min_val = elem_0;
    if (validity_mask[1]) min_val = (min_val > elem_1) ? elem_1 : min_val;
    if (validity_mask[2]) min_val = (min_val > elem_2) ? elem_2 : min_val;
    if (validity_mask[3]) min_val = (min_val > elem_3) ? elem_3 : min_val;
    if (validity_mask[4]) min_val = (min_val > elem_4) ? elem_4 : min_val;
    if (validity_mask[5]) min_val = (min_val > elem_5) ? elem_5 : min_val;
    if (validity_mask[6]) min_val = (min_val > elem_6) ? elem_6 : min_val;
    if (validity_mask[7]) min_val = (min_val > elem_7) ? elem_7 : min_val;
    
    // If no valid elements were found, output 0
    if (min_val == 6'b111111) min_val = 0;
  end
endmodule