module dict_case_checker #(
  parameter int MAX_KEYS = 4,
  parameter int KEY_WIDTH = 8
) (
  input [3:0] key_count,
  input [MAX_KEYS-1:0][KEY_WIDTH-1:0] keys,
  output logic is_case_consistent
);
  
  wire [3:0] valid;
  wire [3:0] is_letter, is_upper;
  wire all_valid_letters;
  wire case_ok;

  assign valid[0] = (0 < key_count);
  assign valid[1] = (1 < key_count);
  assign valid[2] = (2 < key_count);
  assign valid[3] = (3 < key_count);
  
  assign is_letter[0] = (keys[0] >= 8'h41 && keys[0] <= 8'h5A) || (keys[0] >= 8'h61 && keys[0] <= 8'h7A);
  assign is_letter[1] = (keys[1] >= 8'h41 && keys[1] <= 8'h5A) || (keys[1] >= 8'h61 && keys[1] <= 8'h7A);
  assign is_letter[2] = (keys[2] >= 8'h41 && keys[2] <= 8'h5A) || (keys[2] >= 8'h61 && keys[2] <= 8'h7A);
  assign is_letter[3] = (keys[3] >= 8'h41 && keys[3] <= 8'h5A) || (keys[3] >= 8'h61 && keys[3] <= 8'h7A);
  
  assign is_upper[0] = (keys[0] >= 8'h41 && keys[0] <= 8'h5A);
  assign is_upper[1] = (keys[1] >= 8'h41 && keys[1] <= 8'h5A);
  assign is_upper[2] = (keys[2] >= 8'h41 && keys[2] <= 8'h5A);
  assign is_upper[3] = (keys[3] >= 8'h41 && keys[3] <= 8'h5A);
  
  assign all_valid_letters = & ((~valid) | is_letter);
  
  assign case_ok = ( ~valid[1] || (is_upper[1] == is_upper[0]) ) &&
                  ( ~valid[2] || (is_upper[2] == is_upper[0]) ) &&
                  ( ~valid[3] || (is_upper[3] == is_upper[0]) );
  
  assign is_case_consistent = (key_count != 4'b0) && all_valid_letters && case_ok;
  
endmodule