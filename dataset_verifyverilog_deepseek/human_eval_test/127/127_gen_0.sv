module interval_prime_check (
  input reg [7:0] a_start,
  input reg [7:0] a_end,
  input reg [7:0] b_start,
  input reg [7:0] b_end,
  output logic prime_found
);

  logic signed [7:0] a_start_s;
  logic signed [7:0] a_end_s;
  logic signed [7:0] b_start_s;
  logic signed [7:0] b_end_s;
  assign a_start_s = $signed(a_start);
  assign a_end_s = $signed(a_end);
  assign b_start_s = $signed(b_start);
  assign b_end_s = $signed(b_end);

  logic signed [7:0] intersection_start;
  logic signed [7:0] intersection_end;
  assign intersection_start = (a_start_s > b_start_s) ? a_start_s : b_start_s;
  assign intersection_end = (a_end_s < b_end_s) ? a_end_s : b_end_s;

  logic [7:0] len;
  assign len = intersection_end - intersection_start;

  function automatic logic [255:0] prime_lut_gen();
    logic [255:0] lut = '0;
    int primes[] = '{2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59,61,67,71,73,79,83,89,97,101,103,107,109,113,127,131,137,139,149,151,157,163,167,173,179,181,191,193,197,199,211,223,227,229,233,239,241,251};
    foreach (primes[i]) lut[primes[i]] = 1'b1;
    return lut;
  endfunction

  localparam bit [255:0] PRIME_LUT = prime_lut_gen();

  logic valid_intersection;
  logic len_ge_2;
  logic is_prime;
  assign valid_intersection = (intersection_start <= intersection_end);
  assign len_ge_2 = (len >= 8'd2);
  assign is_prime = PRIME_LUT[len];

  assign prime_found = valid_intersection && len_ge_2 && is_prime;

endmodule