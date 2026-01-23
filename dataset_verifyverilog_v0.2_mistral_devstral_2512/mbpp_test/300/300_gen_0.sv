module binary_seq_counter (
  input [3:0] n,
  input start,
  output reg [31:0] result
);

  always_comb begin
    if (start) begin
      integer r;
      reg [31:0] nCr = 1;
      reg [31:0] temp;
      
      result = 32'h00010000; // 1.0 in Q16.16
      
      for (r = 1; r <= n; r = r + 1) begin
        temp = nCr * (n + 1 - r);
        nCr = temp / r; // integer division
        result = result + (nCr * nCr) << 16;
      end
    end else begin
      result = 32'h00000000;
    end
  end

endmodule