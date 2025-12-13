module same_chars(
  input  [39:0] s0,
  input  [39:0] s1,
  output        same
);

  // Split into 8 characters (5 bits each)
  wire [4:0] s0_c[7:0];
  wire [4:0] s1_c[7:0];

  assign {s0_c[7], s0_c[6], s0_c[5], s0_c[4], s0_c[3], s0_c[2], s0_c[1], s0_c[0]} = s0;
  assign {s1_c[7], s1_c[6], s1_c[5], s1_c[4], s1_c[3], s1_c[2], s1_c[1], s1_c[0]} = s1;

  // Presence vectors for 'a'(1) to 'z'(26)
  reg [25:0] pres0;
  reg [25:0] pres1;

  integer i;

  always @* begin
    pres0 = 26'b0;
    pres1 = 26'b0;

    // s0 presence
    for (i = 0; i < 8; i = i + 1) begin
      if (s0_c[i] >= 5'd1 && s0_c[i] <= 5'd26)
        pres0[s0_c[i] - 5'd1] = 1'b1;
    end

    // s1 presence
    for (i = 0; i < 8; i = i + 1) begin
      if (s1_c[i] >= 5'd1 && s1_c[i] <= 5'd26)
        pres1[s1_c[i] - 5'd1] = 1'b1;
    end
  end

  assign same = (pres0 == pres1);

endmodule