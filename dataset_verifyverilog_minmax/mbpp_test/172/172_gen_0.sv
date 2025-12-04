module count_std (
  // Count occurrences of the ASCII word std in the 16-byte input str
  input reg [127:0] str,
  output reg [2:0] count
);
  logic [3:0] cnt;
  integer i;
  always_comb begin
    cnt = 4'b0;
    for (i = 0; i < 14; i = i + 1) begin
      if (str[(127 - 8*i) -: 8] == 8'd115 &&
          str[(119 - 8*i) -: 8] == 8'd116 &&
          str[(111 - 8*i) -: 8] == 8'd100) begin
        cnt = cnt + 1;
      end
    end
    count = cnt[2:0];
  end
endmodule