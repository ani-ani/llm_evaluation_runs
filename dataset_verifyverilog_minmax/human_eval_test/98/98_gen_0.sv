module count_upper(
  input reg [63:0] chars,
  output reg [2:0] count
);

  localparam A = 8'd65;
  localparam E = 8'd69;
  localparam I = 8'd73;
  localparam O = 8'd79;
  localparam U = 8'd85;

  reg [7:0] b0, b1, b2, b3, b4, b5, b6, b7;

  // chars: bits [63:56] = char[0] (MSB), ..., bits [7:0] = char[7] (LSB)
  always @* begin
    b0 = chars[63:56]; // char[0]
    b1 = chars[55:48]; // char[1]
    b2 = chars[47:40]; // char[2]
    b3 = chars[39:32]; // char[3]
    b4 = chars[31:24]; // char[4]
    b5 = chars[23:16]; // char[5]
    b6 = chars[15:8];  // char[6]
    b7 = chars[7:0];   // char[7]

    count = 3'd0;
    if (b0 == A || b0 == E || b0 == I || b0 == O || b0 == U) count = count + 1'b1;
    if (b2 == A || b2 == E || b2 == I || b2 == O || b2 == U) count = count + 1'b1;
    if (b4 == A || b4 == E || b4 == I || b4 == O || b4 == U) count = count + 1'b1;
    if (b6 == A || b6 == E || b6 == I || b6 == O || b6 == U) count = count + 1'b1;
  end

endmodule
