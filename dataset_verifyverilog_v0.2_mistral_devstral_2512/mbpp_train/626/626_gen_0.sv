module semicircle_triangle_area(
  input [15:0] radius,
  input valid,
  output reg [31:0] area,
  output reg area_valid
);

  always @(*) begin
    if (valid) begin
      area = {16'h0, radius} * {16'h0, radius};
      area_valid = 1'b1;
    end else begin
      area = 32'h0;
      area_valid = 1'b0;
    end
  end

endmodule