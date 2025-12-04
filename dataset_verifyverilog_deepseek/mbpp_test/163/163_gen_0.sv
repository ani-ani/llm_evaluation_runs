module poly_area (
  input [3:0] sides,
  input [4:0] length,
  output [31:0] area
);
  reg [31:0] coefficient;
  wire [9:0] length_squared = length * length;
  wire [41:0] product = coefficient * {22'h0, length_squared};

  always_comb begin
    case (sides)
      4'd3: coefficient = 32'h00006ed9;
      4'd4: coefficient = 32'h00010000;
      4'd5: coefficient = 32'h00015b48;
      4'd6: coefficient = 32'h0;
      4'd7: coefficient = 32'h0;
      4'd8: coefficient = 32'h0;
      4'd9: coefficient = 32'h0;
      4'd10: coefficient = 32'h0;
      4'd11: coefficient = 32'h0;
      4'd12: coefficient = 32'h0;
      4'd13: coefficient = 32'h0;
      4'd14: coefficient = 32'h0;
      4'd15: coefficient = 32'h0;
      default: coefficient = 32'h0;
    endcase
  end

  assign area = product[31:0];
endmodule