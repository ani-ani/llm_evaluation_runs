module rolling_max (
  input  [2:0]  size,
  input  [63:0] numbers,
  output [63:0] result
);

  wire [7:0] base;
  assign base = numbers[7:0];

  // Extract elements
  wire [7:0] e0 = numbers[7:0];
  wire [7:0] e1 = numbers[15:8];
  wire [7:0] e2 = numbers[23:16];
  wire [7:0] e3 = numbers[31:24];
  wire [7:0] e4 = numbers[39:32];
  wire [7:0] e5 = numbers[47:40];
  wire [7:0] e6 = numbers[55:48];
  wire [7:0] e7 = numbers[63:56];

  // Rolling max with base (e0)
  wire [7:0] r0 = (size > 3'd0) ? ((e0 > base) ? e0 : base) : 8'h00; // don't care when size==0
  wire [7:0] r1 = (size > 3'd1) ? ((e1 > base) ? e1 : base) : 8'h00;
  wire [7:0] r2 = (size > 3'd2) ? ((e2 > base) ? e2 : base) : 8'h00;
  wire [7:0] r3 = (size > 3'd3) ? ((e3 > base) ? e3 : base) : 8'h00;
  wire [7:0] r4 = (size > 3'd4) ? ((e4 > base) ? e4 : base) : 8'h00;
  wire [7:0] r5 = (size > 3'd5) ? ((e5 > base) ? e5 : base) : 8'h00;
  wire [7:0] r6 = (size > 3'd6) ? ((e6 > base) ? e6 : base) : 8'h00;
  wire [7:0] r7 = (size > 3'd7) ? ((e7 > base) ? e7 : base) : 8'h00;

  assign result = {r7, r6, r5, r4, r3, r2, r1, r0};

endmodule