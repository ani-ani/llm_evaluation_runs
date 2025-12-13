module special_number_counter(
  input clk,
  input rst_n,
  input start,
  input [15:0] n_bin,
  input [3:0] k,
  output reg [31:0] count,
  output reg done
);

  // ---------------------------------------------
  // Parameters
  // ---------------------------------------------
  localparam MOD = 32'd1000000007;

  // ---------------------------------------------
  // Population count for 16-bit input
  // ---------------------------------------------
  function automatic [4:0] popcount16(input [15:0] x);
    integer i;
    reg [4:0] c;
    begin
      c = 5'd0;
      for (i = 0; i < 16; i = i + 1) begin
        c = c + x[i];
      end
      popcount16 = c;
    end
  endfunction

  // ---------------------------------------------
  // Precomputed min_operations for popcount 0..16
  // Interpretation of "special" reduction operations:
  // For this implementation we assume the minimum operations
  // depends only on the population count of the number.
  // ops(p) table can be tuned as needed; here is a simple
  // example mapping that is purely combinational:
  //   ops(0)  = 0
  //   ops(1)  = 0
  //   ops(2)  = 1
  //   ops(3)  = 2
  //   ops(4)  = 2
  //   ops(5)  = 3
  //   ops(6)  = 3
  //   ops(7)  = 3
  //   ops(8)  = 4
  //   ops(9)  = 4
  //   ops(10) = 4
  //   ops(11) = 4
  //   ops(12) = 4
  //   ops(13) = 4
  //   ops(14) = 4
  //   ops(15) = 4
  //   ops(16) = 4
  function automatic [3:0] min_ops_from_popcount(input [4:0] pc);
    begin
      case (pc)
        5'd0:  min_ops_from_popcount = 4'd0;
        5'd1:  min_ops_from_popcount = 4'd0;
        5'd2:  min_ops_from_popcount = 4'd1;
        5'd3:  min_ops_from_popcount = 4'd2;
        5'd4:  min_ops_from_popcount = 4'd2;
        5'd5:  min_ops_from_popcount = 4'd3;
        5'd6:  min_ops_from_popcount = 4'd3;
        5'd7:  min_ops_from_popcount = 4'd3;
        5'd8:  min_ops_from_popcount = 4'd4;
        5'd9:  min_ops_from_popcount = 4'd4;
        5'd10: min_ops_from_popcount = 4'd4;
        5'd11: min_ops_from_popcount = 4'd4;
        5'd12: min_ops_from_popcount = 4'd4;
        5'd13: min_ops_from_popcount = 4'd4;
        5'd14: min_ops_from_popcount = 4'd4;
        5'd15: min_ops_from_popcount = 4'd4;
        5'd16: min_ops_from_popcount = 4'd4;
        default: min_ops_from_popcount = 4'd0;
      endcase
    end
  endfunction

  // ---------------------------------------------
  // Binomial Coefficient Lookup C(16, r)
  // ---------------------------------------------
  function automatic [31:0] comb16(input [4:0] r);
    begin
      case (r)
        5'd0:  comb16 = 32'd1;
        5'd1:  comb16 = 32'd16;
        5'd2:  comb16 = 32'd120;
        5'd3:  comb16 = 32'd560;
        5'd4:  comb16 = 32'd1820;
        5'd5:  comb16 = 32'd4368;
        5'd6:  comb16 = 32'd8008;
        5'd7:  comb16 = 32'd11440;
        5'd8:  comb16 = 32'd12870;
        5'd9:  comb16 = 32'd11440;
        5'd10: comb16 = 32'd8008;
        5'd11: comb16 = 32'd4368;
        5'd12: comb16 = 32'd1820;
        5'd13: comb16 = 32'd560;
        5'd14: comb16 = 32'd120;
        5'd15: comb16 = 32'd16;
        5'd16: comb16 = 32'd1;
        default: comb16 = 32'd0;
      endcase
    end
  endfunction

  // ---------------------------------------------
  // General combinational function to compute the count of
  // numbers <= n requiring exactly k operations.
  // Utilizes popcount, min_ops_from_popcount, and binomial sums.
  // ---------------------------------------------
  function automatic [31:0] calc_special_count(
    input [15:0] n,
    input [3:0]  k_in
  );
    integer i;
    reg [4:0] ones_so_far;
    reg [31:0] res;
    reg [4:0] r;
    reg [3:0] ops_val;
    begin
      res = 32'd0;
      ones_so_far = 5'd0;

      // Count numbers with smaller bit-length (leading bit < highest 1 of n)
      // For each possible popcount r, if min_ops(r)==k, add C(16, r) for
      // all 16-bit numbers with that count but MSB zero; to keep aligned
      // with the constraint (<= 65535), we simply account within traversal.
      // More precisely, we iterate bits from MSB to LSB and accumulate
      // combinations whenever we see a '1' in n.

      for (i = 15; i >= 0; i = i - 1) begin
        if (n[i]) begin
          // For this bit being 0 while n has 1, we can freely choose
          // remaining bits below i.
          for (r = 0; r <= (15 - i); r = r + 1) begin
            // total ones = ones_so_far + r
            ops_val = min_ops_from_popcount(ones_so_far + r);
            if (ops_val == k_in) begin
              // choose r ones in remaining (i) bits below current index
              // Note: number of remaining lower bits = i
              // We need a generic C(i, r); here we derive via comb16
              // by mapping smaller n using identity C(i,r) from pre-known.
              // Implemented via simple multiplicative formula.
              res = (res + comb_var(i[4:0], r)) % MOD;
            end
          end
          ones_so_far = ones_so_far + 1'b1;
        end
      end

      // Now include n itself if it matches
      ops_val = min_ops_from_popcount(popcount16(n));
      if (ops_val == k_in)
        res = (res + 32'd1) % MOD;

      calc_special_count = res;
    end
  endfunction

  // ---------------------------------------------
  // Generic small C(n,r) using multiplicative formula
  // n up to 16, r up to 16; purely combinational
  // ---------------------------------------------
  function automatic [31:0] comb_var(
    input [4:0] n,
    input [4:0] r
  );
    integer i;
    reg [31:0] num;
    reg [31:0] den;
    reg [31:0] g;
    reg [4:0] rr;

    function automatic [31:0] gcd32(input [31:0] a, input [31:0] b);
      reg [31:0] x, y, t;
      begin
        x = a;
        y = b;
        while (y != 0) begin
          t = x % y;
          x = y;
          y = t;
        end
        gcd32 = x;
      end
    endfunction

    begin
      if (r > n) begin
        comb_var = 32'd0;
      end else if (r == 0 || r == n) begin
        comb_var = 32'd1;
      end else begin
        rr = (r > (n - r)) ? (n - r) : r;
        num = 32'd1;
        den = 32'd1;
        for (i = 0; i < rr; i = i + 1) begin
          num = num * (n - i);
          den = den * (i + 1);
          g = gcd32(num, den);
          if (g != 0) begin
            num = num / g;
            den = den / g;
          end
        end
        comb_var = num; // den should be 1
      end
    end
  endfunction

  // ---------------------------------------------
  // 20-cycle latency control
  // ---------------------------------------------
  reg [4:0] latency_cnt;
  reg [31:0] result_reg;
  reg busy;
  reg [15:0] n_latched;
  reg [3:0]  k_latched;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      count        <= 32'd0;
      done         <= 1'b0;
      latency_cnt  <= 5'd0;
      busy         <= 1'b0;
      result_reg   <= 32'd0;
      n_latched    <= 16'd0;
      k_latched    <= 4'd0;
    end else begin
      done <= 1'b0;

      if (start && !busy) begin
        // Latch inputs at start
        n_latched   <= n_bin;
        k_latched   <= k;
        latency_cnt <= 5'd0;
        busy        <= 1'b1;
      end else if (busy) begin
        latency_cnt <= latency_cnt + 5'd1;

        // On cycle 1 after start, compute combinational result and store
        if (latency_cnt == 5'd0) begin
          result_reg <= calc_special_count(n_latched, k_latched) % MOD;
        end

        // Assert done and output result at 20th cycle
        if (latency_cnt == 5'd19) begin
          count <= result_reg;
          done  <= 1'b1;
          busy  <= 1'b0;
        end
      end
    end
  end

endmodule