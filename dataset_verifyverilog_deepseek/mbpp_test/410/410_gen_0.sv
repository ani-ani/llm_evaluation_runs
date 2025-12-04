module min_hetero_list(
  input [5:0] elem_0, elem_1, elem_2, elem_3, elem_4, elem_5, elem_6, elem_7,
  input [7:0] validity_mask,
  output logic [5:0] min_val
);
  
  wire [5:0] processed_elem [0:7];
  assign processed_elem[0] = validity_mask[0] ? elem_0 : 6'b111111;
  assign processed_elem[1] = validity_mask[1] ? elem_1 : 6'b111111;
  assign processed_elem[2] = validity_mask[2] ? elem_2 : 6'b111111;
  assign processed_elem[3] = validity_mask[3] ? elem_3 : 6'b111111;
  assign processed_elem[4] = validity_mask[4] ? elem_4 : 6'b111111;
  assign processed_elem[5] = validity_mask[5] ? elem_5 : 6'b111111;
  assign processed_elem[6] = validity_mask[6] ? elem_6 : 6'b111111;
  assign processed_elem[7] = validity_mask[7] ? elem_7 : 6'b111111;
  
  wire [5:0] min01 = (processed_elem[0] < processed_elem[1]) ? processed_elem[0] : processed_elem[1];
  wire [5:0] min23 = (processed_elem[2] < processed_elem[3]) ? processed_elem[2] : processed_elem[3];
  wire [5:0] min45 = (processed_elem[4] < processed_elem[5]) ? processed_elem[4] : processed_elem[5];
  wire [5:0] min67 = (processed_elem[6] < processed_elem[7]) ? processed_elem[6] : processed_elem[7];
  
  wire [5:0] min03 = (min01 < min23) ? min01 : min23;
  wire [5:0] min47 = (min45 < min67) ? min45 : min67;    
  wire [5:0] min07 = (min03 < min47) ? min03 : min47;
  
  wire any_valid = |validity_mask;
  
  assign min_val = any_valid ? min07 : 6'b0;
  
endmodule