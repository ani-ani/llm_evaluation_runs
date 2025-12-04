module unsorted_perm_count(
  input [2:0] n,
  output reg [31:0] count
);
  always @* begin
    case (n)
      3'b000: count = 32'd0;      // n=0
      3'b001: count = 32'd0;      // n=1
      3'b010: count = 32'd0;      // n=2
      3'b011: count = 32'd2;      // n=3
      3'b100: count = 32'd14;     // n=4
      3'b101: count = 32'd90;     // n=5
      3'b110: count = 32'd646;    // n=6
      3'b111: count = 32'd5242;   // n=7
      default: count = 32'd0;     // n=8 (not representable in 3 bits, default to 0)
    endcase
  end
endmodule