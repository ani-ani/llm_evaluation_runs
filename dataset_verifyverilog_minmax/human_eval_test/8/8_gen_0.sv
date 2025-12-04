module sum_product (
  input [3:0] len,
  input [63:0] numbers,
  output [15:0] sum,
  output [63:0] product
);

  // Unpacked array view of the packed 'numbers' input (8x8-bit elements)
  logic [7:0] elem [0:7];
  always_comb begin
    elem[0] = numbers[63:56];
    elem[1] = numbers[55:48];
    elem[2] = numbers[47:40];
    elem[3] = numbers[39:32];
    elem[4] = numbers[31:24];
    elem[5] = numbers[23:16];
    elem[6] = numbers[15:8];
    elem[7] = numbers[7:0];
  end

  // Sum: accumulate first 'len' elements (unsigned 8-bit, result fits in 16 bits)
  logic [15:0] sum_comb;
  always_comb begin
    sum_comb = 16'h0000;
    for (int i = 0; i < 8; i++) begin
      if (i < len) sum_comb = sum_comb + elem[i];
    end
  end
  assign sum = sum_comb;

  // Combinational multiplier (Booth-less shift-add) to avoid '*' operator
  function [63:0] mul64;
    input [63:0] a;
    input [63:0] b;
    logic [127:0] result;
    logic [127:0] b_ext;
    integer k;
    begin
      result = 128'h0;
      b_ext = {64'h0, b};
      for (k = 0; k < 64; k++) begin
        if (a[k]) result = result + b_ext;
        b_ext = b_ext << 1;
      end
      mul64 = result[63:0]; // Truncate to 64 bits as per output type
    end
  endfunction

  // Product: multiply first 'len' elements; for len==0 product==1 (multiplicative identity)
  logic [63:0] product_comb;
  always_comb begin
    if (len == 4'd0) begin
      product_comb = 64'h1;
    end else begin
      product_comb = 64'h1;
      for (int i = 0; i < 8; i++) begin
        if (i < len) product_comb = mul64(product_comb, {56'h0, elem[i]});
      end
    end
  end
  assign product = product_comb;

endmodule
