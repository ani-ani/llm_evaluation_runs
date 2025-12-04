module path_sum_optimizer(
  input [3:0] k [0:7], // Up to 8 fragments (4 bits each, 0-15)
  input [2:0] num_fragments, // Actual fragment count (0-8)
  output logic [6:0] min_sum
);

const int primes[6] = '{2, 3, 5, 7, 11, 13};

function [3:0] exponent(int k, int p);
  int count = 0;
  int pow = p;
  while (pow <= k) begin
    count += k / pow;
    pow *= p;
  end
  return count;
endfunction

const int LUT[16][6] = compute_LUT();

function [3:0] compute_LUT[16][6];
  for (int k_val = 0; k_val <= 15; k_val++) begin
    for (int p = 0; p < 6; p++) begin
      compute_LUT[k_val][p] = exponent(k_val, primes[p]);
    end
  end
endfunction

always_comb begin
  int count[6][16];
  for (int j = 0; j < 6; j++) begin
    for (int e = 0; e < 16; e++) begin
      count[j][e] = 0;
    end
  end

  for (int i = 0; i < num_fragments; i++) begin
    for (int j = 0; j < 6; j++) begin
      int exp = LUT[k[i]][j];
      count[j][exp]++;
    end
  end

  int majority_exp[6];
  for (int j = 0; j < 6; j++) begin
    int max_count = -1;
    int min_exp = 15;
    for (int e = 0; e < 16; e++) begin
      if (count[j][e] > max_count) begin
        max_count = count[j][e];
        min_exp = e;
      end else if (count[j][e] == max_count) begin
        if (e < min_exp) begin
          min_exp = e;
        end
      end
    end
    majority_exp[j] = min_exp;
  end

  min_sum = 0;
  for (int j = 0; j < 6; j++) begin
    min_sum += majority_exp[j];
  end
end

endmodule