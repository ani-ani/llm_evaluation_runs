module alternating_sum_mod(
  input clk,           // System clock
  input rst_n,         // Active-low reset
  input start,         // Start computation (pulse high)
  input [14:0] n,      // Max value 32767 (15-bit)
  input [15:0] a,      // Base a (16-bit)
  input [15:0] b,      // Base b (16-bit)
  input [3:0] k,       // Period (1-16, 4-bit)
  input [15:0] s,      // Sign bits (s[0] to s[k-1]: 1='+', 0='-') (16-bit)
  output reg [9:0] result,  // Result mod 997 (10-bit)
  output reg done      // High when computation completes
);
  localparam MOD = 997;
  localparam LOG_MOD = $clog2(MOD);
  localparam W = 10; // width to hold MOD-1

  // State machine
  localparam ST_IDLE    = 3'b000;
  localparam ST_PREP    = 3'b001;
  localparam ST_RUN     = 3'b010;
  localparam ST_FINAL_E = 3'b011;
  localparam ST_FINAL_O = 3'b100;
  localparam ST_DONE    = 3'b101;

  reg [2:0] state, state_next;
  reg [15:0] i;        // iteration index
  reg [15:0] a_pow;    // a^i mod MOD
  reg [15:0] b_pow;    // b^i mod MOD
  reg [15:0] a_n_minus;// a^(n-i) mod MOD
  reg [9:0] sum_even;  // even-index accumulator
  reg [9:0] sum_odd;   // odd-index accumulator
  reg [3:0] k_r;       // registered k (1-16)
  reg [15:0] n_r;      // registered n
  reg [9:0] a_n_mod;   // a^n mod MOD

  // --- Mod-997 helpers (combinational) ---
  function [9:0] addmod;
    input [9:0] x, y;
    reg [9:0] t;
    begin
      t = x + y;
      if (t >= MOD) t = t - MOD;
      addmod = t;
    end
  endfunction

  function [9:0] mulmod;
    input [9:0] x, y;
    reg [9:0] xq, yq;
    reg [16:0] prod;
    begin
      xq = x % MOD;
      yq = y % MOD;
      prod = xq * yq;
      mulmod = prod % MOD;
    end
  endfunction

  function [9:0] sqmod;
    input [9:0] x;
    reg [15:0] prod;
    begin
      prod = x * x;
      sqmod = prod % MOD;
    end
  endfunction

  function [9:0] pat;
    input [15:0] idx;
    input [3:0] K;
    input [15:0] S;
    reg [3:0] pos;
    begin
      if (K == 4'd0) pos = 4'd0;
      else pos = idx % K;
      pat = S[pos];
    end
  endfunction

  // --- Sequential logic (clocked) ---
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      state   <= ST_IDLE;
      done    <= 1'b0;
      result  <= 10'd0;
      i       <= 16'd0;
      a_pow   <= 10'd0;
      b_pow   <= 10'd0;
      a_n_minus <= 10'd0;
      sum_even <= 10'd0;
      sum_odd  <= 10'd0;
      k_r      <= 4'd0;
      n_r      <= 16'd0;
      a_n_mod  <= 10'd0;
    end else begin
      state <= state_next;
      // Default: maintain; changes below where needed
      done    <= 1'b0;
      i       <= i;
      a_pow   <= a_pow;
      b_pow   <= b_pow;
      a_n_minus <= a_n_minus;
      sum_even <= sum_even;
      sum_odd  <= sum_odd;
      k_r      <= k_r;
      n_r      <= n_r;
      a_n_mod  <= a_n_mod;
      result   <= result;

      case (state_next)
        ST_IDLE: begin
          done <= 1'b0;
        end
        ST_PREP: begin
          // Initialize for a chunk of k terms starting at current i
          k_r    <= (k == 4'd0) ? 4'd1 : k; // avoid div-by-zero internally
          n_r    <= n;
          a_pow  <= 10'd1;            // a^0
          b_pow  <= 10'd1;            // b^0
          a_n_mod <= sqmod(a_powmod_sq); // a^n via repeated squaring (see below)
          a_n_minus <= a_n_mod;        // a^(n-i) with current i
          sum_even <= 10'd0;
          sum_odd  <= 10'd0;
          // a_powmod_sq is defined combinatorially below and stable within this cycle
        end
        ST_RUN: begin
          // i is the starting index of a k-sized block
          if (i + k_r >= n_r) begin
            // Last partial block: stop at n_r+1
            // Process j in [0, n-i]
            for (int j = 0; j < 16; j = j + 1) begin
              if (j < (n_r - i + 1)) begin
                // term index = i + j
                if ((i + j)[0] == 1'b0) begin
                  // even index
                  sum_even <= addmod(sum_even, mulmod(a_n_minus, b_pow));
                end else begin
                  // odd index
                  if (pat(i + j, k_r, s) == 1'b1) begin
                    sum_odd <= addmod(sum_odd, mulmod(a_n_minus, b_pow));
                  end else begin
                    sum_odd <= (sum_odd >= mulmod(a_n_minus, b_pow)) ? (sum_odd - mulmod(a_n_minus, b_pow)) : (sum_odd + MOD - mulmod(a_n_minus, b_pow));
                  end
                end
                // advance b^(i+j) to b^(i+j+1)
                b_pow <= mulmod(b_pow, b[9:0] % MOD);
                // move a^(n-(i+j)) to a^(n-(i+j+1)) -> divide by a
                a_n_minus <= divmod(a_n_minus, a[9:0] % MOD);
              end
            end
            // Move to finalize (even index at block end)
            state <= ST_FINAL_E;
          end else begin
            // Full block of k terms
            for (int j = 0; j < 16; j = j + 1) begin
              if (j < k_r) begin
                if ((i + j)[0] == 1'b0) begin
                  sum_even <= addmod(sum_even, mulmod(a_n_minus, b_pow));
                end else begin
                  if (pat(i + j, k_r, s) == 1'b1) begin
                    sum_odd <= addmod(sum_odd, mulmod(a_n_minus, b_pow));
                  end else begin
                    sum_odd <= (sum_odd >= mulmod(a_n_minus, b_pow)) ? (sum_odd - mulmod(a_n_minus, b_pow)) : (sum_odd + MOD - mulmod(a_n_minus, b_pow));
                  end
                end
                b_pow <= mulmod(b_pow, b[9:0] % MOD);
                a_n_minus <= divmod(a_n_minus, a[9:0] % MOD);
              end
            end
            i <= i + k_r;
          end
        end
        ST_FINAL_E: begin
          // handle i (even), if any left
          if (i <= n_r) begin
            if (pat(i, k_r, s) == 1'b1) begin
              sum_even <= addmod(sum_even, mulmod(a_n_minus, b_pow));
            end else begin
              sum_even <= (sum_even >= mulmod(a_n_minus, b_pow)) ? (sum_even - mulmod(a_n_minus, b_pow)) : (sum_even + MOD - mulmod(a_n_minus, b_pow));
            end
            b_pow <= mulmod(b_pow, b[9:0] % MOD);
            a_n_minus <= divmod(a_n_minus, a[9:0] % MOD);
            i <= i + 1;
          end
          state <= ST_FINAL_O;
        end
        ST_FINAL_O: begin
          // handle i+1 (odd), if any left
          if (i <= n_r) begin
            if (pat(i, k_r, s) == 1'b1) begin
              sum_odd <= addmod(sum_odd, mulmod(a_n_minus, b_pow));
            end else begin
              sum_odd <= (sum_odd >= mulmod(a_n_minus, b_pow)) ? (sum_odd - mulmod(a_n_minus, b_pow)) : (sum_odd + MOD - mulmod(a_n_minus, b_pow));
            end
            b_pow <= mulmod(b_pow, b[9:0] % MOD);
            a_n_minus <= divmod(a_n_minus, a[9:0] % MOD);
            i <= i + 1;
          end
          state <= ST_DONE;
        end
        ST_DONE: begin
          result <= addmod(sum_even, sum_odd);
          done   <= 1'b1;
        end
      endcase
    end
  end

  // --- Divider mod 997 (combinational, iterative) ---
  // Computes x / d mod 997 via extended Eucldiean algorithm. Works if gcd(d,997)=1 (i.e., d%997 != 0).
  function [9:0] divmod;
    input [9:0] x; // dividend mod 997
    input [9:0] d; // divisor mod 997, non-zero
    reg [9:0] inv;
  begin
    inv = invmod_997(d);
    divmod = mulmod(x, inv);
  end
  endfunction

  function [9:0] invmod_997;
    input [9:0] a; // a in [1,996]
    reg signed [16:0] t, newt;
    reg signed [16:0] r, newr;
    reg signed [16:0] q;
  begin
    t = 17'd0;
    newt = 17'd1;
    r = 17'd997;
    newr = a;
    while (newr != 17'd0) begin
      q = r / newr;
      {t, newt} = {newt, t - q * newt};
      {r, newr} = {newr, r - q * newr};
    end
    if (r > 17'd1) begin
      invmod_997 = 10'd0; // not invertible
    end else begin
      if (t < 0) t = t + 997;
      invmod_997 = t[9:0];
    end
  end
  endfunction

  // --- a_powmod_sq: compute a^n mod 997 via repeated squaring (combinational) ---
  // Used only in ST_PREP to bootstrap a_n_mod.
  wire [9:0] a_powmod_sq;
  assign a_powmod_sq = powmod_997(a, n);
  function [9:0] powmod_997;
    input [15:0] base_full;
    input [14:0] exp;
    reg [9:0] base;
    reg [9:0] result;
    reg [9:0] squarer;
    reg [14:0] e;
  begin
    base = base_full % MOD;
    result = 10'd1;
    e = exp;
    while (e > 0) begin
      if (e[0]) begin
        result = (result * base) % MOD;
      end
      e = e >> 1;
      if (e > 0) begin // avoid extra multiply when done
        squarer = (base * base) % MOD;
        base = squarer;
      end
    end
    powmod_997 = result;
  end
  endfunction

  // --- Next-state logic (combinational) ---
  always @(*) begin
    state_next = state;
    case (state)
      ST_IDLE:  state_next = start ? ST_PREP : ST_IDLE;
      ST_PREP:  state_next = ST_RUN;
      ST_RUN: begin
        if (i + k_r >= n_r) state_next = ST_FINAL_E;
        else state_next = ST_RUN;
      end
      ST_FINAL_E: state_next = ST_FINAL_O;
      ST_FINAL_O: state_next = ST_DONE;
      ST_DONE:  state_next = start ? ST_PREP : ST_IDLE;
      default:  state_next = ST_IDLE;
    endcase
  end
endmodule
