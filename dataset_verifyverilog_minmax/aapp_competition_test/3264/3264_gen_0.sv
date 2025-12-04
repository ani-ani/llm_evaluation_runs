module coprime_set_counter(
  input [3:0] N, // Input N (max 15)
  output [29:0] count // Result modulo 1000000000
);

  // Combinational-only module. Computes:
  // count = product_{x=2}^{N} (2^{E(x)} - 1) mod 1e9
  // where E(x) is the number of coprime pairs (i,j) with 1 < i < j <= N,
  // and both i and j are either in [2, x-1] or in [x, N].
  // This equals the number of subsets of valid coprime pairs that cannot be
  // partitioned by any x in {2,..,N}, modulo 1_000_000_000.

  localparam MOD = 30'd1_000_000_000;

  function [29:0] mod_pow2(input [6:0] e);
    integer i;
    reg [29:0] res;
  begin
    res = 30'd1;
    for (i = 0; i < e; i = i + 1) begin
      res = {1'b0, res[29:1]} + {1'b0, res[29:1]}; // res = (res << 1) without overflow beyond 30 bits
    end
    mod_pow2 = res;
  end
  endfunction

  // Coprime edge counts per possible N (for pairs with 1 < i < j <= N)
  // These are precomputed constants to keep the module purely combinational.
  localparam [6:0] CP0 = 7'd0;  // N=0 (unused)
  localparam [6:0] CP1 = 7'd0;  // N=1 (unused)
  localparam [6:0] CP2 = 7'd0;  // N=2
  localparam [6:0] CP3 = 7'd1;  // N=3
  localparam [6:0] CP4 = 7'd3;  // N=4
  localparam [6:0] CP5 = 7'd6;  // N=5
  localparam [6:0] CP6 = 7'd9;  // N=6
  localparam [6:0] CP7 = 7'd13; // N=7
  localparam [6:0] CP8 = 7'd18; // N=8
  localparam [6:0] CP9 = 7'd24; // N=9
  localparam [6:0] CP10 = 7'd30; // N=10
  localparam [6:0] CP11 = 7'd37; // N=11
  localparam [6:0] CP12 = 7'd45; // N=12
  localparam [6:0] CP13 = 7'd53; // N=13
  localparam [6:0] CP14 = 7'd61; // N=14
  localparam [6:0] CP15 = 7'd73; // N=15

  reg [29:0] temp_count;

  always_comb begin
    temp_count = 30'd0;
    if (N < 4'd2) begin
      temp_count = 30'd0; // No valid pairs for N < 2
    end else begin
      temp_count = 30'd1; // Start with multiplicative identity
      case (N)
        4'd2:  temp_count = ((mod_pow2(CP2)  - 30'd1) % MOD);
        4'd3:  temp_count = ((mod_pow2(CP2)  - 30'd1) % MOD) * ((mod_pow2(CP3)  - 30'd1) % MOD);
        4'd4:  temp_count = ((mod_pow2(CP2)  - 30'd1) % MOD) * ((mod_pow2(CP3)  - 30'd1) % MOD) * ((mod_pow2(CP4)  - 30'd1) % MOD);
        4'd5:  temp_count = ((mod_pow2(CP2)  - 30'd1) % MOD) * ((mod_pow2(CP3)  - 30'd1) % MOD) * ((mod_pow2(CP4)  - 30'd1) % MOD) * ((mod_pow2(CP5)  - 30'd1) % MOD);
        4'd6:  temp_count = ((mod_pow2(CP2)  - 30'd1) % MOD) * ((mod_pow2(CP3)  - 30'd1) % MOD) * ((mod_pow2(CP4)  - 30'd1) % MOD) * ((mod_pow2(CP5)  - 30'd1) % MOD) * ((mod_pow2(CP6)  - 30'd1) % MOD);
        4'd7:  temp_count = ((mod_pow2(CP2)  - 30'd1) % MOD) * ((mod_pow2(CP3)  - 30'd1) % MOD) * ((mod_pow2(CP4)  - 30'd1) % MOD) * ((mod_pow2(CP5)  - 30'd1) % MOD) * ((mod_pow2(CP6)  - 30'd1) % MOD) * ((mod_pow2(CP7)  - 30'd1) % MOD);
        4'd8:  temp_count = ((mod_pow2(CP2)  - 30'd1) % MOD) * ((mod_pow2(CP3)  - 30'd1) % MOD) * ((mod_pow2(CP4)  - 30'd1) % MOD) * ((mod_pow2(CP5)  - 30'd1) % MOD) * ((mod_pow2(CP6)  - 30'd1) % MOD) * ((mod_pow2(CP7)  - 30'd1) % MOD) * ((mod_pow2(CP8)  - 30'd1) % MOD);
        4'd9:  temp_count = ((mod_pow2(CP2)  - 30'd1) % MOD) * ((mod_pow2(CP3)  - 30'd1) % MOD) * ((mod_pow2(CP4)  - 30'd1) % MOD) * ((mod_pow2(CP5)  - 30'd1) % MOD) * ((mod_pow2(CP6)  - 30'd1) % MOD) * ((mod_pow2(CP7)  - 30'd1) % MOD) * ((mod_pow2(CP8)  - 30'd1) % MOD) * ((mod_pow2(CP9)  - 30'd1) % MOD);
        4'd10: temp_count = ((mod_pow2(CP2)  - 30'd1) % MOD) * ((mod_pow2(CP3)  - 30'd1) % MOD) * ((mod_pow2(CP4)  - 30'd1) % MOD) * ((mod_pow2(CP5)  - 30'd1) % MOD) * ((mod_pow2(CP6)  - 30'd1) % MOD) * ((mod_pow2(CP7)  - 30'd1) % MOD) * ((mod_pow2(CP8)  - 30'd1) % MOD) * ((mod_pow2(CP9)  - 30'd1) % MOD) * ((mod_pow2(CP10) - 30'd1) % MOD);
        4'd11: temp_count = ((mod_pow2(CP2)  - 30'd1) % MOD) * ((mod_pow2(CP3)  - 30'd1) % MOD) * ((mod_pow2(CP4)  - 30'd1) % MOD) * ((mod_pow2(CP5)  - 30'd1) % MOD) * ((mod_pow2(CP6)  - 30'd1) % MOD) * ((mod_pow2(CP7)  - 30'd1) % MOD) * ((mod_pow2(CP8)  - 30'd1) % MOD) * ((mod_pow2(CP9)  - 30'd1) % MOD) * ((mod_pow2(CP10) - 30'd1) % MOD) * ((mod_pow2(CP11) - 30'd1) % MOD);
        4'd12: temp_count = ((mod_pow2(CP2)  - 30'd1) % MOD) * ((mod_pow2(CP3)  - 30'd1) % MOD) * ((mod_pow2(CP4)  - 30'd1) % MOD) * ((mod_pow2(CP5)  - 30'd1) % MOD) * ((mod_pow2(CP6)  - 30'd1) % MOD) * ((mod_pow2(CP7)  - 30'd1) % MOD) * ((mod_pow2(CP8)  - 30'd1) % MOD) * ((mod_pow2(CP9)  - 30'd1) % MOD) * ((mod_pow2(CP10) - 30'd1) % MOD) * ((mod_pow2(CP11) - 30'd1) % MOD) * ((mod_pow2(CP12) - 30'd1) % MOD);
        4'd13: temp_count = ((mod_pow2(CP2)  - 30'd1) % MOD) * ((mod_pow2(CP3)  - 30'd1) % MOD) * ((mod_pow2(CP4)  - 30'd1) % MOD) * ((mod_pow2(CP5)  - 30'd1) % MOD) * ((mod_pow2(CP6)  - 30'd1) % MOD) * ((mod_pow2(CP7)  - 30'd1) % MOD) * ((mod_pow2(CP8)  - 30'd1) % MOD) * ((mod_pow2(CP9)  - 30'd1) % MOD) * ((mod_pow2(CP10) - 30'd1) % MOD) * ((mod_pow2(CP11) - 30'd1) % MOD) * ((mod_pow2(CP12) - 30'd1) % MOD) * ((mod_pow2(CP13) - 30'd1) % MOD);
        4'd14: temp_count = ((mod_pow2(CP2)  - 30'd1) % MOD) * ((mod_pow2(CP3)  - 30'd1) % MOD) * ((mod_pow2(CP4)  - 30'd1) % MOD) * ((mod_pow2(CP5)  - 30'd1) % MOD) * ((mod_pow2(CP6)  - 30'd1) % MOD) * ((mod_pow2(CP7)  - 30'd1) % MOD) * ((mod_pow2(CP8)  - 30'd1) % MOD) * ((mod_pow2(CP9)  - 30'd1) % MOD) * ((mod_pow2(CP10) - 30'd1) % MOD) * ((mod_pow2(CP11) - 30'd1) % MOD) * ((mod_pow2(CP12) - 30'd1) % MOD) * ((mod_pow2(CP13) - 30'd1) % MOD) * ((mod_pow2(CP14) - 30'd1) % MOD);
        4'd15: temp_count = ((mod_pow2(CP2)  - 30'd1) % MOD) * ((mod_pow2(CP3)  - 30'd1) % MOD) * ((mod_pow2(CP4)  - 30'd1) % MOD) * ((mod_pow2(CP5)  - 30'd1) % MOD) * ((mod_pow2(CP6)  - 30'd1) % MOD) * ((mod_pow2(CP7)  - 30'd1) % MOD) * ((mod_pow2(CP8)  - 30'd1) % MOD) * ((mod_pow2(CP9)  - 30'd1) % MOD) * ((mod_pow2(CP10) - 30'd1) % MOD) * ((mod_pow2(CP11) - 30'd1) % MOD) * ((mod_pow2(CP12) - 30'd1) % MOD) * ((mod_pow2(CP13) - 30'd1) % MOD) * ((mod_pow2(CP14) - 30'd1) % MOD) * ((mod_pow2(CP15) - 30'd1) % MOD);
        default: temp_count = 30'd0;
      endcase
    end
    count = temp_count % MOD;
  end

endmodule
