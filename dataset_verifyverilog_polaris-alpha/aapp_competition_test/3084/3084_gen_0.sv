module clock_adjust_counter(
  input  [3:0] start_ht,
  input  [3:0] start_hu,
  input  [3:0] start_mt,
  input  [3:0] start_mu,
  input  [3:0] target_ht,
  input  [3:0] target_hu,
  input  [3:0] target_mt,
  input  [3:0] target_mu,
  output [5:0] count
);

  // Internal wires for per-digit differences
  wire [3:0] inc_ht, dec_ht, inc_hu, dec_hu, inc_mt, dec_mt, inc_mu, dec_mu;
  wire [3:0] min_ht, min_hu, min_mt, min_mu;
  wire [5:0] sum_min;

  // Increasing steps: (target - start + 10) % 10
  assign inc_ht = (target_ht + 4'd10 - start_ht) % 4'd10;
  assign inc_hu = (target_hu + 4'd10 - start_hu) % 4'd10;
  assign inc_mt = (target_mt + 4'd10 - start_mt) % 4'd10;
  assign inc_mu = (target_mu + 4'd10 - start_mu) % 4'd10;

  // Decreasing steps: (start - target + 10) % 10
  assign dec_ht = (start_ht + 4'd10 - target_ht) % 4'd10;
  assign dec_hu = (start_hu + 4'd10 - target_hu) % 4'd10;
  assign dec_mt = (start_mt + 4'd10 - target_mt) % 4'd10;
  assign dec_mu = (start_mu + 4'd10 - target_mu) % 4'd10;

  // Per-digit minima
  assign min_ht = (inc_ht <= dec_ht) ? inc_ht : dec_ht;
  assign min_hu = (inc_hu <= dec_hu) ? inc_hu : dec_hu;
  assign min_mt = (inc_mt <= dec_mt) ? inc_mt : dec_mt;
  assign min_mu = (inc_mu <= dec_mu) ? inc_mu : dec_mu;

  // Sum of minima (up to 4 * 9 = 36), then +1
  assign sum_min = {2'b00, min_ht} +
                   {2'b00, min_hu} +
                   {2'b00, min_mt} +
                   {2'b00, min_mu};

  assign count = sum_min + 6'd1;

endmodule