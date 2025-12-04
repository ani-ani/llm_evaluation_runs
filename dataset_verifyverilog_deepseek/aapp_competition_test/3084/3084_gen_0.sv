module clock_adjust_counter(
  input [3:0] start_ht,
  input [3:0] start_hu,
  input [3:0] start_mt,
  input [3:0] start_mu,
  input [3:0] target_ht,
  input [3:0] target_hu,
  input [3:0] target_mt,
  input [3:0] target_mu,
  output [5:0] count
);

  wire [4:0] ht_inc_diff = {1'b0,target_ht} - {1'b0,start_ht};
  wire [4:0] ht_inc_full = ht_inc_diff + 5'd10;
  wire [3:0] ht_inc_steps = (ht_inc_full >= 5'd10) ? (ht_inc_full - 5'd10) : ht_inc_full[3:0];
  
  wire [4:0] ht_dec_diff = {1'b0,start_ht} - {1'b0,target_ht};
  wire [4:0] ht_dec_full = ht_dec_diff + 5'd10;
  wire [3:0] ht_dec_steps = (ht_dec_full >= 5'd10) ? (ht_dec_full - 5'd10) : ht_dec_full[3:0];
  
  wire [3:0] ht_min = (ht_inc_steps < ht_dec_steps) ? ht_inc_steps : ht_dec_steps;

  wire [4:0] hu_inc_diff = {1'b0,target_hu} - {1'b0,start_hu};
  wire [4:0] hu_inc_full = hu_inc_diff + 5'd10;
  wire [3:0] hu_inc_steps = (hu_inc_full >= 5'd10) ? (hu_inc_full - 5'd10) : hu_inc_full[3:0];
  
  wire [4:0] hu_dec_diff = {1'b0,start_hu} - {1'b0,target_hu};
  wire [4:0] hu_dec_full = hu_dec_diff + 5'd10;
  wire [3:0] hu_dec_steps = (hu_dec_full >= 5'd10) ? (hu_dec_full - 5'd10) : hu_dec_full[3:0];
  
  wire [3:0] hu_min = (hu_inc_steps < hu_dec_steps) ? hu_inc_steps : hu_dec_steps;

  wire [4:0] mt_inc_diff = {1'b0,target_mt} - {1'b0,start_mt};
  wire [4:0] mt_inc_full = mt_inc_diff + 5'd10;
  wire [3:0] mt_inc_steps = (mt_inc_full >= 5'd10) ? (mt_inc_full - 5'd10) : mt_inc_full[3:0];
  
  wire [4:0] mt_dec_diff = {1'b0,start_mt} - {1'b0,target_mt};
  wire [4:0] mt_dec_full = mt_dec_diff + 5'd10;
  wire [3:0] mt_dec_steps = (mt_dec_full >= 5'd10) ? (mt_dec_full - 5'd10) : mt_dec_full[3:0];
  
  wire [3:0] mt_min = (mt_inc_steps < mt_dec_steps) ? mt_inc_steps : mt_dec_steps;

  wire [4:0] mu_inc_diff = {1'b0,target_mu} - {1'b0,start_mu};
  wire [4:0] mu_inc_full = mu_inc_diff + 5'd10;
  wire [3:0] mu_inc_steps = (mu_inc_full >= 5'd10) ? (mu_inc_full - 5'd10) : mu_inc_full[3:0];
  
  wire [4:0] mu_dec_diff = {1'b0,start_mu} - {1'b0,target_mu};
  wire [4:0] mu_dec_full = mu_dec_diff + 5'd10;
  wire [3:0] mu_dec_steps = (mu_dec_full >= 5'd10) ? (mu_dec_full - 5'd10) : mu_dec_full[3:0];
  
  wire [3:0] mu_min = (mu_inc_steps < mu_dec_steps) ? mu_inc_steps : mu_dec_steps;

  wire [5:0] total_sum = ht_min + hu_min + mt_min + mu_min;
  assign count = total_sum + 6'd1;

endmodule