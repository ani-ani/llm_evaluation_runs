module char_to_ascii (
  input  reg [7:0] char,
  output reg [7:0] ascii_val
);
  // Combinational passthrough: ascii_val = char
  always @* begin
    ascii_val = char;
  end
endmodule