module same_chars(input [39:0] s0, s1, output result);
  logic [25:0] presence0, presence1;
  
  always_comb begin
    presence0 = 26'b0;
    for (int i=0; i<8; i=i+1) begin
      logic [4:0] char = s0[i*5 +:5];
      if (char >= 5'd1 && char <= 5'd26) begin
        presence0[char-1] = 1'b1;
      end
    end
  end

  always_comb begin
    presence1 = 26'b0;
    for (int i=0; i<8; i=i+1) begin
      logic [4:0] char = s1[i*5 +:5];
      if (char >= 5'd1 && char <= 5'd26) begin
        presence1[char-1] = 1'b1;
      end
    end
  end

  assign result = (presence0 == presence1);
endmodule