module triplet_counter(
  input  [3:0] n,
  output [5:0] count
);

  integer i;
  reg [2:0] a_mod3 [1:8];
  reg [3:0] cnt0, cnt1, cnt2;
  reg [5:0] triplets;

  always @* begin
    // Initialize counts
    cnt0 = 4'd0;
    cnt1 = 4'd0;
    cnt2 = 4'd0;

    // Compute a[i] mod 3 for i=1..n and count residues
    for (i = 1; i <= 8; i = i + 1) begin
      if (i <= n) begin
        // a[i] = i*i - i + 1
        // Working in small width is safe for modulo-3
        // Compute i*i in sufficient width
        reg [7:0] ii;
        reg [7:0] ai;
        ii = i[7:0] * i[7:0];
        ai = ii - i[7:0] + 8'd1;
        a_mod3[i] = ai % 3;

        case (a_mod3[i])
          3'd0: cnt0 = cnt0 + 1'b1;
          3'd1: cnt1 = cnt1 + 1'b1;
          default: cnt2 = cnt2 + 1'b1; // must be 2 mod 3
        endcase
      end else begin
        a_mod3[i] = 3'd0;
      end
    end

    // If fewer than 3 elements, no triplets
    if (n < 3) begin
      triplets = 6'd0;
    end else begin
      // Count triplets with sum mod 3 == 0 using residue counts
      // Patterns:
      //  (0,0,0), (1,1,1), (2,2,2), (0,1,2)
      reg [5:0] c0, c1, c2, c012;

      // Combination counts C(m,3) = m*(m-1)*(m-2)/6
      if (cnt0 >= 3)
        c0 = (cnt0 * (cnt0 - 1) * (cnt0 - 2)) / 6;
      else
        c0 = 6'd0;

      if (cnt1 >= 3)
        c1 = (cnt1 * (cnt1 - 1) * (cnt1 - 2)) / 6;
      else
        c1 = 6'd0;

      if (cnt2 >= 3)
        c2 = (cnt2 * (cnt2 - 1) * (cnt2 - 2)) / 6;
      else
        c2 = 6'd0;

      // Triplets with one from each residue: cnt0 * cnt1 * cnt2
      c012 = cnt0 * cnt1 * cnt2;

      triplets = c0 + c1 + c2 + c012;
    end
  end

  assign count = triplets;

endmodule