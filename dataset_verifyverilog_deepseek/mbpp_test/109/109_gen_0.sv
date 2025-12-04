module odd_equivalent(input reg [7:0] s, input reg [2:0] n, output reg [3:0] count);
  always_comb begin
    count = 0;
    for (int i = 0; i < 7; i++) begin
      if (i < n) begin
        count += s[i];
      end
    end
  end
endmodule