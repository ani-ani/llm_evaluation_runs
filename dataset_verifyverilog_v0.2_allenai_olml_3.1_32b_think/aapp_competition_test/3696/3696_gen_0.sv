module euclid_poly_builder(input clk, input rst_n, input start, input [7:0] n, output reg [7:0] deg_a, output reg [7:0] deg_b, output reg signed [2:0] a_coeffs [0:120], output reg signed [2:0] b_coeffs [0:120], output reg done);
always @(posedge clk) begin
  if (!rst_n) begin
    deg_a <= 0;
    deg_b <= 0;
    for (int i=0; i<121; i++) begin
      a_coeffs[i] <= 0;
      b_coeffs[i] <= 0;
    end
    done <= 0;
  end
end
endmodule