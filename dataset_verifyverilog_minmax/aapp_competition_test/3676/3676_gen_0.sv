module polygon_counter(
  input [1:0] R,
  input [1:0] C,
  output reg [15:0] count
);
  always @(*) begin
    case ({R,C})
      4'b00_00: count = 16'd1;  // 1x1
      4'b00_01: count = 16'd3;  // 1x2
      4'b00_10: count = 16'd6;  // 1x3
      4'b00_11: count = 16'd10; // 1x4
      4'b01_00: count = 16'd3;  // 2x1
      4'b01_01: count = 16'd13; // 2x2
      default: count = 16'd0;   // Unimplemented sizes
    endcase
  end
endmodule