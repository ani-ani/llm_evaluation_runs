module count_std (
  input [127:0] str,
  output logic [2:0] count
);

  always_comb begin
    count = 0;
    for (int i = 0; i < 14; i++) begin
      logic [7:0] char0, char1, char2;
      char0 = str[127 - 8*i -: 8];
      char1 = str[119 - 8*i -: 8];
      char2 = str[111 - 8*i -: 8];
      if ((char0 == 8'd115) && (char1 == 8'd116) && (char2 == 8'd100)) begin
        count += 1'b1;
      end
    end
  end

endmodule