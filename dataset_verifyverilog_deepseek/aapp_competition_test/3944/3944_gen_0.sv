module card_game_victory_counter(
  input clk,
  input rst_n,
  input start,
  input [3:0] N,
  input [3:0] M,
  input [3:0] K,
  output reg [29:0] result,
  output reg done
);

  localparam MOD = 30'd1000000007;
  reg [29:0] factorials [0:32];
  reg [29:0] pow2 [0:32];
  reg [29:0] pow3 [0:32];
  reg [29:0] inv_fact [0:32];

  always @(*) begin
    // Initialize factorials[0]
    factorials[0] = 1;
    // Precompute factorials[1:32]
    for (int i = 1; i <= 32; i = i + 1) begin
      factorials[i] = (factorials[i-1] * i) % MOD;
    end

    // Precompute pow2[0:32]
    pow2[0] = 1;
    for (int i = 1; i <= 32; i = i + 1) begin
      pow2[i] = (pow2[i-1] * 2) % MOD;
    end

    // Precompute pow3[0:32]
    pow3[0] = 1;
    for (int i = 1; i <= 32; i = i + 1) begin
      pow3[i] = (pow3[i-1] * 3) % MOD;
    end

    // Precompute modular inverses of factorials (manually precalculated values)
    inv_fact[0] = 1;
    inv_fact[1] = 1;
    inv_fact[2] = 500000004;
    inv_fact[3] = 166666668;
    inv_fact[4] = 41666667;
    inv_fact[5] = 808333339;
    inv_fact[6] = 301388891;
    inv_fact[7] = 432114857;
    inv_fact[8] = 480190476;
    inv_fact[9] = 887333448;
    inv_fact[10] = 165714082;
    inv_fact[11] = 283865222;
    inv_fact[12] = 388444897;
    inv_fact[13] = 84231735;
    inv_fact[14] = 679802814;
    inv_fact[15] = 631701197;
    inv_fact[16] = 302336712;
    inv_fact[17] = 461440341;
    inv_fact[18] = 12800027;
    inv_fact[19] = 771230564;
    inv_fact[20] = 364398335;
    inv_fact[21] = 166057164;
    inv_fact[22] = 204543276;
    inv_fact[23] = 386873252;
    inv_fact[24] = 14001621;
    inv_fact[25] = 232577332;
    inv_fact[26] = 930293605;
    inv_fact[27] = 751115473;
    inv_fact[28] = 412748672;
    inv_fact[29] = 764509139;
    inv_fact[30] = 58923725;
    inv_fact[31] = 689285307;
    inv_fact[32] = 761754098;
  end

  reg [29:0] temp_result;
  always @(*) begin
    temp_result = 0;
    if (start) begin
      for (int a = 0; a <= K; a = a + 1) begin
        int b = K - a;
        reg [29:0] sum_term;
        sum_term = 0;
        for (int t = 0; t <= M + N; t = t + 1) begin
          if (t <= N && (M + N - t) <= M) begin
            reg [29:0] comb_term;
            comb_term = (factorials[M + N] * inv_fact[t]) % MOD;
            comb_term = (comb_term * inv_fact[M + N - t]) % MOD;
            comb_term = (comb_term * pow2[t]) % MOD;
            comb_term = (comb_term * pow3[M + N - t]) % MOD;
            sum_term = (sum_term + comb_term) % MOD;
          end
        end
        sum_term = (sum_term * pow2[a]) % MOD;
        sum_term = (sum_term * pow3[b]) % MOD;
        temp_result = (temp_result + sum_term) % MOD;
      end
    end
  end

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      result <= 0;
      done <= 0;
    end else begin
      if (start) begin
        result <= temp_result;
        done <= 1;
      end else begin
        done <= 0;
      end
    end
  end
endmodule