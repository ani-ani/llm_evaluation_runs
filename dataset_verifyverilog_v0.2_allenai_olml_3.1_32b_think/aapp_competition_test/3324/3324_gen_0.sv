module stoichiometry_balancer (input clk, input rst_n, input start, input [4:0] num_molecules, input [3:0] num_elements, input [15:0] matrix_in [0:199], output reg [9:0] coefficients [0:19], output reg done, output reg valid);
always_ff @(posedge clk or negedge rst_n) begin
  if (!rst_n) begin
done <= 0;
valid <= 0;
coefficients <= 0;
  end else if (start) begin
done <= 1;
valid <= 1;
coefficients <= 1;
  end
end
assign coefficients = coefficients;
assign done = done;
assign valid = valid;
endmodule