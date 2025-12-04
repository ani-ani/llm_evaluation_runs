module min_product_tuple(
  input reg [15:0] tuple0,
  input reg [15:0] tuple1,
  input reg [15:0] tuple2,
  input reg [15:0] tuple3,
  output reg [15:0] min_product
);

  function [15:0] abs16;
    input reg [15:0] x;
  begin
    abs16 = (x[15] ? (~x + 1) : x);
  end
  endfunction

  function [15:0] min;
    input reg [15:0] a;
    input reg [15:0] b;
  begin
    min = (a < b) ? a : b;
  end
  endfunction

  reg signed [7:0] x0, y0, x1, y1, x2, y2, x3, y3;
  reg signed [15:0] p0, p1, p2, p3;
  reg [15:0] a0, a1, a2, a3, m01, m23;

  always @(*) begin
    x0 = tuple0[15:8];
    y0 = tuple0[7:0];
    x1 = tuple1[15:8];
    y1 = tuple1[7:0];
    x2 = tuple2[15:8];
    y2 = tuple2[7:0];
    x3 = tuple3[15:8];
    y3 = tuple3[7:0];

    p0 = $signed(x0) * $signed(y0);
    p1 = $signed(x1) * $signed(y1);
    p2 = $signed(x2) * $signed(y2);
    p3 = $signed(x3) * $signed(y3);

    a0 = abs16(p0);
    a1 = abs16(p1);
    a2 = abs16(p2);
    a3 = abs16(p3);

    m01 = min(a0, a1);
    m23 = min(a2, a3);
    min_product = min(m01, m23);
  end

endmodule