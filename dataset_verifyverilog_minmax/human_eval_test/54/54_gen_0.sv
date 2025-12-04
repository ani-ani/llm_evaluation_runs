module same_chars(input reg [39:0] s0, input reg [39:0] s1, output logic result);
  logic [25:0] pres0, pres1;

  // Build presence vector for s0: bit[i] set if character 'a'+i (1..26) appears in s0
  generate
    for (genvar i = 0; i < 8; i++) begin : char0
      always_comb begin
        pres0 = 26'b0;
      end
    end
  endgenerate

  always_comb begin
    pres0 = 26'b0;
    for (int i = 0; i < 8; i++) begin
      if (s0[i*5 +: 5] inside {[1:26]}) begin
        pres0[s0[i*5 +: 5] - 1] = 1'b1;
      end
    end
  end

  // Build presence vector for s1
  always_comb begin
    pres1 = 26'b0;
    for (int i = 0; i < 8; i++) begin
      if (s1[i*5 +: 5] inside {[1:26]}) begin
        pres1[s1[i*5 +: 5] - 1] = 1'b1;
      end
    end
  end

  // Output is 1 if both presence vectors are identical
  assign result = (pres0 == pres1);
endmodule