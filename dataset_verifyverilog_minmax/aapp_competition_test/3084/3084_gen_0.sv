module clock_adjust_counter(
  input reg [3:0] start_ht,  // Start hour tens (0-2)
  input reg [3:0] start_hu,  // Start hour units (0-9)
  input reg [3:0] start_mt,  // Start minute tens (0-5)
  input reg [3:0] start_mu,  // Start minute units (0-9)
  input reg [3:0] target_ht, // Target hour tens (0-2)
  input reg [3:0] target_hu, // Target hour units (0-9)
  input reg [3:0] target_mt, // Target minute tens (0-5)
  input reg [3:0] target_mu, // Target minute units (0-9)
  output wire [5:0] count    // Number of displayed times (N+1)
);

  // Compute per-digit minimum adjustment steps
  wire [3:0] diff_ht_inc = (target_ht >= start_ht) ? (target_ht - start_ht) : (4'd10 - (start_ht - target_ht));
  wire [3:0] diff_ht_dec = (start_ht >= target_ht) ? (start_ht - target_ht) : (4'd10 - (target_ht - start_ht));
  wire [3:0] min_ht = (diff_ht_inc <= diff_ht_dec) ? diff_ht_inc : diff_ht_dec;

  wire [3:0] diff_hu_inc = (target_hu >= start_hu) ? (target_hu - start_hu) : (4'd10 - (start_hu - target_hu));
  wire [3:0] diff_hu_dec = (start_hu >= target_hu) ? (start_hu - target_hu) : (4'd10 - (target_hu - start_hu));
  wire [3:0] min_hu = (diff_hu_inc <= diff_hu_dec) ? diff_hu_inc : diff_hu_dec;

  wire [3:0] diff_mt_inc = (target_mt >= start_mt) ? (target_mt - start_mt) : (4'd10 - (start_mt - target_mt));
  wire [3:0] diff_mt_dec = (start_mt >= target_mt) ? (start_mt - target_mt) : (4'd10 - (target_mt - start_mt));
  wire [3:0] min_mt = (diff_mt_inc <= diff_mt_dec) ? diff_mt_inc : diff_mt_dec;

  wire [3:0] diff_mu_inc = (target_mu >= start_mu) ? (target_mu - start_mu) : (4'd10 - (start_mu - target_mu));
  wire [3:0] diff_mu_dec = (start_mu >= target_mu) ? (start_mu - target_mu) : (4'd10 - (target_mu - start_mu));
  wire [3:0] min_mu = (diff_mu_inc <= diff_mu_dec) ? diff_mu_inc : diff_mu_dec;

  // Sum minima and add 1 to get total distinct displayed times
  wire [5:0] sum_min = {2'b00, min_ht} + {2'b00, min_hu} + {2'b00, min_mt} + {2'b00, min_mu};
  assign count = sum_min + 6'b1;

endmodule
