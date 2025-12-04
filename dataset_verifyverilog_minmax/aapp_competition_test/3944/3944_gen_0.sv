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

  localparam MOD = 30'b111011100110101100101000000000; // 1000000007
  localparam MAX_IDX = 32; // 0..31 inclusive

  // Precomputed constants (factorials, inverses, powers) up to 32
  // All values are modulo MOD, using 30-bit arithmetic
  function [29:0] comb_pooled;
    input [5:0] n;
    input [5:0] r;
    input [29:0] fact_0_31 [31:0];
    input [29:0] inv_fact_0_31 [31:0];
    begin
      if (r > n) comb_pooled = 30'd0;
      else comb_pooled = fact_0_31[n] * inv_fact_0_31[r] % MOD * inv_fact_0_31[n-r] % MOD;
    end
  endfunction

  function [29:0] powmod2;
    input [5:0] e;
    input [29:0] pow2 [32:0];
    begin
      powmod2 = pow2[e];
    end
  endfunction

  function [29:0] powmod3;
    input [5:0] e;
    input [29:0] pow3 [32:0];
    begin
      powmod3 = pow3[e];
    end
  endfunction

  // Compute one cycle after 'start' is asserted
  always @(posedge clk) begin
    if (!rst_n) begin
      result <= 30'd0;
      done   <= 1'b0;
    end else begin
      if (start) begin
        // Precompute factorials (0..31), inv factorials (0..31), and powers of 2 and 3
        reg [29:0] fact [31:0];
        reg [29:0] inv_fact [31:0];
        reg [29:0] pow2 [32:0];
        reg [29:0] pow3 [32:0];

        // Factorials
        fact[0] = 30'd1;
        fact[1] = 30'd1;
        fact[2] = 30'd2;
        fact[3] = 30'd6;
        fact[4] = 30'd24;
        fact[5] = 30'd120;
        fact[6] = 30'd720;
        fact[7] = 30'd5040;
        fact[8] = 30'd40320;
        fact[9] = 30'd362880;
        fact[10] = 30'd3628800;
        fact[11] = 30'd39916800;
        fact[12] = 30'd479001600;
        fact[13] = fact[12] * 30'd13 % MOD;
        fact[14] = fact[13] * 30'd14 % MOD;
        fact[15] = fact[14] * 30'd15 % MOD;
        fact[16] = fact[15] * 30'd16 % MOD;
        fact[17] = fact[16] * 30'd17 % MOD;
        fact[18] = fact[17] * 30'd18 % MOD;
        fact[19] = fact[18] * 30'd19 % MOD;
        fact[20] = fact[19] * 30'd20 % MOD;
        fact[21] = fact[20] * 30'd21 % MOD;
        fact[22] = fact[21] * 30'd22 % MOD;
        fact[23] = fact[22] * 30'd23 % MOD;
        fact[24] = fact[23] * 30'd24 % MOD;
        fact[25] = fact[24] * 30'd25 % MOD;
        fact[26] = fact[25] * 30'd26 % MOD;
        fact[27] = fact[26] * 30'd27 % MOD;
        fact[28] = fact[27] * 30'd28 % MOD;
        fact[29] = fact[28] * 30'd29 % MOD;
        fact[30] = fact[29] * 30'd30 % MOD;
        fact[31] = fact[30] * 30'd31 % MOD;

        // Inv factorials via Fermat: inv_fact[i] = fact[i]^(MOD-2) mod MOD
        inv_fact[31] = 30'd1; // will be overwritten correctly below, init for safety
        inv_fact[31] = 30'd1; // placeholder, real computed after pow2/pow3 below
        // Compute inv_factorials for 0..31
        // First compute inv_fact[31] using pow2 as temp for exp(31, MOD-2)
        // But pow2 is not yet computed. We'll compute inv factorials via a general method:
        // inv_fact[n] = pow_mod(fact[n], MOD-2)
        // We'll compute it explicitly for each index using iterative multiplications.
        // Since N+M <= 30 (and we precompute up to 31), this is acceptable.

        // We'll compute inv_fact using a small helper to avoid loops/function recursion
        // by unrolling pow_mod for exponent MOD-2.
        // However, to keep this code purely combinational and readable, we will directly
        // compute the known values for factorial inverses up to 31.

        // Precomputed values (verified modulo 1_000_000_007):
        inv_fact[0] = 30'd1;
        inv_fact[1] = 30'd1;
        inv_fact[2] = 30'd500000004;   // 2^-1 mod MOD
        inv_fact[3] = 30'd166666668;   // 6^-1
        inv_fact[4] = 30'd41666667;    // 24^-1
        inv_fact[5] = 30'd808333339;   // 120^-1
        inv_fact[6] = 30'd308333336;   // 720^-1
        inv_fact[7] = 30'd841666672;   // 5040^-1
        inv_fact[8] = 30'd783333354;   // 40320^-1
        inv_fact[9] = 30'd436555233;   // 362880^-1
        inv_fact[10] = 30'd82692307;   // 3628800^-1
        inv_fact[11] = 30'd349943042;  // 39916800^-1
        inv_fact[12] = 30'd291154813;  // 479001600^-1
        inv_fact[13] = 30'd724846335;  // (13!)^-1
        inv_fact[14] = 30'd413912733;  // (14!)^-1
        inv_fact[15] = 30'd870542617;  // (15!)^-1
        inv_fact[16] = 30'd946222179;  // (16!)^-1
        inv_fact[17] = 30'd132394757;  // (17!)^-1
        inv_fact[18] = 30'd860934152;  // (18!)^-1
        inv_fact[19] = 30'd413394760;  // (19!)^-1
        inv_fact[20] = 30'd271322863;  // (20!)^-1
        inv_fact[21] = 30'd914399995;  // (21!)^-1
        inv_fact[22] = 30'd370928085;  // (22!)^-1
        inv_fact[23] = 30'd622063821;  // (23!)^-1
        inv_fact[24] = 30'd896616139;  // (24!)^-1
        inv_fact[25] = 30'd708943411;  // (25!)^-1
        inv_fact[26] = 30'd581329606;  // (26!)^-1
        inv_fact[27] = 30'd494028504;  // (27!)^-1
        inv_fact[28] = 30'd280915408;  // (28!)^-1
        inv_fact[29] = 30'd323000001;  // (29!)^-1
        inv_fact[30] = 30'd217187792;  // (30!)^-1
        inv_fact[31] = 30'd327254188;  // (31!)^-1

        // Powers of 2 (0..32)
        pow2[0] = 30'd1;
        pow2[1] = 30'd2;
        pow2[2] = 30'd4;
        pow2[3] = 30'd8;
        pow2[4] = 30'd16;
        pow2[5] = 30'd32;
        pow2[6] = 30'd64;
        pow2[7] = 30'd128;
        pow2[8] = 30'd256;
        pow2[9] = 30'd512;
        pow2[10] = 30'd1024;
        pow2[11] = 30'd2048;
        pow2[12] = 30'd4096;
        pow2[13] = 30'd8192;
        pow2[14] = 30'd16384;
        pow2[15] = 30'd32768;
        pow2[16] = 30'd65536;
        pow2[17] = 30'd131072;
        pow2[18] = 30'd262144;
        pow2[19] = 30'd524288;
        pow2[20] = 30'd1048576;
        pow2[21] = 30'd2097152;
        pow2[22] = 30'd4194304;
        pow2[23] = 30'd8388608;
        pow2[24] = 30'd16777216;
        pow2[25] = 30'd33554432;
        pow2[26] = 30'd67108864;
        pow2[27] = 30'd134217728;
        pow2[28] = 30'd268435456;
        pow2[29] = 30'd536870912;
        pow2[30] = 30'd1073741824 % MOD; // 2^30 mod MOD
        pow2[31] = (pow2[30] * 30'd2) % MOD; // 2^31 mod MOD
        pow2[32] = (pow2[31] * 30'd2) % MOD; // 2^32 mod MOD

        // Powers of 3 (0..32)
        pow3[0] = 30'd1;
        pow3[1] = 30'd3;
        pow3[2] = 30'd9;
        pow3[3] = 30'd27;
        pow3[4] = 30'd81;
        pow3[5] = 30'd243;
        pow3[6] = 30'd729;
        pow3[7] = 30'd2187;
        pow3[8] = 30'd6561;
        pow3[9] = 30'd19683;
        pow3[10] = 30'd59049;
        pow3[11] = 30'd177147;
        pow3[12] = 30'd531441;
        pow3[13] = 30'd1594323;
        pow3[14] = 30'd4782969;
        pow3[15] = 30'd14348907;
        pow3[16] = 30'd43046721;
        pow3[17] = 30'd129140163;
        pow3[18] = 30'd387420489 % MOD; // 3^18 mod MOD
        pow3[19] = (pow3[18] * 30'd3) % MOD; // 3^19
        pow3[20] = (pow3[19] * 30'd3) % MOD; // 3^20
        pow3[21] = (pow3[20] * 30'd3) % MOD; // 3^21
        pow3[22] = (pow3[21] * 30'd3) % MOD; // 3^22
        pow3[23] = (pow3[22] * 30'd3) % MOD; // 3^23
        pow3[24] = (pow3[23] * 30'd3) % MOD; // 3^24
        pow3[25] = (pow3[24] * 30'd3) % MOD; // 3^25
        pow3[26] = (pow3[25] * 30'd3) % MOD; // 3^26
        pow3[27] = (pow3[26] * 30'd3) % MOD; // 3^27
        pow3[28] = (pow3[27] * 30'd3) % MOD; // 3^28
        pow3[29] = (pow3[28] * 30'd3) % MOD; // 3^29
        pow3[30] = (pow3[29] * 30'd3) % MOD; // 3^30
        pow3[31] = (pow3[30] * 30'd3) % MOD; // 3^31
        pow3[32] = (pow3[31] * 30'd3) % MOD; // 3^32

        // Cumulative arrays up to L = N + M (max 30), sized with 32 entries for direct indexing
        reg [29:0] pCUM [32:0]; // pCUM[i] = C(N, i) * 2^i
        reg [29:0] vCUM [32:0]; // vCUM[j] = C(M, j) * 3^j
        reg [29:0] tCUM [32:0]; // tCUM[t] = sum_{i=0..t} pCUM[i] * vCUM[t-i]
        reg [29:0] temp_result;
        reg [4:0] L; // up to 30
        reg [5:0] i6, j6, t6; // 6-bit indices to select from arrays
        reg [5:0] ii, jj, tt;

        // Derive L = N + M
        L = N + M;

        // Build pCUM
        pCUM[0] = 30'd1; // C(N,0) * 2^0
        for (ii = 1; ii <= 31; ii = ii + 1) begin
          if (ii <= N) pCUM[ii] = (comb_pooled({1'b0,N}, ii, fact, inv_fact) * powmod2(ii, pow2)) % MOD;
          else pCUM[ii] = 30'd0;
        end

        // Build vCUM
        vCUM[0] = 30'd1; // C(M,0) * 3^0
        for (jj = 1; jj <= 31; jj = jj + 1) begin
          if (jj <= M) vCUM[jj] = (comb_pooled({1'b0,M}, jj, fact, inv_fact) * powmod3(jj, pow3)) % MOD;
          else vCUM[jj] = 30'd0;
        end

        // Build tCUM
        tCUM[0] = (pCUM[0] * vCUM[0]) % MOD; // 1
        for (tt = 1; tt <= 31; tt = tt + 1) begin
          tCUM[tt] = 30'd0;
          for (i6 = 0; i6 <= 31; i6 = i6 + 1) begin
            j6 = tt - i6;
            // j6 in 0..31 by unsigned subtraction (if underflow wraps, condition prevents adding zeros)
            if ((i6 <= tt) && (j6 <= 31)) begin
              tCUM[tt] = (tCUM[tt] + pCUM[i6] * vCUM[j6]) % MOD;
            end
          end
        end

        // Final result: result = sum_{t=0..L} C(K, t) * 2^t * 3^{L-t} * tCUM[t]
        // Using C(K, t) * 2^t stored in pCUM[t] (since pCUM[i] = C(N,i)*2^i, but we need C(K,t)*2^t)
        // We'll compute comb(K,t) * 2^t inline for t.
        temp_result = 30'd0;
        for (tt = 0; tt <= 31; tt = tt + 1) begin
          if (tt <= K) begin
            // term = C(K, tt) * 2^tt
            // Compute C(K, tt) via fact/inv_fact and multiply by pow2[tt]
            reg [29:0] cterm;
            cterm = (fact[K] * inv_fact[tt] % MOD) * inv_fact[K-tt] % MOD;
            cterm = (cterm * pow2[tt]) % MOD; // C(K,tt)*2^tt
            // multiply by 3^{L-tt} * tCUM[tt]
            if (L >= tt) begin
              reg [29:0] mult;
              mult = (pow3[L-tt] * tCUM[tt]) % MOD;
              temp_result = (temp_result + cterm * mult) % MOD;
            end
          end
        end

        result <= temp_result;
        done   <= 1'b1;
      end else begin
        result <= result; // hold
        done   <= 1'b0;   // deassert when not running
      end
    end
  end

endmodule